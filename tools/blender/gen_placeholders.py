"""Generate placeholder creature meshes for OmniVerse and export them as .glb.

Run headless from the repo root:
    blender -b --factory-startup -P tools/blender/gen_placeholders.py

Conventions (important for Godot):
  * Blender is Z-up, Godot is Y-up. The glTF exporter converts automatically.
  * A model must FACE +Y in Blender so it faces -Z (forward) in Godot.
  * Feet at z = 0, origin at the world origin. Height about 1.8 units.
    FormData.size scales the whole thing in-game.
  * One object per creature, named after the form id, one material per color.

These are silhouettes, not final art. Ares: replace piece by piece with real sculpts,
keep the same file names, and Godot will pick them up automatically.
"""
import math
import os
import sys

import bpy

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models")
OUT_DIR = os.path.normpath(OUT_DIR)


# ----------------------------------------------------------------- helpers

def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.materials):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def material(name, rgb, emission=0.0):
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.8
        if emission > 0 and "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (*rgb, 1.0)
            bsdf.inputs["Emission Strength"].default_value = emission
    mat.diffuse_color = (*rgb, 1.0)
    return mat


def _finish(obj, mat, scale=(1, 1, 1), rot=(0, 0, 0)):
    obj.scale = scale
    obj.rotation_euler = tuple(math.radians(r) for r in rot)
    obj.data.materials.append(mat)
    return obj


def sphere(loc, r, mat, scale=(1, 1, 1), rot=(0, 0, 0), segs=16):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=segs, ring_count=segs // 2)
    return _finish(bpy.context.active_object, mat, scale, rot)


def cylinder(loc, r, depth, mat, scale=(1, 1, 1), rot=(0, 0, 0), verts=16):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc, vertices=verts)
    return _finish(bpy.context.active_object, mat, scale, rot)


def cone(loc, r, depth, mat, scale=(1, 1, 1), rot=(0, 0, 0), verts=12):
    bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=0.0, depth=depth, location=loc, vertices=verts)
    return _finish(bpy.context.active_object, mat, scale, rot)


def box(loc, size, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    return _finish(bpy.context.active_object, mat, size, rot)


def limb(start, end, r, mat, verts=10):
    """Cylinder between two points."""
    sx, sy, sz = start
    ex, ey, ez = end
    dx, dy, dz = ex - sx, ey - sy, ez - sz
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    mid = ((sx + ex) / 2, (sy + ey) / 2, (sz + ez) / 2)
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=length, location=mid, vertices=verts)
    obj = bpy.context.active_object
    # Align local Z to the direction vector.
    phi = math.atan2(dy, dx)
    theta = math.acos(dz / length) if length > 0 else 0
    obj.rotation_euler = (0, theta, phi)
    obj.data.materials.append(mat)
    return obj


def join_all(name):
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.shade_flat()
    return obj


def export(obj, name):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, f"{name}.glb")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True)
    print(f"[gen_placeholders] wrote {path}")


# ----------------------------------------------------------------- creatures
# All face +Y. Feet at z=0.

def build_human():
    """Lanky punk from docs/concepts/human_turnaround.jpg: spiky blue hair,
    dark jacket with teal lapels, orange turtleneck, navy pants, grey boots."""
    skin = material("skin", (0.62, 0.55, 0.62))
    hair = material("hair_blue", (0.22, 0.45, 0.92))
    jacket = material("jacket", (0.14, 0.15, 0.18))
    teal = material("lapel_teal", (0.2, 0.62, 0.55))
    orange = material("turtleneck", (0.85, 0.42, 0.14))
    pants = material("pants_navy", (0.12, 0.14, 0.26))
    boot = material("boots", (0.45, 0.42, 0.38))
    mutrix = material("mutrix", (0.24, 0.95, 0.54), emission=2.0)

    # Legs (thin)
    for side in (-1, 1):
        x = 0.11 * side
        cylinder((x, 0, 0.55), 0.075, 0.95, pants)
        box((x, 0.02, 0.06), (0.16, 0.26, 0.12), boot)
    # Torso: turtleneck under a cropped jacket
    cylinder((0, 0, 1.2), 0.15, 0.5, orange, scale=(1.15, 0.8, 1.0))
    box((0, 0, 1.28), (0.44, 0.26, 0.4), jacket)
    box((0, 0.13, 1.4), (0.22, 0.04, 0.2), teal)   # lapels
    cylinder((0, 0, 1.5), 0.09, 0.14, orange)      # collar
    # Arms hanging
    for side in (-1, 1):
        x = 0.27 * side
        limb((x, 0, 1.45), (x + 0.04 * side, 0, 0.98), 0.055, jacket)
        sphere((x + 0.05 * side, 0, 0.9), 0.055, skin, scale=(1, 0.6, 1.3))
    # Mutrix on the left wrist
    box((-0.32, 0.02, 1.0), (0.1, 0.11, 0.07), mutrix)
    # Neck and head (long face)
    cylinder((0, 0, 1.58), 0.05, 0.1, skin)
    sphere((0, 0, 1.76), 0.12, skin, scale=(0.85, 0.85, 1.25))
    # Hair: cluster of spikes
    for i in range(9):
        a = (i / 9.0) * math.tau
        ox = math.cos(a) * 0.08
        oy = math.sin(a) * 0.06 - 0.02
        tilt_x = -math.sin(a) * 40
        tilt_y = math.cos(a) * 40
        cone((ox, oy, 1.93), 0.045, 0.22, hair, rot=(tilt_x, tilt_y, 0))
    cone((0, 0, 1.98), 0.06, 0.26, hair)
    return join_all("human")


def build_vantablade():
    """Assassin. Slim, tall, crest on the head, arms end in long blades."""
    body = material("vanta_body", (0.14, 0.08, 0.26))
    blade = material("vanta_blade", (0.6, 0.3, 1.0), emission=1.5)
    eye = material("vanta_eye", (1.0, 0.2, 0.4), emission=3.0)

    for side in (-1, 1):
        x = 0.1 * side
        limb((x, 0, 0.0), (x * 1.3, 0, 0.95), 0.06, body)
    cylinder((0, 0, 1.25), 0.14, 0.7, body, scale=(1.0, 0.7, 1.0))
    sphere((0, 0, 1.65), 0.16, body, scale=(1.2, 0.9, 0.8))   # shoulders
    sphere((0, 0.02, 1.85), 0.12, body, scale=(0.9, 1.0, 1.1))  # head
    cone((0, -0.05, 2.05), 0.08, 0.4, body, rot=(-25, 0, 0))   # crest sweeping back
    sphere((0, 0.11, 1.87), 0.03, eye, scale=(2.2, 0.6, 1.0))   # eye slit, faces +Y
    # Blade arms: from shoulder down and forward
    for side in (-1, 1):
        x = 0.24 * side
        limb((x, 0, 1.6), (x * 1.4, 0.1, 1.05), 0.05, body)
        box((x * 1.45, 0.35, 0.95), (0.05, 0.75, 0.16), blade, rot=(20, 0, 0))
    return join_all("vantablade")


def build_bulwark():
    """Tank. Wide box torso, huge shoulders, tiny head."""
    stone = material("bulwark_stone", (0.45, 0.38, 0.3))
    dark = material("bulwark_dark", (0.28, 0.24, 0.2))
    core = material("bulwark_core", (1.0, 0.55, 0.15), emission=2.0)

    for side in (-1, 1):
        x = 0.28 * side
        cylinder((x, 0, 0.4), 0.17, 0.8, dark)
        box((x, 0.03, 0.08), (0.36, 0.42, 0.16), dark)
    box((0, 0, 1.1), (0.95, 0.6, 0.8), stone)
    box((0, 0.31, 1.1), (0.3, 0.06, 0.3), core)   # glowing core on the chest (+Y)
    for side in (-1, 1):
        x = 0.62 * side
        sphere((x, 0, 1.5), 0.3, stone)
        limb((x, 0, 1.45), (x * 1.15, 0.05, 0.75), 0.14, dark)
        sphere((x * 1.18, 0.07, 0.65), 0.2, stone)  # fist
    sphere((0, 0.05, 1.68), 0.16, stone, scale=(1, 1, 0.8))
    return join_all("bulwark")


def build_voltrix():
    """Speedster. Slim, swept-back fin, thin limbs, forward lean."""
    cyan = material("volt_body", (0.2, 0.75, 1.0))
    dark = material("volt_dark", (0.08, 0.2, 0.35))
    spark = material("volt_spark", (1.0, 0.95, 0.4), emission=3.0)

    for side in (-1, 1):
        x = 0.09 * side
        limb((x, 0.05, 0.0), (x, -0.05, 0.9), 0.05, dark)
    cylinder((0, 0, 1.15), 0.12, 0.55, cyan, scale=(1, 0.75, 1), rot=(-8, 0, 0))
    sphere((0, 0.02, 1.5), 0.13, cyan, scale=(1.3, 0.8, 0.7))
    sphere((0, 0.08, 1.7), 0.11, cyan, scale=(0.8, 1.2, 0.9))
    cone((0, -0.12, 1.75), 0.09, 0.55, dark, rot=(-70, 0, 0))   # fin sweeping back (-Y)
    sphere((0, 0.19, 1.71), 0.035, spark)                       # eye, faces +Y
    for side in (-1, 1):
        x = 0.2 * side
        limb((x, 0, 1.45), (x * 1.3, 0.15, 1.0), 0.04, dark)
        box((x * 1.3, 0.05, 1.3), (0.03, 0.12, 0.3), spark, rot=(0, 0, 0))  # forearm spark blades
    return join_all("voltrix")


BUILDERS = {
    "human": build_human,
    "vantablade": build_vantablade,
    "bulwark": build_bulwark,
    "voltrix": build_voltrix,
}


def main():
    wanted = [a for a in sys.argv[sys.argv.index("--") + 1:]] if "--" in sys.argv else list(BUILDERS)
    for name in wanted:
        if name not in BUILDERS:
            print(f"[gen_placeholders] unknown creature {name}")
            continue
        clear_scene()
        obj = BUILDERS[name]()
        export(obj, name)
    clear_scene()


if __name__ == "__main__":
    main()
