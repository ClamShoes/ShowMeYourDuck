extends Node

signal lobby_updated(code: String, players: Array, is_host: bool, min_players: int)
signal match_updated(snapshot: Dictionary)
signal match_started
signal connection_failed(msg: String)
signal notice(msg: String)
signal reveal_progress(target_player_id: String, t: float)
signal reveal_cancel(target_player_id: String)
## Duck owner's hover over the centre pick row; -1 = none.
signal discard_hover(slot: int)
signal duck_art_updated(player_id: String)

const DuckServerScript = preload("res://scripts/net/server.gd")
const DuckDrawing = preload("res://scripts/ui/duck_drawing.gd")
const CardArt = preload("res://scripts/ui/card_art.gd")
const DEFAULT_PORT := 9080
## Duck PNGs (up to DuckDrawing.MAX_BYTES each) can queue together on join; default is 64 KiB.
const WS_BUFFER_BYTES := 1 << 20

var server_url := "ws://127.0.0.1:%s" % DEFAULT_PORT
var room_code := ""
var player_id := ""
var is_host := false
var last_snapshot: Dictionary = {}
var _display_name := "Mallard"
var _cosmetics: Dictionary = {}
var _duck_png := PackedByteArray()
var _pending_action := "" # create | join
var _pending_join_code := ""
var _logic
var _is_server := false
var _server_pid := -1
var _connect_tries := 0
var _retrying := false
var _spawn_attempted := false


func _ready() -> void:
	# Web build talks to the server behind the site it was loaded from (Caddy proxies /ws).
	if OS.has_feature("web"):
		server_url = "wss://%s/ws" % str(JavaScriptBridge.eval("location.host"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--server-url="):
			server_url = arg.get_slice("=", 1)


func _notification(what: int) -> void:
	# Don't leave orphan headless servers behind when the game client exits.
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_kill_spawned_server()


func start_server(port: int, min_players: int = 1) -> void:
	_is_server = true
	_logic = DuckServerScript.new()
	_logic.min_players = min_players
	var peer := _make_ws_peer()
	var err := peer.create_server(port, "*")
	if err != OK:
		push_error("Could not bind server on %s: %s" % [port, err])
		print("Failed to bind WebSocket server on port %s (error %s) — exiting." % [port, err])
		# Critical: exit so failed binds don't accumulate idle headless processes.
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("Show me your duck server on port %s (min %s players)" % [port, min_players])
	print("Clients should connect to ws://127.0.0.1:%s" % port)
	notice.emit("Server listening on %s" % port)


func _make_ws_peer() -> WebSocketMultiplayerPeer:
	var peer := WebSocketMultiplayerPeer.new()
	peer.inbound_buffer_size = WS_BUFFER_BYTES
	peer.outbound_buffer_size = WS_BUFFER_BYTES
	return peer


func connect_and_create(display_name: String, cosmetics: Dictionary = {}) -> void:
	_display_name = display_name
	_cosmetics = cosmetics
	_pending_action = "create"
	_connect_tries = 0
	_ensure_connected()


func connect_and_join(code: String, display_name: String, cosmetics: Dictionary = {}) -> void:
	_display_name = display_name
	_cosmetics = cosmetics
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
	# Prefer an already-running server (run_server.bat). Only spawn if port is free.
	if _url_is_loopback() and not _loopback_port_open(DEFAULT_PORT):
		_maybe_spawn_local_server()
		_connect_tries = 1
		get_tree().create_timer(0.7).timeout.connect(_begin_client_connect, CONNECT_ONE_SHOT)
		return
	_begin_client_connect()


func _begin_client_connect() -> void:
	_connect_tries += 1
	if not _is_server:
		multiplayer.multiplayer_peer = null
	var peer := _make_ws_peer()
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
	# Never spawn on retry — that was creating dozens of headless Godots.
	# Only retry connecting to whatever is (or should be) on the port.
	if _connect_tries < 12:
		_retrying = true
		get_tree().create_timer(0.4).timeout.connect(_begin_client_connect, CONNECT_ONE_SHOT)
		return
	_retrying = false
	connection_failed.emit("Could not reach %s. Run run_server.bat and keep that window open." % server_url)


func _url_is_loopback() -> bool:
	var url := server_url.to_lower()
	return "127.0.0.1" in url or "localhost" in url


func _loopback_port_open(port: int) -> bool:
	var tcp := StreamPeerTCP.new()
	var err := tcp.connect_to_host("127.0.0.1", port)
	if err != OK and err != ERR_BUSY:
		return false
	for _i in 30:
		tcp.poll()
		var status := tcp.get_status()
		if status == StreamPeerTCP.STATUS_CONNECTED:
			tcp.disconnect_from_host()
			return true
		if status == StreamPeerTCP.STATUS_ERROR:
			tcp.disconnect_from_host()
			return false
		OS.delay_msec(10)
	tcp.disconnect_from_host()
	return false


func _maybe_spawn_local_server() -> void:
	if _spawn_attempted or _server_pid != -1:
		return
	if _loopback_port_open(DEFAULT_PORT):
		notice.emit("Using existing server on %s" % DEFAULT_PORT)
		return
	_spawn_attempted = true
	notice.emit("Starting a local server…")
	_spawn_dedicated_server()


func _spawn_dedicated_server() -> void:
	if _server_pid != -1:
		return
	if _loopback_port_open(DEFAULT_PORT):
		print("Port %s already in use — not spawning another server" % DEFAULT_PORT)
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
		str(DEFAULT_PORT),
	])
	_server_pid = OS.create_process(exe, args, false)
	if _server_pid == -1:
		push_error("Could not spawn dedicated server process")
		_spawn_attempted = false
	else:
		print("Spawned dedicated server pid %s" % _server_pid)


func _kill_spawned_server() -> void:
	if _server_pid == -1:
		return
	# Only kill servers we spawned — never touch run_server.bat's process.
	OS.kill(_server_pid)
	print("Stopped spawned server pid %s" % _server_pid)
	_server_pid = -1


func _on_server_disconnected() -> void:
	room_code = ""
	last_snapshot = {}
	connection_failed.emit("Disconnected from server")


func _finish_pending() -> void:
	if not _is_client_connected():
		connection_failed.emit("Not connected to a dedicated server. Try Create room again, or run run_server.bat.")
		return
	if _pending_action == "create":
		rpc_id(1, "s_create_room", _display_name, _cosmetics)
	elif _pending_action == "join":
		rpc_id(1, "s_join_room", _pending_join_code, _display_name, _cosmetics)
	# Reliable + ordered: the room exists by the time this arrives.
	if _pending_action != "" and not _duck_png.is_empty():
		rpc_id(1, "s_set_duck_drawing", _duck_png)
	_pending_action = ""


## Card back/front choice. Applies to the room while in the lobby (picker UI calls this).
func set_cosmetics(cosmetics: Dictionary) -> void:
	_cosmetics = cosmetics
	if _is_client_connected() and room_code != "":
		rpc_id(1, "s_set_cosmetics", cosmetics)


## Duck drawing PNG. Sent now if in a room, and on every create/join after this.
func set_duck_drawing(png: PackedByteArray) -> void:
	_duck_png = png
	if _is_client_connected() and room_code != "":
		rpc_id(1, "s_set_duck_drawing", png)


## Duck upgrade baked mid-match. `progress` (already saved locally) rides along on later joins.
func apply_duck_upgrade(stamp_id: String, png: PackedByteArray, progress: Dictionary) -> void:
	_duck_png = png
	_cosmetics = _cosmetics.merged({"duck_progress": progress}, true)
	if _is_client_connected() and room_code != "":
		rpc_id(1, "s_apply_duck_upgrade", stamp_id, png)


func start_match() -> void:
	if not _is_client_connected():
		connection_failed.emit("Not connected to a server.")
		return
	rpc_id(1, "s_start_match")


func submit_intent(intent: Dictionary) -> void:
	if not _is_client_connected():
		return
	rpc_id(1, "s_intent", intent)


func send_reveal_progress(target_player_id: String, t: float) -> void:
	if not _is_client_connected():
		return
	rpc_id(1, "s_reveal_progress", target_player_id, clampf(t, 0.0, 1.0))


func send_reveal_cancel(target_player_id: String) -> void:
	if not _is_client_connected():
		return
	rpc_id(1, "s_reveal_cancel", target_player_id)


func send_discard_hover(slot: int) -> void:
	if not _is_client_connected():
		return
	rpc_id(1, "s_discard_hover", slot)


func leave_room() -> void:
	if _is_client_connected():
		rpc_id(1, "s_leave")
	room_code = ""
	player_id = ""
	is_host = false
	last_snapshot = {}


@rpc("any_peer", "reliable")
func s_create_room(display_name: String, cosmetics: Dictionary) -> void:
	if not _is_server:
		return
	var peer := multiplayer.get_remote_sender_id()
	var result: Dictionary = _logic.create_room(peer, display_name, cosmetics)
	if not result.ok:
		rpc_id(peer, "c_error", result.get("error", "Create failed"))
		return
	_broadcast_lobby(String(result.code))


@rpc("any_peer", "reliable")
func s_join_room(code: String, display_name: String, cosmetics: Dictionary) -> void:
	if not _is_server:
		return
	var peer := multiplayer.get_remote_sender_id()
	var result: Dictionary = _logic.join_room(peer, code, display_name, cosmetics)
	if not result.ok:
		rpc_id(peer, "c_error", result.get("error", "Join failed"))
		return
	_broadcast_lobby(String(result.code))
	for art in _logic.duck_arts(String(result.code)):
		rpc_id(peer, "c_duck_art", art.player_id, art.rev, art.png)


@rpc("any_peer", "reliable")
func s_set_duck_drawing(png: PackedByteArray) -> void:
	if not _is_server:
		return
	var peer := multiplayer.get_remote_sender_id()
	var result: Dictionary = _logic.set_duck_drawing(peer, png)
	if not result.ok:
		rpc_id(peer, "c_error", result.get("error", "Could not change your duck"))
		return
	for pid in _logic.rooms[result.code].peers.keys():
		rpc_id(int(pid), "c_duck_art", result.player_id, result.rev, png)
	_broadcast_lobby(String(result.code))


@rpc("any_peer", "reliable")
func s_apply_duck_upgrade(stamp_id: String, png: PackedByteArray) -> void:
	if not _is_server:
		return
	var peer := multiplayer.get_remote_sender_id()
	var result: Dictionary = _logic.apply_duck_upgrade(peer, stamp_id, png)
	if not result.ok:
		rpc_id(peer, "c_error", result.get("error", "Could not upgrade your duck"))
		return
	for pid in _logic.rooms[result.code].peers.keys():
		rpc_id(int(pid), "c_duck_art", result.player_id, result.rev, png)
	_broadcast_match(String(result.code), false)


@rpc("any_peer", "reliable")
func s_set_cosmetics(cosmetics: Dictionary) -> void:
	if not _is_server:
		return
	var peer := multiplayer.get_remote_sender_id()
	var result: Dictionary = _logic.set_cosmetics(peer, cosmetics)
	if not result.ok:
		rpc_id(peer, "c_error", result.get("error", "Could not change cards"))
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


@rpc("any_peer", "reliable")
func s_reveal_progress(target_player_id: String, t: float) -> void:
	if not _is_server:
		return
	var peer := multiplayer.get_remote_sender_id()
	var result: Dictionary = _logic.validate_reveal_relay(peer, target_player_id)
	if not result.ok:
		return
	var scrub_t := clampf(t, 0.0, 1.0)
	for pid in result.peer_ids:
		rpc_id(int(pid), "c_reveal_progress", target_player_id, scrub_t)


@rpc("any_peer", "reliable")
func s_reveal_cancel(target_player_id: String) -> void:
	if not _is_server:
		return
	var peer := multiplayer.get_remote_sender_id()
	var result: Dictionary = _logic.validate_reveal_relay(peer, target_player_id)
	if not result.ok:
		return
	for pid in result.peer_ids:
		rpc_id(int(pid), "c_reveal_cancel", target_player_id)


@rpc("any_peer", "reliable")
func s_discard_hover(slot: int) -> void:
	if not _is_server:
		return
	var peer := multiplayer.get_remote_sender_id()
	var result: Dictionary = _logic.validate_discard_hover_relay(peer, slot)
	if not result.ok:
		return
	for pid in result.peer_ids:
		rpc_id(int(pid), "c_discard_hover", slot)


@rpc("authority", "reliable")
func c_lobby(code: String, players: Array, your_player_id: String, host: bool, min_players: int) -> void:
	room_code = code
	player_id = your_player_id
	is_host = host
	lobby_updated.emit(code, players, host, min_players)


@rpc("authority", "reliable")
func c_match(snapshot: Dictionary, just_started: bool) -> void:
	last_snapshot = snapshot
	if just_started:
		match_started.emit()
	match_updated.emit(snapshot)


@rpc("authority", "reliable")
func c_duck_art(art_player_id: String, rev: int, png: PackedByteArray) -> void:
	var img := DuckDrawing.decode(png)
	if img == null:
		return
	CardArt.set_duck_image(art_player_id, rev, img)
	duck_art_updated.emit(art_player_id)


@rpc("authority", "reliable")
func c_error(msg: String) -> void:
	notice.emit(str(msg))
	print("Net error: ", msg)


@rpc("authority", "reliable")
func c_kicked(msg: String) -> void:
	room_code = ""
	last_snapshot = {}
	connection_failed.emit(msg)


@rpc("authority", "reliable")
func c_reveal_progress(target_player_id: String, t: float) -> void:
	reveal_progress.emit(target_player_id, clampf(t, 0.0, 1.0))


@rpc("authority", "reliable")
func c_reveal_cancel(target_player_id: String) -> void:
	reveal_cancel.emit(target_player_id)


@rpc("authority", "reliable")
func c_discard_hover(slot: int) -> void:
	discard_hover.emit(slot)


func _broadcast_lobby(code: String) -> void:
	if code == "" or not _logic.rooms.has(code):
		return
	var snap: Dictionary = _logic.lobby_snapshot(code)
	for p in snap.players:
		rpc_id(int(p.peer_id), "c_lobby", code, snap.players, String(p.player_id), bool(p.host), int(snap.min_players))


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
