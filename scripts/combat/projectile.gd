## A simple straight-line projectile. Every peer simulates it visually;
## only the shooter's peer (authoritative == true) applies damage.
class_name Projectile
extends Area3D

var velocity := Vector3.ZERO
var damage := 0.0
var max_dist := 30.0
var traveled := 0.0
var shooter: Node3D
var authoritative := false
var color := Color.WHITE

func setup(from: Vector3, dir: Vector3, ab: AbilityData, from_node: Node3D, is_authoritative: bool) -> void:
	position = from
	velocity = dir.normalized() * ab.speed
	damage = ab.damage
	max_dist = ab.range
	shooter = from_node
	authoritative = is_authoritative
	color = ab.color

func _ready() -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.16
	s.height = 0.32
	mi.mesh = s
	mi.material_override = Fx._mat(color)
	add_child(mi)
	var shape := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.2
	shape.shape = sph
	add_child(shape)
	monitoring = true
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	var step := velocity * delta
	position += step
	traveled += step.length()
	if traveled >= max_dist:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
	if authoritative and body.has_method("receive_hit") and shooter != null and shooter.has_method("deal_damage"):
		shooter.deal_damage(body, damage, velocity.normalized() * 2.0)
	Fx.burst(global_position, color, 0.6, 0.15)
	queue_free()
