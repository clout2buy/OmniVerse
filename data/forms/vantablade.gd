## Assassin. High damage, low health. Shadow creature with blade arms.
extends FormData

func _init() -> void:
	id = "vantablade"
	display_name = "Vantablade"
	role = "assassin"
	max_health = 70.0
	move_speed = 7.5
	jump_velocity = 8.0
	size = 1.05
	color = Color(0.16, 0.1, 0.28)
	model_path = "res://assets/models/vantablade.glb"
	lore = "A mutation grown from something that lives between shadows. Its arms end in edges."
	abilities = [
		AbilityData.make({ "id": "claw", "display_name": "Claw Combo", "kind": AbilityData.Kind.MELEE,
			"damage": 14.0, "cooldown": 0.3, "range": 2.6, "color": Color(0.6, 0.3, 1.0),
			"description": "Fast slashes." }),
		AbilityData.make({ "id": "blink", "display_name": "Blink", "kind": AbilityData.Kind.BLINK,
			"damage": 0.0, "cooldown": 6.0, "range": 8.0, "color": Color(0.6, 0.3, 1.0),
			"description": "Teleport forward. Lands behind an enemy if one is in the way." }),
		AbilityData.make({ "id": "veil", "display_name": "Smoke Veil", "kind": AbilityData.Kind.STEALTH,
			"damage": 0.0, "cooldown": 14.0, "duration": 3.0, "color": Color(0.3, 0.3, 0.35),
			"description": "Become nearly invisible for 3s." }),
		AbilityData.make({ "id": "execute", "display_name": "Execute", "kind": AbilityData.Kind.EXECUTE,
			"damage": 30.0, "cooldown": 40.0, "range": 3.0, "factor": 0.35, "color": Color(1, 0.1, 0.2),
			"description": "Heavy strike. Instantly kills targets below 35% health." }),
	]
