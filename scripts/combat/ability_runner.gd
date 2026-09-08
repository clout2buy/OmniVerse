## Executes AbilityData on behalf of a Player. One place to look for "what does kind X do".
## Only ever runs on the player's own (authoritative) peer; results are broadcast via Player RPCs.
class_name AbilityRunner
extends RefCounted

const CONE_HALF_ANGLE := 55.0
const MAX_CHAIN_TARGETS := 4

var p: Player

func _init(player: Player) -> void:
	p = player

func cast(slot: int) -> bool:
	if p.dead or p.form == null:
		return false
	if slot < 0 or slot >= p.form.abilities.size():
		return false
	if p.is_on_cooldown(slot) or p.is_stunned():
		return false
	var ab: AbilityData = p.form.abilities[slot]
	match ab.kind:
		AbilityData.Kind.MELEE: _melee(ab)
		AbilityData.Kind.PROJECTILE: _projectile(ab, slot)
		AbilityData.Kind.DASH: _dash(ab)
		AbilityData.Kind.BLINK: _blink(ab)
		AbilityData.Kind.BUFF: _buff(ab)
		AbilityData.Kind.AOE: _aoe(ab)
		AbilityData.Kind.STEALTH: _stealth(ab)
		AbilityData.Kind.EXECUTE: _execute(ab)
		AbilityData.Kind.CHAIN: _chain(ab)
		AbilityData.Kind.OVERCHARGE: _overcharge(ab)
	p.start_cooldown(slot, ab.cooldown)
	return true

func _melee(ab: AbilityData) -> void:
	p.fx_swing.rpc(ab.color, ab.range)
	for t in p.targets_in_cone(ab.range, CONE_HALF_ANGLE):
		p.deal_damage(t, ab.damage, p.facing() * 3.0)

func _projectile(ab: AbilityData, slot: int) -> void:
	var origin := p.muzzle_position()
	var dir := p.aim_direction_from(origin)
	p.spawn_projectile.rpc(origin, dir, slot)

func _dash(ab: AbilityData) -> void:
	var dir := p.facing()
	if ab.damage <= 0.0:
		# Pure mobility (dodge roll): follow movement input if any.
		var inp := p.move_input_world()
		if inp.length() > 0.1:
			dir = inp
	var duration: float = ab.range / max(ab.speed, 0.1)
	p.start_dash(dir, ab.speed, duration, ab.damage, ab.duration)
	p.fx_ring.rpc(p.global_position, 1.5, ab.color)

func _blink(ab: AbilityData) -> void:
	var dest: Vector3
	var target := p.nearest_in_cone(ab.range, 30.0)
	if target != null:
		var away: Vector3 = (target.global_position - p.global_position)
		away.y = 0
		away = away.normalized()
		dest = target.global_position + away * 1.4
		p.face_toward(target.global_position)
	else:
		var dir := p.facing()
		var hit := p.raycast(p.global_position + Vector3(0, 1.0, 0), dir, ab.range)
		if hit.is_empty():
			dest = p.global_position + dir * ab.range
		else:
			dest = hit.position - dir * 0.8
			dest.y = p.global_position.y
	p.fx_burst.rpc(p.global_position + Vector3(0, 1, 0), ab.color, 1.5)
	p.global_position = dest
	p.fx_burst.rpc(dest + Vector3(0, 1, 0), ab.color, 1.5)

func _buff(ab: AbilityData) -> void:
	p.apply_status.rpc("buff", ab.duration, ab.factor)
	p.fx_ring.rpc(p.global_position, 2.0, ab.color)

func _aoe(ab: AbilityData) -> void:
	p.fx_ring.rpc(p.global_position, ab.radius, ab.color)
	for t in p.targets_in_radius(ab.radius):
		var knock := Vector3.ZERO
		if ab.speed > 0.0:
			knock = (t.global_position - p.global_position).normalized() * ab.speed + Vector3(0, 4, 0)
		p.deal_damage(t, ab.damage, knock)
		if ab.duration > 0.0:
			if ab.factor <= 0.0:
				t.apply_status.rpc("stun", ab.duration, 0.0)
			else:
				t.apply_status.rpc("slow", ab.duration, ab.factor)

func _stealth(ab: AbilityData) -> void:
	p.apply_status.rpc("stealth", ab.duration, 0.0)

func _execute(ab: AbilityData) -> void:
	p.fx_swing.rpc(ab.color, ab.range)
	var t := p.nearest_in_cone(ab.range, CONE_HALF_ANGLE)
	if t == null:
		return
	var frac: float = t.health / max(t.max_health, 1.0)
	var dmg := ab.damage
	if frac <= ab.factor:
		dmg = 99999.0
	p.deal_damage(t, dmg, p.facing() * 4.0)

func _chain(ab: AbilityData) -> void:
	var targets := p.targets_in_radius(ab.radius)
	targets.sort_custom(func(a, b): return a.global_position.distance_to(p.global_position) < b.global_position.distance_to(p.global_position))
	var from: Vector3 = p.global_position + Vector3(0, 1.2, 0)
	var n := 0
	for t in targets:
		if n >= MAX_CHAIN_TARGETS:
			break
		var to: Vector3 = t.global_position + Vector3(0, 1.0, 0)
		p.fx_beam.rpc(from, to, ab.color)
		p.deal_damage(t, ab.damage, Vector3.ZERO)
		from = to
		n += 1
	if n == 0:
		p.fx_burst.rpc(from, ab.color, 1.2)

func _overcharge(ab: AbilityData) -> void:
	p.apply_status.rpc("overcharge", ab.duration, ab.factor)
