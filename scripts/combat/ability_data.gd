## One ability slot on a form. Pure data; execution lives in AbilityRunner.
class_name AbilityData
extends Resource

## How the AbilityRunner executes this ability.
enum Kind { MELEE, PROJECTILE, DASH, BLINK, BUFF, AOE, STEALTH, EXECUTE, CHAIN, OVERCHARGE }

@export var id: String = ""
@export var display_name: String = ""
@export var kind: Kind = Kind.MELEE
@export var damage: float = 10.0
@export var cooldown: float = 1.0
## Reach in meters (melee cone length, projectile max travel, dash/blink distance).
@export var range: float = 3.0
## Radius in meters for AOE / chain / execute checks.
@export var radius: float = 4.0
## Seconds for buffs, stealth, slows, stuns.
@export var duration: float = 0.0
## Projectile speed, dash speed.
@export var speed: float = 25.0
## Generic multiplier: buff damage reduction, execute threshold, slow factor.
@export var factor: float = 0.5
## Visual color for projectiles / effects.
@export var color: Color = Color.WHITE
@export_multiline var description: String = ""

static func make(d: Dictionary) -> AbilityData:
	var a := AbilityData.new()
	for k in d.keys():
		a.set(k, d[k])
	return a
