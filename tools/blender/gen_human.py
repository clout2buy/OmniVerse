"""Stylized human for OmniVerse, built from docs/concepts/human_turnaround.jpg.

Organic body via a vertex skeleton + Skin modifier + Subdivision, then clothing shells.
Run:  blender -b --factory-startup -P tools/blender/gen_human.py [-- --preview]
Writes assets/models/human.glb (and docs/preview_human.png with --preview).

Conventions: faces +Y in Blender (= -Z forward in Godot), feet at z=0, ~1.85 tall.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "assets", "models", "human.glb")
PREVIEW = os.path.join(ROOT, "docs", "preview_human.png")

# ----------------------------------------------------------------- materials

def mat(name, rgb, emission=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.85
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    m.diffuse_color = (*rgb, 1.0)
    return m


SKIN = mat("skin", (0.74, 0.63, 0.68))
HAIR = mat("hair_blue", (0.2, 0.42, 0.9))
JACKET = mat("jacket", (0.13, 0.14, 0.17))
TEAL = mat("lapel_teal", (0.18, 0.6, 0.52))
ORANGE = mat("turtleneck", (0.86, 0.4, 0.12))
PANTS = mat("pants_navy", (0.11, 0.13, 0.25))
BOOT = mat("boots", (0.46, 0.42, 0.37))
BELT = mat("belt", (0.2, 0.14, 0.1))
MUTRIX = mat("mutrix", (0.24, 0.95, 0.54), emission=2.5)
EYE = mat("eye", (0.06, 0.06, 0.08))

# ----------------------------------------------------------------- helpers

def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def new_object(name, verts, edges, faces=()):
    me = bpy.data.meshes.new(name)
    me.from_pydata([Vector(v) for v in verts], list(edges), list(faces))
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob


def skin_body():
    """Vertex skeleton -> Skin modifier. Returns the object. Lanky proportions."""
    # (x, y, z, radius_x, radius_y)
    joints = {
        "pelvis": (0, 0, 0.98, 0.13, 0.10),
        "belly": (0, 0.0, 1.12, 0.12, 0.095),
        "chest": (0, 0.0, 1.32, 0.15, 0.10),
        "neck_b": (0, 0.0, 1.48, 0.06, 0.06),
        "neck_t": (0, 0.0, 1.56, 0.055, 0.055),
    }
    edges = [("pelvis", "belly"), ("belly", "chest"), ("chest", "neck_b"), ("neck_b", "neck_t")]
    for s, sign in (("l", -1), ("r", 1)):
        joints[f"hip_{s}"] = (0.09 * sign, 0, 0.95, 0.085, 0.08)
        joints[f"knee_{s}"] = (0.10 * sign, 0.01, 0.52, 0.06, 0.06)
        joints[f"ankle_{s}"] = (0.10 * sign, 0.0, 0.10, 0.045, 0.045)
        joints[f"sho_{s}"] = (0.21 * sign, 0, 1.44, 0.065, 0.065)
        joints[f"elb_{s}"] = (0.26 * sign, -0.01, 1.14, 0.045, 0.045)
        joints[f"wri_{s}"] = (0.29 * sign, 0.02, 0.90, 0.035, 0.035)
        edges += [("pelvis", f"hip_{s}"), (f"hip_{s}", f"knee_{s}"), (f"knee_{s}", f"ankle_{s}"),
                  ("chest", f"sho_{s}"), (f"sho_{s}", f"elb_{s}"), (f"elb_{s}", f"wri_{s}")]
    names = list(joints)
    idx = {n: i for i, n in enumerate(names)}
    verts = [joints[n][:3] for n in names]
    ob = new_object("body", verts, [(idx[a], idx[b]) for a, b in edges])
    skin = ob.modifiers.new("Skin", "SKIN")
    skin.use_smooth_shade = True
    for n in names:
        v = ob.data.skin_vertices[0].data[idx[n]]
        v.radius = (joints[n][3], joints[n][4])
        if n in ("pelvis", "chest"):
            v.use_root = n == "pelvis"
    sub = ob.modifiers.new("Sub", "SUBSURF")
    sub.levels = 2
    sub.render_levels = 2
    return ob


def apply_all(ob):
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    for m in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)
    ob.select_set(False)


def assign_by_height(ob, rules, default):
    """rules: list of (zmin, zmax, material). Faces by center z."""
    mats = [default] + [r[2] for r in rules] + [JACKET]
    for m in mats:
        if m.name not in [s.material.name for s in ob.material_slots if s.material]:
            ob.data.materials.append(m)
    slot = {m.name: i for i, m in enumerate(ob.data.materials)}
    for f in ob.data.polygons:
        z = sum(ob.data.vertices[v].co.z for v in f.vertices) / len(f.vertices)
        x = sum(ob.data.vertices[v].co.x for v in f.vertices) / len(f.vertices)
        f.material_index = slot[default.name]
        for zmin, zmax, m in rules:
            if zmin <= z < zmax:
                f.material_index = slot[m.name]
                break
        # Arms above the wrist are jacket sleeves, not skin
        if 0.96 <= z < 1.47 and abs(x) > 0.19:
            f.material_index = slot[JACKET.name]


def prim(op, mat_, loc, scale=(1, 1, 1), rot=(0, 0, 0), **kw):
    op(location=loc, **kw)
    ob = bpy.context.active_object
    ob.scale = scale
    ob.rotation_euler = tuple(math.radians(r) for r in rot)
    ob.data.materials.append(mat_)
    bpy.ops.object.shade_smooth()
    return ob


def head_and_hair():
    parts = []
    # Long face: stretched sphere, slight chin
    head = prim(bpy.ops.mesh.primitive_uv_sphere_add, SKIN, (0, 0.0, 1.72), (0.105, 0.11, 0.15), segments=24, ring_count=16)
    parts.append(head)
    chin = prim(bpy.ops.mesh.primitive_uv_sphere_add, SKIN, (0, 0.02, 1.60), (0.07, 0.075, 0.06), segments=16, ring_count=10)
    parts.append(chin)
    # Nose (front is +Y)
    nose = prim(bpy.ops.mesh.primitive_cone_add, SKIN, (0, 0.11, 1.70), (0.02, 0.035, 0.03), rot=(-90, 0, 0), vertices=8)
    parts.append(nose)
    # Eyes: flat dark ovals
    for sx in (-1, 1):
        e = prim(bpy.ops.mesh.primitive_uv_sphere_add, EYE, (0.04 * sx, 0.098, 1.745), (0.022, 0.008, 0.014), segments=12, ring_count=8)
        parts.append(e)
    # Hair: dense crown of swept-back spikes
    spikes = [
        # (x, y, z, tilt_x, tilt_y, length)
        (0.0, -0.02, 1.86, -35, 0, 0.30),
        (0.05, -0.03, 1.86, -30, 25, 0.28),
        (-0.05, -0.03, 1.86, -30, -25, 0.28),
        (0.09, -0.06, 1.83, -40, 45, 0.24),
        (-0.09, -0.06, 1.83, -40, -45, 0.24),
        (0.0, -0.08, 1.83, -60, 0, 0.26),
        (0.06, -0.09, 1.80, -70, 20, 0.22),
        (-0.06, -0.09, 1.80, -70, -20, 0.22),
        (0.03, 0.04, 1.86, 10, 15, 0.22),
        (-0.03, 0.04, 1.86, 10, -15, 0.22),
        (0.08, 0.0, 1.84, -15, 55, 0.2),
        (-0.08, 0.0, 1.84, -15, -55, 0.2),
        (0.0, -0.11, 1.76, -95, 0, 0.18),
    ]
    for x, y, z, tx, ty, ln in spikes:
        s = prim(bpy.ops.mesh.primitive_cone_add, HAIR, (x, y, z), (1, 1, 1), rot=(tx, ty, 0), vertices=6, radius1=0.045, radius2=0.004, depth=ln)
        # shift so base sits at the scalp
        s.location += s.matrix_world.to_3x3() @ Vector((0, 0, ln * 0.35))
        bpy.ops.object.shade_flat()
        parts.append(s)
    cap = prim(bpy.ops.mesh.primitive_uv_sphere_add, HAIR, (0, -0.02, 1.80), (0.115, 0.12, 0.10), segments=16, ring_count=10)
    parts.append(cap)
    return parts


def clothing():
    parts = []
    # Cropped jacket shell: boxy torso cover, open at the front
    jacket = prim(bpy.ops.mesh.primitive_cube_add, JACKET, (0, -0.02, 1.31), (0.24, 0.15, 0.16), size=2)
    bev = jacket.modifiers.new("Bevel", "BEVEL")
    bev.width = 0.55   # local units (cube is 2 wide before scale)
    bev.segments = 6
    # Cut the front open so the orange turtleneck underneath shows (V shape, wider at the top)
    cutter = prim(bpy.ops.mesh.primitive_cone_add, JACKET, (0, 0.16, 1.30), (0.16, 0.12, 0.2), rot=(0, 0, 0), vertices=4, radius1=0.6, radius2=1.0, depth=2.0)
    cutter.rotation_euler = (0, 0, math.radians(45))
    boo = jacket.modifiers.new("Cut", "BOOLEAN")
    boo.operation = "DIFFERENCE"
    boo.object = cutter
    bpy.context.view_layer.objects.active = jacket
    jacket.select_set(True)
    bpy.ops.object.modifier_apply(modifier="Bevel")
    bpy.ops.object.modifier_apply(modifier="Cut")
    jacket.select_set(False)
    bpy.data.objects.remove(cutter, do_unlink=True)
    parts.append(jacket)
    # Body turtleneck fill so the opening is never hollow
    front = prim(bpy.ops.mesh.primitive_cylinder_add, ORANGE, (0, 0.0, 1.30), (0.15, 0.115, 0.17), vertices=20)
    parts.append(front)
    # Collar (orange, high)
    collar = prim(bpy.ops.mesh.primitive_cylinder_add, ORANGE, (0, 0, 1.53), (0.075, 0.07, 0.05), vertices=16)
    parts.append(collar)
    # Teal lapels
    for sx in (-1, 1):
        lap = prim(bpy.ops.mesh.primitive_cube_add, TEAL, (0.095 * sx, 0.135, 1.40), (0.035, 0.012, 0.09), rot=(0, 0, 30 * sx), size=2)
        parts.append(lap)
    # Belt with Mutrix on the left hip, plus a wrist Mutrix
    belt = prim(bpy.ops.mesh.primitive_cylinder_add, BELT, (0, 0, 1.06), (0.145, 0.115, 0.02), vertices=20)
    parts.append(belt)
    buckle = prim(bpy.ops.mesh.primitive_cube_add, MUTRIX, (-0.06, 0.105, 1.06), (0.035, 0.015, 0.035), size=2)
    parts.append(buckle)
    watch = prim(bpy.ops.mesh.primitive_cylinder_add, MUTRIX, (-0.295, 0.02, 0.94), (0.045, 0.045, 0.03), rot=(0, 90, 0), vertices=12)
    parts.append(watch)
    # Hands
    for sx in (-1, 1):
        h = prim(bpy.ops.mesh.primitive_uv_sphere_add, SKIN, (0.295 * sx, 0.03, 0.845), (0.038, 0.028, 0.065), segments=12, ring_count=8)
        parts.append(h)
    # Boots
    for sx in (-1, 1):
        b = prim(bpy.ops.mesh.primitive_cube_add, BOOT, (0.10 * sx, 0.035, 0.065), (0.06, 0.115, 0.065), size=2)
        bv = b.modifiers.new("Bevel", "BEVEL")
        bv.width = 0.6
        bv.segments = 5
        parts.append(b)
    return parts


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = name
    ob.data.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return ob


def preview(ob):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_object_outline = True
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.render.filepath = PREVIEW
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = (2.3, 3.4, 1.5)
    cam_data.lens = 55
    target = bpy.data.objects.new("target", None)
    target.location = (0, 0, 0.95)
    bpy.context.collection.objects.link(target)
    con = cam.constraints.new("TRACK_TO")
    con.target = target
    con.track_axis = "TRACK_NEGATIVE_Z"
    con.up_axis = "UP_Y"
    scene.camera = cam
    bpy.ops.render.render(write_still=True)
    print("[gen_human] preview", PREVIEW)


def main():
    clear()
    body = skin_body()
    apply_all(body)
    assign_by_height(body, [
        (0.0, 0.14, BOOT),
        (0.14, 1.00, PANTS),
        (1.00, 1.08, BELT),
        (1.08, 1.50, ORANGE),
    ], SKIN)
    parts = [body] + head_and_hair() + clothing()
    for p in parts:
        bpy.context.view_layer.objects.active = p
        p.select_set(True)
        for m in list(p.modifiers):
            bpy.ops.object.modifier_apply(modifier=m.name)
        p.select_set(False)
    human = join(parts, "human")
    if "--preview" in sys.argv:
        preview(human)
    bpy.ops.object.select_all(action="DESELECT")
    human.select_set(True)
    bpy.context.view_layer.objects.active = human
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True)
    print("[gen_human] wrote", OUT)


if __name__ == "__main__":
    main()
