## The first arena, built procedurally so it exists without any art.
## Ares: replace with a hand-built scene later, but keep Game.spawn_points populated.
class_name Arena
extends Node3D

const SIZE := 56.0
const WALL_H := 6.0

func _ready() -> void:
	_environment()
	_floor()
	_walls()
	_cover()
	Game.spawn_points = [
		Vector3(-20, 1, -20), Vector3(20, 1, -20), Vector3(-20, 1, 20), Vector3(20, 1, 20),
		Vector3(0, 1, -24), Vector3(0, 1, 24), Vector3(-24, 1, 0), Vector3(24, 1, 0),
	]

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.12, 0.18, 0.38)
	mat.sky_horizon_color = Color(0.55, 0.5, 0.65)
	mat.ground_bottom_color = Color(0.1, 0.08, 0.12)
	mat.ground_horizon_color = Color(0.4, 0.35, 0.45)
	sky.sky_material = mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.light_energy = 1.4
	sun.light_color = Color(1, 0.96, 0.9)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120
	add_child(sun)

func _block(pos: Vector3, size: Vector3, color: Color, outline := 0.03) -> StaticBody3D:
	var body := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	Cel.apply(body, color, outline)
	add_child(body)
	return body

func _floor() -> void:
	_block(Vector3(0, -0.5, 0), Vector3(SIZE, 1, SIZE), Color(0.32, 0.36, 0.42), 0.0)
	# Center plate
	_block(Vector3(0, 0.05, 0), Vector3(12, 0.1, 12), Color(0.22, 0.5, 0.42), 0.0)

func _walls() -> void:
	var h := SIZE * 0.5
	var t := 1.0
	var col := Color(0.2, 0.22, 0.3)
	_block(Vector3(0, WALL_H * 0.5, -h - t * 0.5), Vector3(SIZE + t * 2, WALL_H, t), col)
	_block(Vector3(0, WALL_H * 0.5, h + t * 0.5), Vector3(SIZE + t * 2, WALL_H, t), col)
	_block(Vector3(-h - t * 0.5, WALL_H * 0.5, 0), Vector3(t, WALL_H, SIZE), col)
	_block(Vector3(h + t * 0.5, WALL_H * 0.5, 0), Vector3(t, WALL_H, SIZE), col)

func _cover() -> void:
	var stone := Color(0.5, 0.45, 0.5)
	var accent := Color(0.75, 0.35, 0.3)
	# Four pillars
	for x in [-12.0, 12.0]:
		for z in [-12.0, 12.0]:
			_block(Vector3(x, 2.0, z), Vector3(2.2, 4.0, 2.2), stone)
	# Low walls
	_block(Vector3(0, 0.75, -9), Vector3(8, 1.5, 1), accent)
	_block(Vector3(0, 0.75, 9), Vector3(8, 1.5, 1), accent)
	_block(Vector3(-9, 0.75, 0), Vector3(1, 1.5, 8), accent)
	_block(Vector3(9, 0.75, 0), Vector3(1, 1.5, 8), accent)
	# Corner ramps / platforms
	_block(Vector3(-22, 0.6, -22), Vector3(8, 1.2, 8), stone)
	_block(Vector3(22, 0.6, 22), Vector3(8, 1.2, 8), stone)
	_block(Vector3(22, 1.2, -22), Vector3(6, 2.4, 6), stone)
	_block(Vector3(-22, 1.2, 22), Vector3(6, 2.4, 6), stone)
