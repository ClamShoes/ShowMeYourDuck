class_name GameTypes
extends RefCounted

enum Phase {
	LOBBY,
	PLACE_INITIAL,
	PLACE_OR_BID,
	BIDDING,
	REVEAL,
	CHOOSE_DISCARD,
	GAME_OVER,
}

const MIN_PLAYERS := 1
const MAX_PLAYERS := 6
const SAFE_PER_PLAYER := 3
const POINTS_TO_WIN := 2


static func make_card(id: String, owner_id: String, is_duck: bool, art_id: String) -> Dictionary:
	return {
		"id": id,
		"owner_id": owner_id,
		"is_duck": is_duck,
		"art_id": art_id,
	}


static func make_player(id: String, display_name: String) -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"hand": [],
		"stack": [],
		"points": 0,
		"passed": false,
		"eliminated": false,
		"placed_initial": false,
		"custom_duck_id": "",
		"adornments": [],
	}
