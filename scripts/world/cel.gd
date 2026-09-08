## Helpers for the cel-shaded look. Every mesh in the game should go through here.
class_name Cel

const CEL_SHADER := "res://assets/shaders/cel.gdshader"
const OUTLINE_SHADER := "res://assets/shaders/outline.gdshader"

## Build a cel material (with ink outline as next_pass) in a given color.
static func material(color: Color, emission: float = 0.0, outline_width: float = 0.025) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(CEL_SHADER)
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("emission_strength", emission)
	var o := ShaderMaterial.new()
	o.shader = load(OUTLINE_SHADER)
	o.set_shader_parameter("width", outline_width)
	m.next_pass = o
	return m

## Apply cel materials to every MeshInstance3D under `node`.
## If a surface already has a StandardMaterial3D (e.g. imported from a .glb),
## its albedo color is kept so multi-colored models survive. Otherwise `fallback` is used.
static func apply(node: Node, fallback: Color, outline_width: float = 0.025) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var color := fallback
				var existing := mi.get_active_material(i)
				if existing is StandardMaterial3D:
					color = (existing as StandardMaterial3D).albedo_color
				mi.set_surface_override_material(i, material(color, 0.0, outline_width))
	for c in node.get_children():
		apply(c, fallback, outline_width)

## Set a shader parameter on every cel material (and its outline pass) under `node`.
static func set_param(node: Node, param: String, value: Variant) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var m := mi.get_surface_override_material(i)
				if m is ShaderMaterial:
					m.set_shader_parameter(param, value)
					if m.next_pass is ShaderMaterial:
						m.next_pass.set_shader_parameter(param, value)
	for c in node.get_children():
		set_param(c, param, value)
