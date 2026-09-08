## A playable form: the human, or a Mutrix mutation. Subclass in data/forms/*.gd.
class_name FormData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
## "human", "assassin", "tank", "speedster", ... free text for now.
@export var role: String = ""
@export var max_health: float = 100.0
@export var move_speed: float = 6.0
@export var jump_velocity: float = 7.0
## Scale multiplier applied to the model + collider height.
@export var size: float = 1.0
@export var color: Color = Color.WHITE
## Path to a .glb in assets/models. Falls back to a primitive body if missing.
@export var model_path: String = ""
## Exactly four entries: [basic, ability1, ability2, ultimate]
var abilities: Array[AbilityData] = []
@export_multiline var lore: String = ""

func basic() -> AbilityData: return abilities[0]
func ability1() -> AbilityData: return abilities[1]
func ability2() -> AbilityData: return abilities[2]
func ultimate() -> AbilityData: return abilities[3]

func validate() -> Array[String]:
	var errs: Array[String] = []
	if id == "": errs.append("form has no id")
	if abilities.size() != 4: errs.append("%s: needs exactly 4 abilities, has %d" % [id, abilities.size()])
	if max_health <= 0: errs.append("%s: max_health must be > 0" % id)
	if move_speed <= 0: errs.append("%s: move_speed must be > 0" % id)
	for a in abilities:
		if a.cooldown < 0: errs.append("%s/%s: negative cooldown" % [id, a.id])
	return errs
