## Peer-to-peer networking. Host opens a port; friends join with a code the host shares.
## Autoload as "Net".
extends Node

signal status_changed(msg: String)
signal code_ready(code: String, lan_code: String)

const PORT := 7777
const MAX_PLAYERS := 8

var is_host := false
var public_ip := ""
var local_ip := ""

func _ready() -> void:
	multiplayer.connected_to_server.connect(func(): status_changed.emit("Connected to host."))
	multiplayer.connection_failed.connect(func(): status_changed.emit("Connection failed. Check the code and that the host forwarded port %d." % PORT))
	multiplayer.server_disconnected.connect(func(): status_changed.emit("Host left."))
	multiplayer.peer_connected.connect(func(id): status_changed.emit("Player %d joined." % id))
	multiplayer.peer_disconnected.connect(func(id): status_changed.emit("Player %d left." % id))

func host() -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		status_changed.emit("Could not host (error %d). Is another host running?" % err)
		return false
	multiplayer.multiplayer_peer = peer
	is_host = true
	local_ip = get_local_ip()
	status_changed.emit("Hosting on port %d. Fetching public IP..." % PORT)
	_fetch_public_ip()
	return true

func join(code: String) -> bool:
	var target := JoinCode.decode(code)
	if target.is_empty():
		status_changed.emit("That code is not valid.")
		return false
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(target.ip, target.port)
	if err != OK:
		status_changed.emit("Could not start client (error %d)." % err)
		return false
	multiplayer.multiplayer_peer = peer
	is_host = false
	status_changed.emit("Connecting to %s:%d..." % [target.ip, target.port])
	return true

func leave() -> void:
	multiplayer.multiplayer_peer = null
	is_host = false

func get_local_ip() -> String:
	for addr in IP.get_local_addresses():
		if addr.begins_with("192.168.") or addr.begins_with("10.") or addr.begins_with("172."):
			return addr
	return "127.0.0.1"

func _fetch_public_ip() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		http.queue_free()
		if code == 200:
			public_ip = body.get_string_from_utf8().strip_edges()
			status_changed.emit("Hosting. Share your code.")
		else:
			public_ip = ""
			status_changed.emit("Hosting (could not fetch public IP; LAN code only).")
		code_ready.emit(
			JoinCode.encode(public_ip, PORT) if public_ip != "" else "",
			JoinCode.encode(local_ip, PORT)))
	var err := http.request("https://api.ipify.org")
	if err != OK:
		http.queue_free()
		code_ready.emit("", JoinCode.encode(local_ip, PORT))
