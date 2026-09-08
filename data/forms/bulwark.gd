## Tank. High health, low damage. Rock-hide brute.
extends FormData

func _init() -> void:
	id = "bulwark"
	display_name = "Bulwark"
	role = "tank"
	max_health = 220.0
	move_speed = 4.8
	jump_velocity = 6.0
	size = 1.5
	color = Color(0.45, 0.38, 0.3)
	model_path = "res://assets/models/bulwark.glb"
	lore = "Living stone. Slow to anger, slower to fall."
	abilities = [
		AbilityData.make({ "id": "slam", "display_name": "Slam", "kind": AbilityData.Kind.MELEE,
			"damage": 18.0, "cooldown": 0.9, "range": 3.2, "color": Color(0.8, 0.6, 0.3),
			"description": "Slow, heavy hit." }),
		AbilityData.make({ "id": "pound", "display_name": "Ground Pound", "kind": AbilityData.Kind.AOE,
			"damage": 20.0, "cooldown": 8.0, "radius": 5.0, "duration": 0.4, "factor": 0.0, "speed": 12.0, "color": Color(0.8, 0.6, 0.3),
			"description": "Damages and knocks back everything nearby." }),
		AbilityData.make({ "id": "stoneskin", "display_name": "Stone Skin", "kind": AbilityData.Kind.BUFF,
			"damage": 0.0, "cooldown": 16.0, "duration": 5.0, "factor": 0.5, "color": Color(0.6, 0.6, 0.6),
			"description": "Take 50% less damage for 5s." }),
		AbilityData.make({ "id": "seismic", "display_name": "Seismic Charge", "kind": AbilityData.Kind.DASH,
			"damage": 35.0, "cooldown": 45.0, "range": 12.0, "speed": 18.0, "duration": 1.5, "color": Color(1, 0.5, 0.1),
			"description": "Unstoppable charge. Enemies hit are stunned for 1.5s." }),
	]
