## Baseline human form. Weak, mobile, always available.
extends FormData

func _init() -> void:
	id = "human"
	display_name = "Human"
	role = "human"
	max_health = 100.0
	move_speed = 6.5
	jump_velocity = 7.0
	size = 1.0
	color = Color(0.86, 0.72, 0.58)
	model_path = "res://assets/models/human.glb"
	lore = "You. Ordinary, until the Mutrix latched onto your wrist."
	abilities = [
		AbilityData.make({ "id": "pistol", "display_name": "Pistol", "kind": AbilityData.Kind.PROJECTILE,
			"damage": 8.0, "cooldown": 0.35, "range": 40.0, "speed": 45.0, "color": Color(1, 0.9, 0.4),
			"description": "Quick, low-damage shot." }),
		AbilityData.make({ "id": "roll", "display_name": "Dodge Roll", "kind": AbilityData.Kind.DASH,
			"damage": 0.0, "cooldown": 3.0, "range": 5.0, "speed": 22.0, "color": Color.WHITE,
			"description": "Short roll in your movement direction." }),
		AbilityData.make({ "id": "flashbang", "display_name": "Flashbang", "kind": AbilityData.Kind.AOE,
			"damage": 5.0, "cooldown": 10.0, "radius": 6.0, "duration": 1.2, "factor": 0.0, "color": Color(1, 1, 1),
			"description": "Stuns nearby enemies briefly." }),
		AbilityData.make({ "id": "overcharge", "display_name": "Mutrix Overcharge", "kind": AbilityData.Kind.OVERCHARGE,
			"damage": 0.0, "cooldown": 45.0, "duration": 8.0, "factor": 1.3, "color": Color(0.24, 0.95, 0.54),
			"description": "Bypass the Mutrix lock. Next mutation is instant and deals +30% damage for 8s." }),
	]
