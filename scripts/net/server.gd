class_name DuckServer
extends RefCounted

const GameStateScript = preload("res://scripts/rules/game_state.gd")
const GameTypes = preload("res://scripts/rules/types.gd")
const CardCatalog = preload("res://scripts/ui/card_catalog.gd")
const DuckDrawing = preload("res://scripts/ui/duck_drawing.gd")
const PlayerCosmetics = preload("res://scripts/ui/player_cosmetics.gd")
const DuckStamps = preload("res://scripts/ui/duck_stamps.gd")

const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var rooms: Dictionary = {}
var peer_room: Dictionary = {}
var rng := RandomNumberGenerator.new()
## Players needed to start (server launch flag `--min-players`).
var min_players := GameTypes.MIN_PLAYERS


func _init() -> void:
	rng.randomize()


func create_room(peer_id: int, display_name: String, cosmetics: Variant = {}) -> Dictionary:
	leave(peer_id)
	var code := _fresh_code()
	rooms[code] = {
		"code": code,
		"host_peer": peer_id,
		"peers": {peer_id: _peer_info(peer_id, display_name, cosmetics)},
		"state": null,
	}
	peer_room[peer_id] = code
	return {"ok": true, "code": code}


func join_room(peer_id: int, code: String, display_name: String, cosmetics: Variant = {}) -> Dictionary:
	code = code.strip_edges().to_upper()
	if not rooms.has(code):
		return {"ok": false, "error": "No room with that code"}
	var room: Dictionary = rooms[code]
	if room.state != null:
		return {"ok": false, "error": "That game already started"}
	if room.peers.size() >= GameTypes.MAX_PLAYERS:
		return {"ok": false, "error": "Room is full"}
	leave(peer_id)
	room.peers[peer_id] = _peer_info(peer_id, display_name, cosmetics)
	peer_room[peer_id] = code
	return {"ok": true, "code": code}


## Lobby only for now — mid-match changes would need snapshot-driven re-skins.
func set_cosmetics(peer_id: int, cosmetics: Variant) -> Dictionary:
	var room := _room_of(peer_id)
	if room.is_empty():
		return {"ok": false, "error": "Not in a room"}
	if room.state != null:
		return {"ok": false, "error": "Can't change cards during a match"}
	room.peers[peer_id].cosmetics = CardCatalog.sanitize(cosmetics)
	room.peers[peer_id].duck_progress = _progress_of(cosmetics)
	return {"ok": true, "code": String(room.code)}


## Lobby only. Validated PNG is stored and duck_rev bumped; caller broadcasts it once.
func set_duck_drawing(peer_id: int, png: PackedByteArray) -> Dictionary:
	var room := _room_of(peer_id)
	if room.is_empty():
		return {"ok": false, "error": "Not in a room"}
	if room.state != null:
		return {"ok": false, "error": "Can't change your duck during a match"}
	if DuckDrawing.decode(png) == null:
		return {"ok": false, "error": "That duck drawing couldn't be read"}
	var info: Dictionary = room.peers[peer_id]
	info.duck_png = png
	info.duck_rev = int(info.duck_rev) + 1
	return {"ok": true, "code": String(room.code), "player_id": String(info.player_id), "rev": info.duck_rev}


## [{player_id, rev, png}] for every peer in the room with a drawing (sync for joiners).
func duck_arts(code: String) -> Array:
	var out: Array = []
	if not rooms.has(code):
		return out
	for pid in rooms[code].peers.keys():
		var info: Dictionary = rooms[code].peers[pid]
		if not PackedByteArray(info.duck_png).is_empty():
			out.append({"player_id": String(info.player_id), "rev": int(info.duck_rev), "png": info.duck_png})
	return out


func start_match(peer_id: int) -> Dictionary:
	var room := _room_of(peer_id)
	if room.is_empty():
		return {"ok": false, "error": "Not in a room"}
	if peer_id != room.host_peer:
		return {"ok": false, "error": "Only the host can start"}
	if room.peers.size() < min_players:
		return {"ok": false, "error": "Need at least %s players" % min_players}
	var infos: Array = []
	for pid in room.peers.keys():
		var info: Dictionary = room.peers[pid]
		var looks: Dictionary = info.cosmetics.merged({
			"duck_rev": info.duck_rev,
			"duck_progress": info.duck_progress,
		})
		infos.append({"id": info.player_id, "name": info.name, "cosmetics": looks})
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
	# Solo / testing: any seated player may advance. Multiplayer: host only.
	if String(intent.get("type", "")) == "next_round":
		if room.peers.size() > 1 and peer_id != room.host_peer:
			return {"ok": false, "error": "Only the host can start the next round"}
	var player_id: String = String(room.peers[peer_id].player_id)
	return room.state.apply_intent(player_id, intent)


## Mid-match duck upgrade: the client baked `stamp_id` into its duck; keep the art and progress
## on the peer so the next match starts from them.
func apply_duck_upgrade(peer_id: int, stamp_id: String, png: PackedByteArray) -> Dictionary:
	var room := _room_of(peer_id)
	if room.is_empty() or room.state == null:
		return {"ok": false, "error": "No match"}
	if DuckDrawing.decode(png) == null:
		return {"ok": false, "error": "That duck drawing couldn't be read"}
	var info: Dictionary = room.peers[peer_id]
	var player_id := String(info.player_id)
	var result: Dictionary = room.state.apply_duck_upgrade(player_id, stamp_id)
	if not result.ok:
		return result
	var p: Dictionary = room.state.players[player_id]
	info.duck_png = png
	info.duck_rev = int(p.duck_rev)
	info.duck_progress = p.duck_progress.duplicate(true)
	return {"ok": true, "code": String(room.code), "player_id": player_id, "rev": info.duck_rev}


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
			"card_back_id": info.cosmetics.card_back_id,
			"card_front_id": info.cosmetics.card_front_id,
			"duck_rev": info.duck_rev,
		})
	return {"code": code, "players": players, "in_match": room.state != null, "min_players": min_players}


func snapshots_for_room(code: String) -> Dictionary:
	# peer_id -> private snapshot
	var out := {}
	if not rooms.has(code):
		return out
	var room: Dictionary = rooms[code]
	if room.state == null:
		return out
	var host_id := String(room.peers[room.host_peer].player_id) if room.peers.has(room.host_peer) else ""
	for pid in room.peers.keys():
		var player_id: String = String(room.peers[pid].player_id)
		var snap: Dictionary = room.state.private_snapshot(player_id)
		snap["you_are_host"] = int(pid) == int(room.host_peer)
		snap["host_id"] = host_id
		out[pid] = snap
	return out


func room_code_for(peer_id: int) -> String:
	return String(peer_room.get(peer_id, ""))


## Presentation relay gate — does not mutate GameState.
## Returns { ok, code, peer_ids } on success (peer_ids = room peers except sender).
func validate_reveal_relay(peer_id: int, target_player_id: String) -> Dictionary:
	var room := _room_of(peer_id)
	if room.is_empty() or room.state == null:
		return {"ok": false, "error": "No match"}
	var state = room.state
	if int(state.phase) != GameTypes.Phase.REVEAL:
		return {"ok": false, "error": "Not revealing"}
	var sender_id: String = String(room.peers[peer_id].player_id)
	if sender_id != String(state.challenger_id):
		return {"ok": false, "error": "Only the challenger can scrub a reveal"}
	if not state.players.has(target_player_id):
		return {"ok": false, "error": "Unknown target"}
	if state.players[target_player_id].stack.is_empty():
		return {"ok": false, "error": "That stack is empty"}
	var others: Array = []
	for pid in room.peers.keys():
		if int(pid) != peer_id:
			others.append(int(pid))
	return {"ok": true, "code": String(room.code), "peer_ids": others}


## Presentation relay gate for the Duck owner's hover over the centre pick row (-1 = none).
func validate_discard_hover_relay(peer_id: int, slot: int) -> Dictionary:
	var room := _room_of(peer_id)
	if room.is_empty() or room.state == null:
		return {"ok": false, "error": "No match"}
	var state = room.state
	if int(state.phase) != GameTypes.Phase.CHOOSE_DISCARD or state.discard_order.is_empty():
		return {"ok": false, "error": "Not picking a discard"}
	if String(room.peers[peer_id].player_id) != String(state.discard_chooser_id):
		return {"ok": false, "error": "Only the Duck's owner picks"}
	if slot < -1 or slot >= state.discard_order.size():
		return {"ok": false, "error": "No such card"}
	var others: Array = []
	for pid in room.peers.keys():
		if int(pid) != peer_id:
			others.append(int(pid))
	return {"ok": true, "code": String(room.code), "peer_ids": others}


func _room_of(peer_id: int) -> Dictionary:
	var code := room_code_for(peer_id)
	if code == "" or not rooms.has(code):
		return {}
	return rooms[code]


func _peer_info(peer_id: int, display_name: String, cosmetics: Variant) -> Dictionary:
	return {
		"name": PlayerCosmetics.clean_name(display_name),
		"player_id": _pid(peer_id),
		"cosmetics": CardCatalog.sanitize(cosmetics),
		"duck_png": PackedByteArray(),
		"duck_rev": 0,
		"duck_progress": _progress_of(cosmetics),
	}


func _progress_of(cosmetics: Variant) -> Dictionary:
	var raw: Variant = cosmetics.get("duck_progress", {}) if cosmetics is Dictionary else {}
	return DuckStamps.sanitize_progress(raw)


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
