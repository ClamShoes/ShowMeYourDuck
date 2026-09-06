class_name DuckServer
extends RefCounted

const GameStateScript = preload("res://scripts/rules/game_state.gd")
const GameTypes = preload("res://scripts/rules/types.gd")

const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var rooms: Dictionary = {}
var peer_room: Dictionary = {}
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


func create_room(peer_id: int, display_name: String) -> Dictionary:
	leave(peer_id)
	var code := _fresh_code()
	rooms[code] = {
		"code": code,
		"host_peer": peer_id,
		"peers": {peer_id: {"name": display_name, "player_id": _pid(peer_id)}},
		"state": null,
	}
	peer_room[peer_id] = code
	return {"ok": true, "code": code}


func join_room(peer_id: int, code: String, display_name: String) -> Dictionary:
	code = code.strip_edges().to_upper()
	if not rooms.has(code):
		return {"ok": false, "error": "No room with that code"}
	var room: Dictionary = rooms[code]
	if room.state != null:
		return {"ok": false, "error": "That game already started"}
	if room.peers.size() >= GameTypes.MAX_PLAYERS:
		return {"ok": false, "error": "Room is full"}
	leave(peer_id)
	room.peers[peer_id] = {"name": display_name, "player_id": _pid(peer_id)}
	peer_room[peer_id] = code
	return {"ok": true, "code": code}


func start_match(peer_id: int) -> Dictionary:
	var room := _room_of(peer_id)
	if room.is_empty():
		return {"ok": false, "error": "Not in a room"}
	if peer_id != room.host_peer:
		return {"ok": false, "error": "Only the host can start"}
	if room.peers.size() < GameTypes.MIN_PLAYERS:
		return {"ok": false, "error": "Need at least %s players" % GameTypes.MIN_PLAYERS}
	var infos: Array = []
	for pid in room.peers.keys():
		var info: Dictionary = room.peers[pid]
		infos.append({"id": info.player_id, "name": info.name})
	var gs = GameStateScript.new()
	var first: String = String(room.peers[room.host_peer].player_id)
	var result: Dictionary = gs.start_match(infos, first)
	if not result.ok:
		return result
	room.state = gs
	return {"ok": true}


func apply_intent(peer_id: int, intent: Dictionary) -> Dictionary:
	var room := _room_of(peer_id)
	if room.is_empty() or room.state == null:
		return {"ok": false, "error": "No match"}
	var player_id: String = String(room.peers[peer_id].player_id)
	return room.state.apply_intent(player_id, intent)


func leave(peer_id: int) -> String:
	if not peer_room.has(peer_id):
		return ""
	var code: String = String(peer_room[peer_id])
	peer_room.erase(peer_id)
	if not rooms.has(code):
		return code
	var room: Dictionary = rooms[code]
	room.peers.erase(peer_id)
	if peer_id == room.host_peer or room.peers.is_empty():
		rooms.erase(code)
		return code
	if room.state != null:
		room.state = null
	return code


func lobby_snapshot(code: String) -> Dictionary:
	if not rooms.has(code):
		return {}
	var room: Dictionary = rooms[code]
	var players: Array = []
	for pid in room.peers.keys():
		var info: Dictionary = room.peers[pid]
		players.append({
			"peer_id": pid,
			"name": info.name,
			"player_id": info.player_id,
			"host": pid == room.host_peer,
		})
	return {"code": code, "players": players, "in_match": room.state != null}


func snapshots_for_room(code: String) -> Dictionary:
	# peer_id -> private snapshot
	var out := {}
	if not rooms.has(code):
		return out
	var room: Dictionary = rooms[code]
	if room.state == null:
		return out
	for pid in room.peers.keys():
		var player_id: String = String(room.peers[pid].player_id)
		out[pid] = room.state.private_snapshot(player_id)
	return out


func room_code_for(peer_id: int) -> String:
	return String(peer_room.get(peer_id, ""))


func _room_of(peer_id: int) -> Dictionary:
	var code := room_code_for(peer_id)
	if code == "" or not rooms.has(code):
		return {}
	return rooms[code]


func _pid(peer_id: int) -> String:
	return "p%s" % peer_id


func _fresh_code() -> String:
	for _i in 32:
		var code := ""
		for _j in 4:
			code += ALPHABET[rng.randi_range(0, ALPHABET.length() - 1)]
		if not rooms.has(code):
			return code
	return "DUCK"
