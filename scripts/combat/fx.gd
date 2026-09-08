## Transient visual effects. Everything here is fire-and-forget and self-cleans.
## These are placeholders; Ares should replace them with particles + animations over time.
class_name Fx

static func _scene() -> Node:
	return Engine.get_main_loop().current_scene

static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 2.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

static func _spawn(mesh: Mesh, pos: Vector3, color: Color, dur: float, start_scale: float, end_scale: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := _mat(color)
	mi.material_override = m
	mi.position = pos
	mi.scale = Vector3.ONE * start_scale
	_scene().add_child(mi)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * end_scale, dur).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(a: float): m.albedo_color.a = a, color.a, 0.0, dur)
	tw.chain().tween_callback(mi.queue_free)
	return mi

## Expanding flat ring on the ground.
static func ring(pos: Vector3, radius: float, color: Color, dur: float = 0.45) -> void:
	var t := TorusMesh.new()
	t.inner_radius = 0.85
	t.outer_radius = 1.0
	_spawn(t, pos + Vector3(0, 0.1, 0), color, dur, 0.2, radius)

## Expanding sphere.
static func burst(pos: Vector3, color: Color, size: float = 1.0, dur: float = 0.3) -> void:
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	_spawn(s, pos, color, dur, 0.2, size)

## Straight beam between two points.
static func beam(a: Vector3, b: Vector3, color: Color, dur: float = 0.25, thickness: float = 0.12) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(thickness, thickness, 1.0)
	mi.mesh = box
	var m := _mat(color)
	mi.material_override = m
	_scene().add_child(mi)
	var length := a.distance_to(b)
	if length < 0.01:
		mi.queue_free()
		return
	mi.global_position = (a + b) * 0.5
	mi.look_at(b, Vector3.UP if abs((b - a).normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT)
	mi.scale = Vector3(1, 1, length)
	var tw := mi.create_tween()
	tw.tween_method(func(x: float): m.albedo_color.a = x, 1.0, 0.0, dur)
	tw.tween_callback(mi.queue_free)

## Melee swing arc in front of a body.
static func swing(body: Node3D, color: Color, reach: float) -> void:
	var fwd: Vector3 = -body.global_transform.basis.z
	var origin: Vector3 = body.global_position + Vector3(0, 1.1, 0)
	burst(origin + fwd * reach * 0.6, color, reach * 0.9, 0.18)

static func hit(pos: Vector3) -> void:
	burst(pos + Vector3(0, 1.0, 0), Color(1, 0.35, 0.2), 0.9, 0.15)

## Big mutation flash when the Mutrix fires.
static func mutate(pos: Vector3, color: Color) -> void:
	burst(pos + Vector3(0, 1.0, 0), Color(0.24, 0.95, 0.54), 3.0, 0.45)
	burst(pos + Vector3(0, 1.0, 0), color, 2.2, 0.6)
	ring(pos, 4.0, Color(0.24, 0.95, 0.54), 0.5)
