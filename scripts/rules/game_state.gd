class_name GameState
extends RefCounted

const GameTypes = preload("res://scripts/rules/types.gd")
const DuckStamps = preload("res://scripts/ui/duck_stamps.gd")

var rng: RandomNumberGenerator
var phase: int = GameTypes.Phase.LOBBY
var players: Dictionary = {}
var cards: Dictionary = {}
var player_order: Array = []
var current_player_id: String = ""
var hand_starter_id: String = ""
var current_bid: int = 0
var current_bidder_id: String = ""
var challenger_id: String = ""
var flips_remaining: int = 0
var winner_id: String = ""
var flip_history: Array = []
var last_revealed: Dictionary = {}
var last_events: Array = []
var next_hand_starter_id: String = ""
## Bumped per permanent discard so clients can animate each one exactly once.
var discard_seq: int = 0
## {player_id, seq, card_id, is_duck, slot, style}; card identity only ever goes to the loser's snapshot.
var last_discard: Dictionary = {}
## Who picks the card the challenger loses: the challenger (own Duck) or the Duck's owner.
var discard_chooser_id: String = ""
## Duck-owner pick only: the challenger's hand, shuffled. Never sent to anyone but the challenger.
var discard_order: Array = []


func _init() -> void:
	rng = RandomNumberGenerator.new()
	rng.randomize()


func start_match(player_infos: Array, first_player_id: String = "") -> Dictionary:
	if player_infos.size() < GameTypes.MIN_PLAYERS or player_infos.size() > GameTypes.MAX_PLAYERS:
		return _fail("Need %s–%s players" % [GameTypes.MIN_PLAYERS, GameTypes.MAX_PLAYERS])
	players.clear()
	cards.clear()
	player_order.clear()
	winner_id = ""
	last_revealed = {}
	discard_seq = 0
	last_discard = {}
	for info in player_infos:
		var pid := String(info.id)
		var display := String(info.get("name", pid))
		var cosmetics: Dictionary = info.get("cosmetics", {})
		players[pid] = GameTypes.make_player(pid, display, cosmetics)
		player_order.append(pid)
		_deal_player(pid)
	if first_player_id == "" or not players.has(first_player_id):
		first_player_id = String(player_order[0])
	_start_hand(first_player_id)
	return _ok()


func apply_intent(player_id: String, intent: Dictionary) -> Dictionary:
	var t := String(intent.get("type", ""))
	match t:
		"place_card":
			return place_card(player_id, String(intent.get("card_id", "")))
		"open_bid":
			return open_bid(player_id, int(intent.get("amount", 0)))
		"raise":
			return raise_bid(player_id, int(intent.get("amount", 0)))
		"pass":
			return pass_bid(player_id)
		"flip":
			return flip_stack(player_id, String(intent.get("target_player_id", "")))
		"choose_discard":
			return choose_discard(player_id, String(intent.get("card_id", "")))
		"pick_discard":
			return pick_discard(player_id, int(intent.get("slot", -1)))
		"next_round":
			return next_round(player_id)
		_:
			return _fail("Unknown intent")


func place_card(player_id: String, card_id: String) -> Dictionary:
	var p := _require_active(player_id)
	if p.is_empty():
		return _fail("Unknown or eliminated player")
	if phase != GameTypes.Phase.PLACE_INITIAL and phase != GameTypes.Phase.PLACE_OR_BID:
		return _fail("Cannot place a card now")
	if phase == GameTypes.Phase.PLACE_INITIAL:
		if p.placed_initial:
			return _fail("You already played your opening card")
	elif player_id != current_player_id:
		return _fail("Not your turn")
	if not _has_card_in_hand(player_id, card_id):
		return _fail("That card is not in your hand")
	if phase == GameTypes.Phase.PLACE_OR_BID and p.hand.size() == 0:
		return _fail("No cards left — you must bid")
	_move_hand_to_stack(player_id, card_id)
	if phase == GameTypes.Phase.PLACE_INITIAL:
		p.placed_initial = true
		if _all_initial_placed():
			phase = GameTypes.Phase.PLACE_OR_BID
			current_player_id = hand_starter_id
			_skip_if_eliminated_current()
	else:
		current_player_id = _next_active(player_id)
		_nudge_empty_hands()
	return _ok()


func open_bid(player_id: String, amount: int) -> Dictionary:
	if phase != GameTypes.Phase.PLACE_OR_BID:
		return _fail("Cannot open bidding now")
	if player_id != current_player_id:
		return _fail("Not your turn")
	if not _is_active(player_id):
		return _fail("Unknown or eliminated player")
	var in_play := _cards_in_play()
	if amount < 1 or amount > in_play:
		return _fail("Bid must be between 1 and %s" % in_play)
	_begin_bidding(player_id, amount)
	return _ok()


func raise_bid(player_id: String, amount: int) -> Dictionary:
	if phase != GameTypes.Phase.BIDDING:
		return _fail("Not bidding")
	if player_id != current_player_id:
		return _fail("Not your turn")
	if not _is_active(player_id):
		return _fail("Unknown or eliminated player")
	if players[player_id].passed:
		return _fail("You already passed")
	var in_play := _cards_in_play()
	if amount <= current_bid or amount > in_play:
		return _fail("Raise must be %s–%s" % [current_bid + 1, in_play])
	current_bid = amount
	current_bidder_id = player_id
	_advance_bidding_turn(player_id)
	return _ok()


func pass_bid(player_id: String) -> Dictionary:
	if phase != GameTypes.Phase.BIDDING:
		return _fail("Not bidding")
	if player_id != current_player_id:
		return _fail("Not your turn")
	if not _is_active(player_id):
		return _fail("Unknown or eliminated player")
	players[player_id].passed = true
	if player_id == current_bidder_id:
		return _fail("Highest bidder cannot pass")
	_advance_bidding_turn(player_id)
	return _ok()


func flip_stack(player_id: String, target_player_id: String) -> Dictionary:
	if phase != GameTypes.Phase.REVEAL:
		return _fail("Not revealing")
	if player_id != challenger_id:
		return _fail("Only the challenger can flip")
	if not players.has(target_player_id):
		return _fail("No such player")
	var own_stack: Array = players[challenger_id].stack
	if own_stack.size() > 0 and target_player_id != challenger_id:
		return _fail("Flip your own stack first")
	var stack: Array = players[target_player_id].stack
	if stack.is_empty():
		return _fail("That stack is empty")
	var card_id: String = String(stack.pop_back())
	var card: Dictionary = cards[card_id]
	last_revealed = {
		"card_id": card_id,
		"owner_id": card.owner_id,
		"target_player_id": target_player_id,
		"is_duck": card.is_duck,
	}
	flip_history.append({
		"card_id": card_id,
		"owner_id": card.owner_id,
		"target_player_id": target_player_id,
		"is_duck": card.is_duck,
	})
	if card.is_duck:
		return _fail_challenge(String(card.owner_id) == challenger_id)
	flips_remaining -= 1
	if flips_remaining <= 0:
		return _succeed_challenge()
	return _ok()


func choose_discard(player_id: String, card_id: String) -> Dictionary:
	if phase != GameTypes.Phase.CHOOSE_DISCARD:
		return _fail("Not choosing a discard")
	if not discard_order.is_empty():
		return _fail("The Duck's owner picks this discard")
	if player_id != challenger_id:
		return _fail("Only the challenger discards")
	if not _has_card_in_hand(player_id, card_id):
		return _fail("That card is not in your hand")
	_remove_card_forever(player_id, card_id)
	discard_chooser_id = ""
	return _after_failed_discard()


## Duck owner picks one of the challenger's face-down cards by its (shuffled) slot.
func pick_discard(player_id: String, slot: int) -> Dictionary:
	if phase != GameTypes.Phase.CHOOSE_DISCARD or discard_order.is_empty():
		return _fail("Not picking a discard")
	if player_id != discard_chooser_id:
		return _fail("Only the Duck's owner picks")
	if slot < 0 or slot >= discard_order.size():
		return _fail("No such card")
	_remove_card_forever(challenger_id, String(discard_order[slot]), slot)
	var chooser: Dictionary = players[player_id]
	if chooser.upgrade_offer.is_empty():
		chooser.upgrade_offer = DuckStamps.offers(rng, chooser.duck_progress.earned)
	discard_chooser_id = ""
	discard_order.clear()
	return _after_failed_discard()


## Server-only (arrives with the baked duck PNG, so not an intent).
func apply_duck_upgrade(player_id: String, stamp_id: String) -> Dictionary:
	if not players.has(player_id):
		return _fail("No such player")
	var p: Dictionary = players[player_id]
	if stamp_id not in p.upgrade_offer:
		return _fail("That stamp was not offered")
	DuckStamps.apply_stamp(p.duck_progress, stamp_id)
	p.upgrade_offer = []
	p.duck_rev += 1
	return _ok()


func next_round(_player_id: String) -> Dictionary:
	if phase == GameTypes.Phase.GAME_OVER:
		return _fail("Game is over — start a new match instead")
	if phase != GameTypes.Phase.ROUND_OVER:
		return _fail("Round is not over yet")
	var starter := next_hand_starter_id
	if starter == "" or not players.has(starter) or not _is_active(starter):
		starter = _next_active(challenger_id if challenger_id != "" else String(player_order[0]))
	# Revealed cards stay on the table until Next round — return them now.
	_return_revealed_to_hands()
	_start_hand(starter)
	return _ok()


func public_snapshot() -> Dictionary:
	var plist: Array = []
	for pid in player_order:
		var p: Dictionary = players[pid]
		plist.append({
			"id": pid,
			"name": p.name,
			"hand_count": p.hand.size(),
			"stack_count": p.stack.size(),
			"points": p.points,
			"passed": p.passed,
			"eliminated": p.eliminated,
			"placed_initial": p.placed_initial,
			"card_back_id": p.card_back_id,
			"card_front_id": p.card_front_id,
			"duck_rev": p.duck_rev,
			"custom_duck_id": p.custom_duck_id,
			"adornments": p.adornments.duplicate(),
		})
	return {
		"phase": phase,
		"phase_name": GameTypes.Phase.keys()[phase] if phase >= 0 and phase < GameTypes.Phase.size() else "UNKNOWN",
		"current_player_id": current_player_id,
		"hand_starter_id": hand_starter_id,
		"current_bid": current_bid,
		"current_bidder_id": current_bidder_id,
		"challenger_id": challenger_id,
		"flips_remaining": flips_remaining,
		"winner_id": winner_id,
		"cards_in_play": _cards_in_play(),
		"flip_history": flip_history.duplicate(true),
		"last_revealed": last_revealed.duplicate(true),
		"next_hand_starter_id": next_hand_starter_id,
		"last_discard": _public_discard(),
		"discard_chooser_id": discard_chooser_id,
		"discard_slots": discard_order.size(),
		"players": plist,
	}


func _public_discard() -> Dictionary:
	if last_discard.is_empty():
		return {}
	return {
		"player_id": last_discard.player_id,
		"seq": last_discard.seq,
		"slot": last_discard.slot,
		"style": last_discard.style,
	}


func private_snapshot(player_id: String) -> Dictionary:
	var snap := public_snapshot()
	var hand_cards: Array = []
	if players.has(player_id):
		for cid in players[player_id].hand:
			hand_cards.append(cards[cid].duplicate())
	snap["you"] = {
		"id": player_id,
		"hand": hand_cards,
	}
	if players.has(player_id) and not players[player_id].upgrade_offer.is_empty():
		snap.you["upgrade_offer"] = players[player_id].upgrade_offer.duplicate()
	if not last_discard.is_empty() and String(last_discard.player_id) == player_id:
		snap.last_discard = last_discard.duplicate()
	if not discard_order.is_empty() and player_id == challenger_id:
		var faces: Array = []
		for cid in discard_order:
			faces.append(cards[cid].duplicate())
		snap["discard_slot_faces"] = faces
	return snap


func _deal_player(player_id: String) -> void:
	var p: Dictionary = players[player_id]
	for i in GameTypes.SAFE_PER_PLAYER:
		var cid := "%s_safe_%s" % [player_id, i]
		cards[cid] = GameTypes.make_card(cid, player_id, false, "safe")
		p.hand.append(cid)
	var duck_id := "%s_duck" % player_id
	cards[duck_id] = GameTypes.make_card(duck_id, player_id, true, "duck")
	p.hand.append(duck_id)
	_shuffle_array(p.hand)


func _start_hand(starter_id: String) -> void:
	hand_starter_id = starter_id
	current_bid = 0
	current_bidder_id = ""
	challenger_id = ""
	flips_remaining = 0
	flip_history.clear()
	next_hand_starter_id = ""
	discard_chooser_id = ""
	discard_order.clear()
	for pid in player_order:
		var p: Dictionary = players[pid]
		p.passed = false
		p.placed_initial = false
		p.stack.clear()
	if not _is_active(starter_id):
		starter_id = _next_active(starter_id)
		hand_starter_id = starter_id
	current_player_id = starter_id
	phase = GameTypes.Phase.PLACE_INITIAL


func _begin_bidding(player_id: String, amount: int) -> void:
	phase = GameTypes.Phase.BIDDING
	current_bid = amount
	current_bidder_id = player_id
	for pid in player_order:
		players[pid].passed = false
	_advance_bidding_turn(player_id)


func _advance_bidding_turn(from_id: String) -> void:
	var still_in: Array = []
	for pid in player_order:
		if _is_active(pid) and not players[pid].passed:
			still_in.append(pid)
	if still_in.size() == 1:
		_start_reveal(String(still_in[0]))
		return
	var nxt := _next_bidding(from_id)
	current_player_id = nxt


func _start_reveal(who: String) -> void:
	phase = GameTypes.Phase.REVEAL
	challenger_id = who
	current_player_id = who
	flips_remaining = current_bid


func _fail_challenge(own_duck: bool) -> Dictionary:
	_return_unflipped_stacks_to_hands()
	if own_duck:
		# Revealed cards stay parked; discard must come from remaining hand.
		if players[challenger_id].hand.is_empty():
			players[challenger_id].eliminated = true
			return _after_failed_discard()
		phase = GameTypes.Phase.CHOOSE_DISCARD
		discard_chooser_id = challenger_id
		current_player_id = challenger_id
		return _ok()
	var hand: Array = players[challenger_id].hand
	if hand.is_empty():
		players[challenger_id].eliminated = true
		return _after_failed_discard()
	phase = GameTypes.Phase.CHOOSE_DISCARD
	discard_chooser_id = String(last_revealed.owner_id)
	current_player_id = discard_chooser_id
	discard_order = hand.duplicate()
	_shuffle_array(discard_order)
	return _ok()


func _succeed_challenge() -> Dictionary:
	_return_unflipped_stacks_to_hands()
	players[challenger_id].points += 1
	if players[challenger_id].points >= GameTypes.POINTS_TO_WIN:
		return _end_game(challenger_id)
	return _enter_round_over(challenger_id)


func _after_failed_discard() -> Dictionary:
	if players[challenger_id].hand.is_empty():
		players[challenger_id].eliminated = true
	var alive := _active_ids()
	# Last player standing only applies when the table started with multiple seats.
	# Solo (player_order.size() == 1) continues after a failed Duck so you can keep testing.
	if alive.size() == 1 and player_order.size() > 1:
		return _end_game(String(alive[0]))
	if alive.is_empty():
		return _end_game(challenger_id)
	var starter := challenger_id
	if not _is_active(starter):
		starter = _next_active(starter)
	return _enter_round_over(starter)


func _enter_round_over(starter_id: String) -> Dictionary:
	phase = GameTypes.Phase.ROUND_OVER
	next_hand_starter_id = starter_id
	current_player_id = ""
	return _ok()


## Keeps flip_history / last_revealed so every client can animate the deciding flip.
func _end_game(who: String) -> Dictionary:
	phase = GameTypes.Phase.GAME_OVER
	winner_id = who
	current_player_id = ""
	next_hand_starter_id = ""
	return _ok()


func _return_unflipped_stacks_to_hands() -> void:
	for pid in player_order:
		var p: Dictionary = players[pid]
		for cid in p.stack:
			p.hand.append(cid)
		p.stack.clear()


func _return_revealed_to_hands() -> void:
	for entry in flip_history:
		var oid: String = String(entry.owner_id)
		if players.has(oid):
			players[oid].hand.append(entry.card_id)
	flip_history.clear()


func _collect_played_to_hands() -> void:
	_return_unflipped_stacks_to_hands()
	_return_revealed_to_hands()


func _remove_card_forever(player_id: String, card_id: String, slot: int = -1) -> void:
	var hand: Array = players[player_id].hand
	hand.erase(card_id)
	discard_seq += 1
	# The Duck that caused the loss decides how the card is destroyed.
	var styler := String(last_revealed.get("owner_id", player_id))
	if not players.has(styler):
		styler = player_id
	last_discard = {
		"player_id": player_id,
		"seq": discard_seq,
		"card_id": card_id,
		"is_duck": bool(cards[card_id].is_duck) if cards.has(card_id) else false,
		"slot": slot,
		"style": DuckStamps.pick_style(players[styler].duck_progress, rng),
	}
	cards.erase(card_id)


func _move_hand_to_stack(player_id: String, card_id: String) -> void:
	var p: Dictionary = players[player_id]
	p.hand.erase(card_id)
	p.stack.append(card_id)


func _has_card_in_hand(player_id: String, card_id: String) -> bool:
	return players.has(player_id) and card_id in players[player_id].hand


func _all_initial_placed() -> bool:
	for pid in _active_ids():
		if not players[pid].placed_initial:
			return false
	return true


func _cards_in_play() -> int:
	var n := 0
	for pid in player_order:
		n += players[pid].stack.size()
	return n


func _nudge_empty_hands() -> void:
	# If the current player has no cards, they cannot place — UI must bid.
	# Rules: they MUST open bidding; we do not auto-bid.
	pass


func _require_active(player_id: String) -> Dictionary:
	if not _is_active(player_id):
		return {}
	return players[player_id]


func _is_active(player_id: String) -> bool:
	return players.has(player_id) and not players[player_id].eliminated


func _active_ids() -> Array:
	var out: Array = []
	for pid in player_order:
		if _is_active(pid):
			out.append(pid)
	return out


func _next_active(from_id: String) -> String:
	if player_order.is_empty():
		return ""
	var start := player_order.find(from_id)
	if start == -1:
		start = 0
	for i in player_order.size():
		var idx: int = (start + i + 1) % player_order.size()
		var pid: String = String(player_order[idx])
		if _is_active(pid):
			return pid
	return from_id


func _next_bidding(from_id: String) -> String:
	var start := player_order.find(from_id)
	if start == -1:
		start = 0
	for i in player_order.size():
		var idx: int = (start + i + 1) % player_order.size()
		var pid: String = String(player_order[idx])
		if _is_active(pid) and not players[pid].passed:
			return pid
	return from_id


func _skip_if_eliminated_current() -> void:
	if not _is_active(current_player_id):
		current_player_id = _next_active(current_player_id)


func _shuffle_array(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _ok() -> Dictionary:
	return {"ok": true, "error": ""}


func _fail(msg: String) -> Dictionary:
	return {"ok": false, "error": msg}
