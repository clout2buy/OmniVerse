## Global state: form registry, input map, spawn points, scoreboard. Autoload as "Game".
extends Node

signal kill_feed(text: String)
signal scores_changed()

const MUTRIX_LOCK_SECONDS := 15.0

var forms: Dictionary = {}
var form_order: Array[String] = []
var player_name := "Player"
var spawn_points: Array[Vector3] = []
## peer_id -> {"name": String, "kills": int, "deaths": int}
var scores: Dictionary = {}
var players: Dictionary = {}

func _ready() -> void:
	_setup_input()
	forms = FormLoader.load_all()
	form_order = FormLoader.ordered_ids(forms)
	print("OmniVerse: loaded forms ", form_order)

func get_form(id: String) -> FormData:
	return forms.get(id)

func random_spawn() -> Vector3:
	if spawn_points.is_empty():
		return Vector3(0, 2, 0)
	return spawn_points[randi() % spawn_points.size()]

func register_player(p: Player) -> void:
	players[p.peer_id()] = p
	if not scores.has(p.peer_id()):
		scores[p.peer_id()] = { "name": p.display_name, "kills": 0, "deaths": 0 }
	scores_changed.emit()

func unregister_player(p: Player) -> void:
	players.erase(p.peer_id())
	scores.erase(p.peer_id())
	scores_changed.emit()

func name_of(peer: int) -> String:
	if players.has(peer):
		return players[peer].display_name
	if scores.has(peer):
		return scores[peer].name
	return "Player %d" % peer

@rpc("any_peer", "call_local", "reliable")
func announce_kill(killer: int, victim: int) -> void:
	if not scores.has(victim):
		scores[victim] = { "name": name_of(victim), "kills": 0, "deaths": 0 }
	scores[victim].deaths += 1
	var text := "%s died" % name_of(victim)
	if killer != victim and killer != 0:
		if not scores.has(killer):
			scores[killer] = { "name": name_of(killer), "kills": 0, "deaths": 0 }
		scores[killer].kills += 1
		text = "%s killed %s" % [name_of(killer), name_of(victim)]
	kill_feed.emit(text)
	scores_changed.emit()

# ---------------------------------------------------------------- input map

func _setup_input() -> void:
	_key("move_forward", KEY_W)
	_key("move_back", KEY_S)
	_key("move_left", KEY_A)
	_key("move_right", KEY_D)
	_key("jump", KEY_SPACE)
	_mouse("basic", MOUSE_BUTTON_LEFT)
	_key("ability1", KEY_Q)
	_key("ability2", KEY_E)
	_key("ultimate", KEY_R)
	_key("form_1", KEY_1)
	_key("form_2", KEY_2)
	_key("form_3", KEY_3)
	_key("form_4", KEY_4)
	_key("toggle_mouse", KEY_ESCAPE)
	_key("scoreboard", KEY_TAB)

func _key(action: String, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)

func _mouse(action: String, button: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
