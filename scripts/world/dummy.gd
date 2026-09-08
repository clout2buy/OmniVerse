## Training dummy: something to hit when you are testing solo. Regenerates after a few seconds.
class_name Dummy
extends StaticBody3D

var max_health := 300.0
var health := 300.0
var dead := false
var last_hit_ms := 0
var label: Label3D
var body: MeshInstance3D

func _ready() -> void:
	add_to_group("damageable")
	body = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.45
	cyl.height = 1.6
	body.mesh = cyl
	body.position.y = 0.8
	add_child(body)
	var head := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.3
	s.height = 0.6
	head.mesh = s
	head.position.y = 1.9
	add_child(head)
	Cel.apply(self, Color(0.85, 0.35, 0.25))
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 2.2
	shape.shape = cap
	shape.position.y = 1.1
	add_child(shape)
	label = Label3D.new()
	label.position.y = 2.6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.outline_size = 8
	add_child(label)
	_refresh()

func _process(_delta: float) -> void:
	if health < max_health and Time.get_ticks_msec() - last_hit_ms > 5000:
		health = min(max_health, health + 60.0 * _delta)
		_refresh()

func _refresh() -> void:
	label.text = "DUMMY  %d / %d" % [ceil(health), max_health]

@rpc("any_peer", "call_local", "reliable")
func receive_hit(amount: float, _from_peer: int, _knock: Vector3) -> void:
	health = max(0.0, health - amount)
	last_hit_ms = Time.get_ticks_msec()
	Fx.hit(global_position)
	if health <= 0.0:
		Fx.burst(global_position + Vector3(0, 1, 0), Color(1, 0.4, 0.2), 3.0, 0.5)
		health = max_health
	_refresh()

@rpc("any_peer", "call_local", "reliable")
func apply_status(_kind: String, _duration: float, _factor: float) -> void:
	pass
