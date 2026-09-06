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
