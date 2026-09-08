## Root scene: arena, lobby UI, and player spawning.
extends Node3D

const PLAYER_SCENE := "res://scenes/player.tscn"

@onready var players: Node3D = $Players
@onready var spawner: MultiplayerSpawner = $Spawner
@onready var ui: CanvasLayer = $UI

var lobby: Control
var status_label: Label
var code_label: Label
var name_edit: LineEdit
var code_edit: LineEdit
var update_label: Label
var update_btn: Button

func _ready() -> void:
	add_child(Arena.new())
	_spawn_dummies()
	spawner.spawn_path = players.get_path()
	spawner.add_spawnable_scene(PLAYER_SCENE)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(func(): lobby.hide())
	multiplayer.connection_failed.connect(func(): lobby.show())
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	Net.status_changed.connect(func(m): status_label.text = m)
	Net.code_ready.connect(_on_code_ready)
	_build_lobby()
	# `godot -- --solo` hosts immediately (used by tools/check.ps1 and for quick testing).
	if "--solo" in OS.get_cmdline_user_args():
		_on_host()
	# `godot -- --solo --screenshot out.png` saves a frame after ~1.5s and quits. For Ares to look at its work.
	var args := OS.get_cmdline_user_args()
	var si := args.find("--screenshot")
	if si >= 0 and si + 1 < args.size():
		_screenshot_then_quit(args[si + 1])

func _screenshot_then_quit(path: String) -> void:
	# Optional `--form <id>` mutates the local player first, to preview a creature.
	var args := OS.get_cmdline_user_args()
	var fi := args.find("--form")
	await get_tree().create_timer(0.3).timeout
	if fi >= 0 and fi + 1 < args.size():
		var p := players.get_node_or_null("1")
		if p != null:
			p.set_form.rpc(args[fi + 1])
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("screenshot saved: ", path)
	get_tree().quit()

func _spawn_dummies() -> void:
	var spots := [Vector3(4, 0, -6), Vector3(-6, 0, 4), Vector3(0, 0, -16)]
	for i in spots.size():
		var d := Dummy.new()
		d.name = "Dummy%d" % i
		d.position = spots[i]
		add_child(d)

# ---------------------------------------------------------------- players

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		_add_player(id)

func _on_peer_disconnected(id: int) -> void:
	var p := players.get_node_or_null(str(id))
	if p != null:
		p.queue_free()

func _on_server_disconnected() -> void:
	for p in players.get_children():
		p.queue_free()
	Net.leave()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	lobby.show()

func _add_player(id: int) -> void:
	var p: Node3D = load(PLAYER_SCENE).instantiate()
	p.name = str(id)
	players.add_child(p, true)

# ---------------------------------------------------------------- lobby

func _build_lobby() -> void:
	lobby = PanelContainer.new()
	lobby.set_anchors_preset(Control.PRESET_CENTER)
	lobby.custom_minimum_size = Vector2(460, 0)
	lobby.position = Vector2(-230, -180)
	ui.add_child(lobby)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	lobby.add_child(v)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	lobby.remove_child(v)
	lobby.add_child(margin)
	margin.add_child(v)

	var title := Label.new()
	title.text = "OMNIVERSE"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.24, 0.95, 0.54))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := Label.new()
	sub.text = "Mutrix arena prototype"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(1, 1, 1, 0.6)
	v.add_child(sub)

	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Your name"
	name_edit.text = "Player%d" % (randi() % 900 + 100)
	v.add_child(name_edit)

	var host_btn := Button.new()
	host_btn.text = "HOST  (play solo or invite friends)"
	host_btn.pressed.connect(_on_host)
	v.add_child(host_btn)

	code_label = Label.new()
	code_label.text = ""
	code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_label.add_theme_font_size_override("font_size", 20)
	v.add_child(code_label)

	var h := HBoxContainer.new()
	v.add_child(h)
	code_edit = LineEdit.new()
	code_edit.placeholder_text = "Join code  (or ip:port, or localhost)"
	code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(code_edit)
	var join_btn := Button.new()
	join_btn.text = "JOIN"
	join_btn.pressed.connect(_on_join)
	h.add_child(join_btn)

	status_label = Label.new()
	status_label.text = "Host a match, or paste a friend's code."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.modulate = Color(1, 1, 1, 0.8)
	v.add_child(status_label)

	var hint := Label.new()
	hint.text = "Friends over the internet need the host to forward UDP port 7777.\nOn the same Wi-Fi, use the LAN code."
	hint.modulate = Color(1, 1, 1, 0.45)
	hint.add_theme_font_size_override("font_size", 12)
	v.add_child(hint)

func _refresh_update() -> void:
	update_label.text = Updater.status_text()
	update_btn.visible = Updater.state == Updater.State.AVAILABLE
	if Updater.state == Updater.State.AVAILABLE:
		update_btn.text = "UPDATE TO v%s" % Updater.latest_version
		update_label.modulate = Color(0.24, 0.95, 0.54)

func _on_host() -> void:
	Game.player_name = name_edit.text.strip_edges() if name_edit.text.strip_edges() != "" else "Host"
	if Net.host():
		_add_player(1)
		lobby.hide()

func _on_join() -> void:
	Game.player_name = name_edit.text.strip_edges() if name_edit.text.strip_edges() != "" else "Guest"
	if Net.join(code_edit.text):
		lobby.hide()

func _on_code_ready(code: String, lan_code: String) -> void:
	var text := ""
	if code != "":
		text += "CODE  %s\n" % code
	text += "LAN   %s" % lan_code
	code_label.text = text
	DisplayServer.clipboard_set(code if code != "" else lan_code)
	status_label.text += "  (code copied to clipboard)"

func _unhandled_input(event: InputEvent) -> void:
	# Esc in the lobby shows codes again while playing.
	if event.is_action_pressed("toggle_mouse") and multiplayer.multiplayer_peer != null and Net.is_host:
		lobby.visible = Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE
