class_name GameProtocol
extends RefCounted


static func place_card(card_id: String) -> Dictionary:
	return {"type": "place_card", "card_id": card_id}


static func open_bid(amount: int) -> Dictionary:
	return {"type": "open_bid", "amount": amount}


static func raise_bid(amount: int) -> Dictionary:
	return {"type": "raise", "amount": amount}


static func pass_bid() -> Dictionary:
	return {"type": "pass"}


static func flip(target_player_id: String) -> Dictionary:
	return {"type": "flip", "target_player_id": target_player_id}


static func choose_discard(card_id: String) -> Dictionary:
	return {"type": "choose_discard", "card_id": card_id}


static func pick_discard(slot: int) -> Dictionary:
	return {"type": "pick_discard", "slot": slot}


static func next_round() -> Dictionary:
	return {"type": "next_round"}


## Presentation-only (not GameState intents).
static func reveal_progress(target_player_id: String, t: float) -> Dictionary:
	return {"target_player_id": target_player_id, "t": clampf(t, 0.0, 1.0)}


static func reveal_cancel(target_player_id: String) -> Dictionary:
	return {"target_player_id": target_player_id}
