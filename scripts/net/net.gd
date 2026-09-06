extends Node

signal lobby_updated(code: String, players: Array, is_host: bool)
signal match_updated(snapshot: Dictionary)
signal match_started
signal connection_failed(msg: String)
signal notice(msg: String)

const DuckServerScript = preload("res://scripts/net/server.gd")

var server_url := "ws://127.0.0.1:9080"
var room_code := ""
var player_id := ""
var is_host := false
var last_snapshot: Dictionary = {}
var _display_name := "Mallard"
var _pending_action := "" # create | join
var _pending_join_code := ""
var _logic
var _is_server := false
var _server_pid := -1
var _connect_tries := 0
var _retrying := false


func start_server(port: int) -> void:
	_is_server = true
	_logic = DuckServerScript.new()
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_server(port, "*")
	if err != OK:
		push_error("Could not bind server on %s: %s" % [port, err])
		print("Failed to bind WebSocket server on port %s (error %s)" % [port, err])
		return
	multiplayer.multiplayer_peer = peer
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("Show me your duck server on port %s" % port)
	print("Clients should connect to ws://127.0.0.1:%s" % port)
	notice.emit("Server listening on %s" % port)


func connect_and_create(display_name: String) -> void:
	_display_name = display_name
	_pending_action = "create"
	_connect_tries = 0
	_ensure_connected()


func connect_and_join(code: String, display_name: String) -> void:
	_display_name = display_name
	_pending_action = "join"
	_pending_join_code = code
	_connect_tries = 0
	_ensure_connected()


func _is_client_connected() -> bool:
	if _is_server:
		return false
	var peer = multiplayer.multiplayer_peer
	if peer == null:
		return false
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	# Godot's default/offline peer is always "connected" as id 1.
	return multiplayer.get_unique_id() != 1


func _ensure_connected() -> void:
	if _is_client_connected():
		_finish_pending()
		return
	if _url_is_loopback() and _server_pid == -1 and _connect_tries == 0:
		notice.emit("Starting a local server…")
		_spawn_dedicated_server()
		_connect_tries = 1
		get_tree().create_timer(0.7).timeout.connect(_begin_client_connect, CONNECT_ONE_SHOT)
		return
	_begin_client_connect()


func _begin_client_connect() -> void:
	_connect_tries += 1
	if not _is_server:
		multiplayer.multiplayer_peer = null
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_client(server_url)
	if err != OK:
		_on_connection_failed()
		return
	multiplayer.multiplayer_peer = peer
	if not multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.connect(_on_connected)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	var try_id := _connect_tries
	get_tree().create_timer(0.8).timeout.connect(_connect_watchdog.bind(try_id), CONNECT_ONE_SHOT)


func _connect_watchdog(try_id: int) -> void:
	if try_id != _connect_tries:
		return
	if _pending_action == "" or _is_client_connected():
		return
	_on_connection_failed()


func _on_connected() -> void:
	_retrying = false
	_connect_tries = 0
	_finish_pending()


func _on_connection_failed() -> void:
	if _pending_action == "":
		return
	if _url_is_loopback() and _server_pid == -1:
		notice.emit("Starting a local server…")
		_spawn_dedicated_server()
	if _connect_tries < 12:
		_retrying = true
		get_tree().create_timer(0.4).timeout.connect(_begin_client_connect, CONNECT_ONE_SHOT)
		return
	_retrying = false
	connection_failed.emit("Could not reach %s. Run run_server.bat and keep that window open." % server_url)


func _url_is_loopback() -> bool:
	var url := server_url.to_lower()
	return "127.0.0.1" in url or "localhost" in url


func _spawn_dedicated_server() -> void:
	if _server_pid != -1:
		return
	var exe := OS.get_executable_path()
	var project := ProjectSettings.globalize_path("res://").rstrip("/").rstrip("\\")
	var args := PackedStringArray([
		"--headless",
		"--path",
		project,
		"--",
		"--server",
		"--port",
		"9080",
	])
	_server_pid = OS.create_process(exe, args, true)
	if _server_pid == -1:
		push_error("Could not spawn dedicated server process")
	else:
		print("Spawned dedicated server pid %s" % _server_pid)


func _on_server_disconnected() -> void:
	room_code = ""
	last_snapshot = {}
	connection_failed.emit("Disconnected from server")


func _finish_pending() -> void:
	if not _is_client_connected():
		connection_failed.emit("Not connected to a dedicated server. Try Create room again, or run run_server.bat.")
		return
	if _pending_action == "create":
		rpc_id(1, "s_create_room", _display_name)
	elif _pending_action == "join":
		rpc_id(1, "s_join_room", _pending_join_code, _display_name)
	_pending_action = ""


func start_match() -> void:
	if not _is_client_connected():
		connection_failed.emit("Not connected to a server.")
		return
	rpc_id(1, "s_start_match")


func submit_intent(intent: Dictionary) -> void:
	if not _is_client_connected():
		return
	rpc_id(1, "s_intent", intent)


func leave_room() -> void:
	if _is_client_connected():
		rpc_id(1, "s_leave")
	room_code = ""
	player_id = ""
	is_host = false
	last_snapshot = {}


@rpc("any_peer", "reliable")
func s_create_room(display_name: String) -> void:
	if not _is_server:
		return
	var peer := multiplayer.get_remote_sender_id()
	var result: Dictionary = _logic.create_room(peer, display_name)
	if not result.ok:
		rpc_id(peer, "c_error", result.get("error", "Create failed"))
		return
	_broadcast_lobby(String(result.code))


@rpc("any_peer", "reliable")
func s_join_room(code: String, display_name: String) -> void:
	if not _is_server:
		return
	var peer := multiplayer.get_remote_sender_id()
	var result: Dictionary = _logic.join_room(peer, code, display_name)
	if not result.ok:
		rpc_id(peer, "c_error", result.get("error", "Join failed"))
		return
	_broadcast_lobby(String(result.code))


@rpc("any_peer", "reliable")
func s_start_match() -> void:
	if not _is_server:
		return
	var peer := multiplayer.get_remote_sender_id()
	var result: Dictionary = _logic.start_match(peer)
	if not result.ok:
		rpc_id(peer, "c_error", result.get("error", "Start failed"))
		return
	var code: String = _logic.room_code_for(peer)
	_broadcast_lobby(code)
	_broadcast_match(code, true)


@rpc("any_peer", "reliable")
func s_intent(intent: Dictionary) -> void:
	if not _is_server:
		return
	var peer := multiplayer.get_remote_sender_id()
	var result: Dictionary = _logic.apply_intent(peer, intent)
	if not result.ok:
		rpc_id(peer, "c_error", result.get("error", "Illegal play"))
		return
	_broadcast_match(_logic.room_code_for(peer), false)


@rpc("any_peer", "reliable")
func s_leave() -> void:
	if not _is_server:
		return
	_server_drop(multiplayer.get_remote_sender_id())


@rpc("authority", "reliable")
func c_lobby(code: String, players: Array, your_player_id: String, host: bool) -> void:
	room_code = code
	player_id = your_player_id
	is_host = host
	lobby_updated.emit(code, players, host)


@rpc("authority", "reliable")
func c_match(snapshot: Dictionary, just_started: bool) -> void:
	last_snapshot = snapshot
	if just_started:
		match_started.emit()
	match_updated.emit(snapshot)


@rpc("authority", "reliable")
func c_error(msg: String) -> void:
	notice.emit(msg)


@rpc("authority", "reliable")
func c_kicked(msg: String) -> void:
	room_code = ""
	last_snapshot = {}
	connection_failed.emit(msg)


func _broadcast_lobby(code: String) -> void:
	if code == "" or not _logic.rooms.has(code):
		return
	var snap: Dictionary = _logic.lobby_snapshot(code)
	for p in snap.players:
		rpc_id(int(p.peer_id), "c_lobby", code, snap.players, String(p.player_id), bool(p.host))


func _broadcast_match(code: String, just_started: bool) -> void:
	var snaps: Dictionary = _logic.snapshots_for_room(code)
	for peer in snaps.keys():
		rpc_id(int(peer), "c_match", snaps[peer], just_started)


func _on_peer_disconnected(peer_id: int) -> void:
	if _is_server:
		_server_drop(peer_id)


func _server_drop(peer_id: int) -> void:
	var code: String = _logic.room_code_for(peer_id)
	var remaining := []
	if code != "" and _logic.rooms.has(code):
		remaining = _logic.rooms[code].peers.keys()
	var closed: String = _logic.leave(peer_id)
	if closed == "":
		return
	if not _logic.rooms.has(closed):
		for pid in remaining:
			if int(pid) != peer_id:
				rpc_id(int(pid), "c_kicked", "Host left — room closed")
		return
	_broadcast_lobby(closed)
	if _logic.rooms[closed].state == null:
		for pid in _logic.rooms[closed].peers.keys():
			rpc_id(int(pid), "c_error", "A player left. Back to the lobby.")
