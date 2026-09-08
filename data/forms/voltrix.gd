## Speedster. Medium range, medium damage, medium health. Electric runner.
extends FormData

func _init() -> void:
	id = "voltrix"
	display_name = "Voltrix"
	role = "speedster"
	max_health = 110.0
	move_speed = 9.5
	jump_velocity = 8.5
	size = 0.95
	color = Color(0.2, 0.75, 1.0)
	model_path = "res://assets/models/voltrix.glb"
	lore = "Static given legs. It never stops moving because it cannot."
	abilities = [
		AbilityData.make({ "id": "bolt", "display_name": "Charged Bolt", "kind": AbilityData.Kind.PROJECTILE,
			"damage": 9.0, "cooldown": 0.25, "range": 25.0, "speed": 40.0, "color": Color(0.5, 0.9, 1.0),
			"description": "Rapid electric shots." }),
		AbilityData.make({ "id": "dashstrike", "display_name": "Dash Strike", "kind": AbilityData.Kind.DASH,
			"damage": 16.0, "cooldown": 5.0, "range": 9.0, "speed": 30.0, "color": Color(0.5, 0.9, 1.0),
			"description": "Dash forward, damaging anything in the path." }),
		AbilityData.make({ "id": "static", "display_name": "Static Field", "kind": AbilityData.Kind.AOE,
			"damage": 8.0, "cooldown": 12.0, "radius": 7.0, "duration": 3.0, "factor": 0.45, "color": Color(0.5, 0.9, 1.0),
			"description": "Slows enemies in the area by 55% for 3s." }),
		AbilityData.make({ "id": "stormsurge", "display_name": "Storm Surge", "kind": AbilityData.Kind.CHAIN,
			"damage": 28.0, "cooldown": 40.0, "radius": 12.0, "color": Color(0.8, 0.95, 1.0),
			"description": "Chain lightning to up to 4 nearby enemies." }),
	]
