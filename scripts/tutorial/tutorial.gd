extends Node
## Offline "How to play": a scripted 3-player game against two bots on the real GameState. Lives
## under Net, which routes the table's intents here instead of to a server; only the move the
## current step asks for is accepted.
##
## Steps (in order): {say, button} waits for the button; {say, expect, target} waits for that
## intent from you; {bot, act} plays a bot move after a short pause (keeps the last `say`).

signal step_changed(text: String, target: String, button: String)
signal finished

const GameStateScript = preload("res://scripts/rules/game_state.gd")
const GameTypes = preload("res://scripts/rules/types.gd")

const YOU := "you"
const BOT_PAUSE := {"place_card": 0.8, "open_bid": 1.0, "pass": 0.9, "flip": 2.0}

const STEPS := [
	# Round 1: someone else flips your Duck, so you destroy one of their cards.
	{say = "Welcome! Everyone has three Safe cards and one Duck. Cards are played face-down, so nobody knows which is which.", button = "Next"},
	{say = "Drag your Duck onto your mat, the box in the middle.", expect = {type = "place_card", duck = true}, target = "hand_duck"},
	{say = "Bill and Daisy play their opening cards.", bot = "bill", act = {type = "place_card"}},
	{bot = "daisy", act = {type = "place_card"}},
	{say = "Bill thinks everything on the table is Safe. He bets he can flip 3 cards without hitting a Duck.", bot = "bill", act = {type = "open_bid", amount = 3}},
	{bot = "daisy", act = {type = "pass"}},
	{say = "Bill bid 3. Pass and let him try.", expect = {type = "pass"}, target = "pass"},
	{say = "The bidder flips their own cards first, then anyone else's.", bot = "bill", act = {type = "flip", target_player_id = "bill"}},
	{bot = "bill", act = {type = "flip", target_player_id = "daisy"}},
	{bot = "bill", act = {type = "flip", target_player_id = YOU}},
	{say = "Bill flipped your Duck! His bet fails, and you destroy one of his cards. Pick one.", expect = {type = "pick_discard"}, target = "pick"},
	{say = "Gone for good. Fewer cards means fewer ways to bluff. Press Next round.", expect = {type = "next_round"}, target = "next_round"},
	# Round 2: bid only what you can flip safely.
	{say = "Round 2: winning a bet. Play a Safe onto your mat.", expect = {type = "place_card", duck = false}, target = "hand_safe"},
	{say = "Bill and Daisy play theirs, then keep adding cards.", bot = "bill", act = {type = "place_card"}},
	{bot = "daisy", act = {type = "place_card"}},
	{bot = "bill", act = {type = "place_card"}},
	{bot = "daisy", act = {type = "place_card"}},
	{say = "Your card is Safe, and you think Daisy's are too. Set the bid to 2 with - and +, then press Bid.", expect = {type = "open_bid", amount = 2}, target = "bid"},
	{say = "Bill and Daisy don't think they can beat that.", bot = "bill", act = {type = "pass"}},
	{bot = "daisy", act = {type = "pass"}},
	{say = "Now prove it. Flip your own card first: drag it sideways and let go past halfway.", expect = {type = "flip", target_player_id = YOU}, target = "mat:you"},
	{say = "Safe! One more. Flip Daisy's top card.", expect = {type = "flip", target_player_id = "daisy"}, target = "mat:daisy"},
	{say = "Two Safes: you won the bet and score a point. Two points wins the game. Press Next round.", expect = {type = "next_round"}, target = "next_round"},
	# Round 3: flipping your own Duck costs you a card of your choice.
	{say = "Round 3: bluffs can backfire. Play a Safe.", expect = {type = "place_card", duck = false}, target = "hand_safe"},
	{say = "Bill and Daisy play their opening cards.", bot = "bill", act = {type = "place_card"}},
	{bot = "daisy", act = {type = "place_card"}},
	{say = "Your turn. Put your Duck on top, hoping it scares everyone off bidding.", expect = {type = "place_card", duck = true}, target = "hand_duck"},
	{say = "Bill and Daisy add a card each.", bot = "bill", act = {type = "place_card"}},
	{bot = "daisy", act = {type = "place_card"}},
	{say = "Now bid 2: set it with - and +, then press Bid.", expect = {type = "open_bid", amount = 2}, target = "bid"},
	{say = "Nobody falls for it.", bot = "bill", act = {type = "pass"}},
	{bot = "daisy", act = {type = "pass"}},
	{say = "You must flip your own stack first, top card first, and your Duck is on top. Flip it.", expect = {type = "flip", target_player_id = YOU}, target = "mat:you"},
	{say = "You hit your own Duck! It comes back to your hand. You lose one card, but you choose which, even the Duck. Tap one.", expect = {type = "choose_discard"}, target = "hand"},
	{say = "That's the game! Bet right twice to win. Lose all your cards and you're out. Now go play with friends.", button = "Finish"},
]

var gs: GameStateScript
var step := -1
var _text := ""
## Bumped when a bot pause starts, so only the latest pause plays its move.
var _bot_seq := 0


func start(display_name: String, cosmetics: Dictionary) -> void:
	gs = GameStateScript.new()
	gs.start_match([
		{id = YOU, name = display_name, cosmetics = cosmetics},
		{id = "bill", name = "Bill", cosmetics = {card_back_id = "ember"}},
		{id = "daisy", name = "Daisy", cosmetics = {card_back_id = "frost"}},
	], "bill")
	_publish()
	_go(0)


func current() -> Dictionary:
	return STEPS[step] if step >= 0 and step < STEPS.size() else {}


func target() -> String:
	return String(current().get("target", ""))


func allows(intent: Dictionary) -> bool:
	var want: Dictionary = current().get("expect", {})
	if want.is_empty() or String(intent.get("type", "")) != String(want.type):
		return false
	if want.has("duck"):
		var card: Dictionary = gs.cards.get(String(intent.get("card_id", "")), {})
		if card.is_empty() or bool(card.is_duck) != bool(want.duck):
			return false
	for key in ["amount", "target_player_id"]:
		if want.has(key) and intent.get(key) != want[key]:
			return false
	return true


## The table's intent. Wrong moves are refused with a nudge back to the current instruction.
func submit(intent: Dictionary) -> void:
	if not allows(intent):
		get_parent().notice.emit(_hint())
		return
	var result: Dictionary = gs.apply_intent(YOU, intent)
	if not result.ok:
		get_parent().notice.emit(String(result.error))
		return
	_publish()
	_go(step + 1)


## Next / Finish on the instruction panel.
func press_button() -> void:
	if not current().has("button"):
		return
	if step == STEPS.size() - 1:
		finished.emit()
		return
	_go(step + 1)


func _hint() -> String:
	if current().has("bot"):
		return "Wait for the others to play."
	if current().has("button"):
		return "Read the instructions, then press %s." % current().button
	if current().expect.has("amount"):
		return "Bid exactly %d." % current().expect.amount
	return "Not that one - follow the instructions."


## Re-sends the current instruction (the overlay calls this when the table opens).
func announce() -> void:
	step_changed.emit(_text, target(), String(current().get("button", "")))


func _go(i: int) -> void:
	step = i
	var s := current()
	if s.has("say"):
		_text = String(s.say)
	announce()
	if s.has("bot"):
		_bot_seq += 1
		get_tree().create_timer(BOT_PAUSE.get(String(s.act.type), 1.0)).timeout.connect(_on_bot_timer.bind(_bot_seq))


func _on_bot_timer(seq: int) -> void:
	if seq == _bot_seq and current().has("bot"):
		_play_bot(String(current().bot), current().act)


func _play_bot(pid: String, act: Dictionary) -> void:
	var intent := act.duplicate()
	if intent.type == "place_card":
		var hand: Array = gs.players[pid].hand
		var slot := -1
		for i in hand.size():
			if not bool(gs.cards[hand[i]].is_duck):
				slot = i
				break
		assert(slot >= 0, "tutorial bot %s has no Safe to play" % pid)
		intent["card_id"] = String(hand[slot])
		# Same order as a real opponent: lift the card, then drop it on the mat before the snapshot.
		get_parent().hand_fx.emit(pid, {"t": "drag", "slot": slot})
		get_parent().hand_fx.emit(pid, {"t": "place", "slot": -1})
	var result: Dictionary = gs.apply_intent(pid, intent)
	assert(result.ok, "tutorial bot %s: %s" % [pid, result.error])
	_publish()
	_go(step + 1)


func _publish() -> void:
	# Real duck stamps are earned in real games; never offer one here (it would edit your saved duck).
	for p in gs.players.values():
		p.upgrade_offer = []
	var snap := gs.private_snapshot(YOU)
	snap["you_are_host"] = true
	snap["host_id"] = YOU
	var net := get_parent()
	net.last_snapshot = snap
	net.match_updated.emit(snap)
