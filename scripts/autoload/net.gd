## Peer-to-peer networking. Host opens a port; friends join with a code the host shares.
## Autoload as "Net".
extends Node

signal status_changed(msg: String)
signal code_ready(code: String, lan_code: String)

const PORT := 7777
const MAX_PLAYERS := 8

const JOIN_TIMEOUT := 12.0

var is_host := false
var public_ip := ""
var local_ip := ""
## "pending" | "open" | "failed" | "" (not attempted)
var upnp_state := ""
var upnp_message := ""
var _upnp_thread: Thread
var _join_timer: SceneTreeTimer

func _ready() -> void:
	status_changed.connect(func(m): print("Net: ", m))
	multiplayer.connected_to_server.connect(func(): status_changed.emit("Connected to host."))
	multiplayer.connection_failed.connect(_on_join_failed)
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
	status_changed.emit("Hosting. Opening port %d on your router..." % PORT)
	_fetch_public_ip()
	_open_port_upnp()
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
	status_changed.emit("Connecting to %s:%d ..." % [target.ip, target.port])
	_join_timer = get_tree().create_timer(JOIN_TIMEOUT)
	_join_timer.timeout.connect(_on_join_timeout)
	return true

func _on_join_timeout() -> void:
	if multiplayer.multiplayer_peer == null or is_host:
		return
	if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		return
	leave()
	_on_join_failed()

func _on_join_failed() -> void:
	leave()
	status_changed.emit("Could not reach the host.\nThe host's game must show 'Port open'. If it shows 'could not open port', they need to forward UDP %d on their router, or you are both on the same Wi-Fi and should use the LAN code." % PORT)

func leave() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_host = false

# ---------------------------------------------------------------- UPnP (automatic port forwarding)

func _open_port_upnp() -> void:
	upnp_state = "pending"
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_worker)

func _upnp_worker() -> void:
	var upnp := UPNP.new()
	var msg := ""
	var ok := false
	var err := upnp.discover(2000, 2, "InternetGatewayDevice")
	if err != UPNP.UPNP_RESULT_SUCCESS:
		msg = "no UPnP router found (%d)" % err
	elif upnp.get_gateway() == null or not upnp.get_gateway().is_valid_gateway():
		msg = "router does not support UPnP"
	else:
		upnp.delete_port_mapping(PORT, "UDP")
		var r := upnp.add_port_mapping(PORT, PORT, "OmniVerse", "UDP", 0)
		if r == UPNP.UPNP_RESULT_SUCCESS:
			ok = true
			var ext := upnp.query_external_address()
			msg = "Port %d open via UPnP (router IP %s)" % [PORT, ext]
			if ext != "" and public_ip == "":
				public_ip = ext
		else:
			msg = "router refused the port mapping (%d)" % r
	call_deferred("_upnp_done", ok, msg)

func _upnp_done(ok: bool, msg: String) -> void:
	if _upnp_thread != null and _upnp_thread.is_started():
		_upnp_thread.wait_to_finish()
	upnp_state = "open" if ok else "failed"
	upnp_message = msg
	if ok:
		status_changed.emit("Hosting. " + msg + ". Share your code.")
	else:
		status_changed.emit("Hosting, but could not open the port automatically: %s.\nFriends over the internet need you to forward UDP %d to this PC. Same Wi-Fi friends can use the LAN code." % [msg, PORT])

func _close_port_upnp() -> void:
	if upnp_state != "open":
		return
	var upnp := UPNP.new()
	if upnp.discover(1000, 1, "InternetGatewayDevice") == UPNP.UPNP_RESULT_SUCCESS:
		upnp.delete_port_mapping(PORT, "UDP")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_close_port_upnp()

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
