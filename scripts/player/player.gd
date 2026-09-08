## The player: movement, camera, health, form (Mutrix) state, and all combat RPCs.
## Node name is the peer id; that peer is the authority for this body.
class_name Player
extends CharacterBody3D

const MOUSE_SENS := 0.0022
const PITCH_MIN := -1.2
const PITCH_MAX := 0.6
const SYNC_INTERVAL := 1.0 / 30.0
const ACCEL := 40.0
const RESPAWN_SECONDS := 4.0

var form: FormData
var form_id := "human"
var max_health := 100.0
var health := 100.0
var dead := false
var display_name := "Player"

# Ability cooldowns (msec timestamps).
var cd_ready := [0, 0, 0, 0]
var cd_total := [0.0, 0.0, 0.0, 0.0]

# Mutrix / status.
var last_combat_ms := -1_000_000
var buff_until := 0
var buff_factor := 1.0
var stealth_until := 0
var slow_until := 0
var slow_factor := 1.0
var stun_until := 0
var overcharge_until := 0
var overcharge_factor := 1.0
var overcharge_ready := false

# Dash state.
var dash_until := 0
var dash_dir := Vector3.ZERO
var dash_speed := 0.0
var dash_damage := 0.0
var dash_stun := 0.0
var dash_hit: Array = []

var yaw := 0.0
var pitch := -0.2
var runner: AbilityRunner
var model: Node3D
var hud: Hud
var _sync_accum := 0.0
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _has_net := false

@onready var pivot: Node3D = $CamPivot
@onready var arm: SpringArm3D = $CamPivot/Arm
@onready var cam: Camera3D = $CamPivot/Arm/Camera
@onready var model_root: Node3D = $ModelRoot
@onready var collider: CollisionShape3D = $Collider
@onready var name_label: Label3D = $NameLabel

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func is_local() -> bool:
	return is_multiplayer_authority()

func peer_id() -> int:
	return name.to_int()

func _ready() -> void:
	add_to_group("players")
	add_to_group("damageable")
	runner = AbilityRunner.new(self)
	cam.current = is_local()
	arm.add_excluded_object(get_rid())
	yaw = rotation.y
	_apply_form(Game.get_form("human"))
	if is_local():
		display_name = Game.player_name
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		hud = Hud.new()
		hud.player = self
		add_child(hud)
		name_label.visible = false
		global_position = Game.random_spawn()
		multiplayer.peer_connected.connect(func(_id): _announce.rpc(display_name, form_id, health))
		_announce.rpc(display_name, form_id, health)
	Game.register_player(self)

func _exit_tree() -> void:
	Game.unregister_player(self)

# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not is_local():
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * MOUSE_SENS
		pitch = clamp(pitch - event.relative.y * MOUSE_SENS, PITCH_MIN, PITCH_MAX)
	if event.is_action_pressed("toggle_mouse"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed("basic"): runner.cast(0)
	elif event.is_action_pressed("ability1"): runner.cast(1)
	elif event.is_action_pressed("ability2"): runner.cast(2)
	elif event.is_action_pressed("ultimate"): runner.cast(3)
	for i in 4:
		if event.is_action_pressed("form_%d" % (i + 1)):
			if i < Game.form_order.size():
				request_mutate(Game.form_order[i])

func _process(_delta: float) -> void:
	# Hold-to-fire for the basic attack.
	if is_local() and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed("basic"):
		runner.cast(0)
	_update_visual_status()

# ---------------------------------------------------------------- movement

func _physics_process(delta: float) -> void:
	if is_local():
		rotation.y = yaw
		pivot.rotation.x = pitch
		_move(delta)
		_sync_accum += delta
		if _sync_accum >= SYNC_INTERVAL:
			_sync_accum = 0.0
			_sync.rpc(global_position, yaw, velocity)
	else:
		if _has_net:
			global_position = global_position.lerp(_net_pos, 0.35)
			rotation.y = lerp_angle(rotation.y, _net_yaw, 0.35)

func _move(delta: float) -> void:
	if dead:
		velocity = Vector3.ZERO
		return
	var now := Time.get_ticks_msec()
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	if now < dash_until:
		velocity = dash_dir * dash_speed
		move_and_slide()
		_dash_hits()
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	if now < stun_until:
		velocity.x = move_toward(velocity.x, 0, ACCEL * delta)
		velocity.z = move_toward(velocity.z, 0, ACCEL * delta)
		move_and_slide()
		return
	var wish := move_input_world()
	var speed := form.move_speed
	if now < slow_until:
		speed *= slow_factor
	var target := wish * speed
	velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = form.jump_velocity
	move_and_slide()
	if global_position.y < -20.0:
		global_position = Game.random_spawn()
		velocity = Vector3.ZERO

func move_input_world() -> Vector3:
	var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(inp.x, 0, inp.y))
	dir.y = 0
	return dir.normalized() if dir.length() > 0.01 else Vector3.ZERO

func facing() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0
	return f.normalized()

func face_toward(point: Vector3) -> void:
	var f := point - global_position
	yaw = atan2(-f.x, -f.z)
	rotation.y = yaw

func start_dash(dir: Vector3, speed: float, duration: float, damage: float, stun: float) -> void:
	dash_dir = dir.normalized()
	dash_speed = speed
	dash_until = Time.get_ticks_msec() + int(duration * 1000.0)
	dash_damage = damage
	dash_stun = stun
	dash_hit.clear()
	if dash_damage > 0.0:
		face_toward(global_position + dash_dir)

func _dash_hits() -> void:
	if dash_damage <= 0.0:
		return
	for t in targets_in_radius(1.8):
		if t in dash_hit:
			continue
		dash_hit.append(t)
		deal_damage(t, dash_damage, dash_dir * 6.0 + Vector3(0, 3, 0))
		if dash_stun > 0.0:
			t.apply_status.rpc("stun", dash_stun, 0.0)

# ---------------------------------------------------------------- aiming helpers

func muzzle_position() -> Vector3:
	return global_position + Vector3(0, 1.3, 0) + facing() * 0.9

## Direction from `origin` to whatever the crosshair is looking at.
func aim_direction_from(origin: Vector3) -> Vector3:
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var hit := raycast(from, dir, 120.0)
	var point: Vector3 = hit.position if not hit.is_empty() else from + dir * 120.0
	var d := point - origin
	if d.dot(dir) < 0.0:
		return dir
	return d.normalized()

func raycast(from: Vector3, dir: Vector3, length: float) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir.normalized() * length)
	q.exclude = [get_rid()]
	q.collide_with_areas = false
	return space.intersect_ray(q)

func _is_enemy(n: Node) -> bool:
	return n != self and n is Node3D and n.get("dead") == false

func targets_in_radius(radius: float) -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("damageable"):
		if not _is_enemy(n):
			continue
		if n.global_position.distance_to(global_position) <= radius:
			out.append(n)
	return out

func targets_in_cone(reach: float, half_angle_deg: float) -> Array:
	var out: Array = []
	var f := facing()
	for n in get_tree().get_nodes_in_group("damageable"):
		if not _is_enemy(n):
			continue
		var to: Vector3 = n.global_position - global_position
		var flat := Vector3(to.x, 0, to.z)
		var dist := flat.length()
		if dist > reach + 0.6 or abs(to.y) > 2.5:
			continue
		if dist < 0.6 or rad_to_deg(f.angle_to(flat.normalized())) <= half_angle_deg:
			out.append(n)
	return out

func nearest_in_cone(reach: float, half_angle_deg: float) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for n in targets_in_cone(reach, half_angle_deg):
		var d: float = n.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = n
	return best

# ---------------------------------------------------------------- cooldowns / status

func is_on_cooldown(slot: int) -> bool:
	return Time.get_ticks_msec() < cd_ready[slot]

func start_cooldown(slot: int, seconds: float) -> void:
	cd_ready[slot] = Time.get_ticks_msec() + int(seconds * 1000.0)
	cd_total[slot] = seconds

func cooldown_remaining(slot: int) -> float:
	return max(0.0, (cd_ready[slot] - Time.get_ticks_msec()) / 1000.0)

func is_stunned() -> bool:
	return Time.get_ticks_msec() < stun_until

func is_stealthed() -> bool:
	return Time.get_ticks_msec() < stealth_until

func is_overcharged() -> bool:
	return Time.get_ticks_msec() < overcharge_until

## Seconds until the Mutrix unlocks after combat. 0 means ready.
func mutrix_lock_remaining() -> float:
	if overcharge_ready and is_overcharged():
		return 0.0
	var since := (Time.get_ticks_msec() - last_combat_ms) / 1000.0
	return max(0.0, Game.MUTRIX_LOCK_SECONDS - since)

func can_mutate() -> bool:
	return not dead and mutrix_lock_remaining() <= 0.0

@rpc("any_peer", "call_local", "reliable")
func apply_status(kind: String, duration: float, factor: float) -> void:
	var until := Time.get_ticks_msec() + int(duration * 1000.0)
	match kind:
		"buff":
			buff_until = until
			buff_factor = factor
		"stealth":
			stealth_until = until
		"slow":
			slow_until = until
			slow_factor = factor
		"stun":
			stun_until = until
			Fx.burst(global_position + Vector3(0, 2.2, 0), Color(1, 1, 0.6), 0.8, 0.3)
		"overcharge":
			overcharge_until = until
			overcharge_factor = factor
			overcharge_ready = true

func _update_visual_status() -> void:
	if model == null:
		return
	var alpha := 1.0
	if is_stealthed():
		alpha = 0.35 if is_local() else 0.08
	Cel.set_param(model, "alpha", alpha)
	Cel.set_param(model, "emission_strength", 0.8 if is_overcharged() else 0.0)
	if name_label != null and not is_local():
		name_label.visible = not dead and not is_stealthed()

# ---------------------------------------------------------------- damage

## Called on the attacker's peer. Broadcasts the hit to everyone.
func deal_damage(target: Node, amount: float, knock: Vector3) -> void:
	if target == null or not target.has_method("receive_hit"):
		return
	if is_overcharged():
		amount *= overcharge_factor
	last_combat_ms = Time.get_ticks_msec()
	target.receive_hit.rpc(amount, peer_id(), knock)

@rpc("any_peer", "call_local", "reliable")
func receive_hit(amount: float, from_peer: int, knock: Vector3) -> void:
	if dead:
		return
	var now := Time.get_ticks_msec()
	var dmg := amount
	if now < buff_until:
		dmg *= buff_factor
	health = max(0.0, health - dmg)
	last_combat_ms = now
	Fx.hit(global_position)
	if is_local():
		velocity += knock
		if health <= 0.0:
			_die(from_peer)

func _die(killer_peer: int) -> void:
	set_dead.rpc(true)
	Game.announce_kill.rpc(killer_peer, peer_id())
	await get_tree().create_timer(RESPAWN_SECONDS).timeout
	if not is_inside_tree():
		return
	global_position = Game.random_spawn()
	velocity = Vector3.ZERO
	last_combat_ms = -1_000_000
	set_form.rpc("human")
	set_health.rpc(max_health)
	set_dead.rpc(false)

@rpc("any_peer", "call_local", "reliable")
func set_dead(v: bool) -> void:
	dead = v
	model_root.visible = not v
	collider.set_deferred("disabled", v)
	if v:
		Fx.burst(global_position + Vector3(0, 1, 0), Color(1, 0.2, 0.2), 2.5, 0.5)

@rpc("any_peer", "call_local", "reliable")
func set_health(v: float) -> void:
	health = v

# ---------------------------------------------------------------- forms / Mutrix

func request_mutate(id: String) -> void:
	if not is_local() or id == form_id:
		return
	if not can_mutate():
		return
	if overcharge_ready:
		overcharge_ready = false
	set_form.rpc(id)

@rpc("any_peer", "call_local", "reliable")
func set_form(id: String) -> void:
	var f := Game.get_form(id)
	if f == null:
		return
	Fx.mutate(global_position, f.color)
	_apply_form(f)

func _apply_form(f: FormData) -> void:
	if f == null:
		return
	var ratio := 1.0 if max_health <= 0.0 else health / max_health
	form = f
	form_id = f.id
	max_health = f.max_health
	health = clamp(ratio * max_health, 1.0, max_health)
	for i in 4:
		cd_ready[i] = 0
	if model != null:
		model.queue_free()
	model = ModelFactory.build(f)
	model_root.add_child(model)
	var cap := collider.shape as CapsuleShape3D
	if cap != null:
		cap = cap.duplicate()
		cap.height = 1.8 * f.size
		cap.radius = 0.4 * f.size
		collider.shape = cap
		collider.position.y = 0.9 * f.size
	pivot.position.y = 1.6 * f.size

# ---------------------------------------------------------------- net sync

@rpc("authority", "call_remote", "unreliable_ordered")
func _sync(pos: Vector3, y: float, vel: Vector3) -> void:
	_net_pos = pos
	_net_yaw = y
	velocity = vel
	if not _has_net:
		global_position = pos
		_has_net = true

@rpc("authority", "call_remote", "reliable")
func _announce(pname: String, fid: String, hp: float) -> void:
	display_name = pname
	name_label.text = pname
	if fid != form_id:
		_apply_form(Game.get_form(fid))
	health = hp

@rpc("any_peer", "call_local", "reliable")
func spawn_projectile(origin: Vector3, dir: Vector3, slot: int) -> void:
	if form == null or slot >= form.abilities.size():
		return
	var pr := Projectile.new()
	pr.setup(origin, dir, form.abilities[slot], self, is_local())
	get_tree().current_scene.add_child(pr)

# Effects, broadcast so everyone sees them.
@rpc("any_peer", "call_local", "unreliable")
func fx_swing(color: Color, reach: float) -> void:
	Fx.swing(self, color, reach)

@rpc("any_peer", "call_local", "unreliable")
func fx_ring(pos: Vector3, radius: float, color: Color) -> void:
	Fx.ring(pos, radius, color)

@rpc("any_peer", "call_local", "unreliable")
func fx_burst(pos: Vector3, color: Color, size: float) -> void:
	Fx.burst(pos, color, size)

@rpc("any_peer", "call_local", "unreliable")
func fx_beam(a: Vector3, b: Vector3, color: Color) -> void:
	Fx.beam(a, b, color)
