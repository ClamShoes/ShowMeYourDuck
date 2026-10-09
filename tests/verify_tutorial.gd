extends SceneTree
## Plays the whole tutorial through Net the way the table would, checking each lesson's outcome.
##   Godot --headless --path . -s res://tests/verify_tutorial.gd

var _net
var _notices: Array = []
var _offer_seen := false


func _initialize() -> void:
	Engine.time_scale = 20.0
	_net = root.get_node("Net")
	_net.notice.connect(func(msg): _notices.append(msg))
	_net.match_updated.connect(func(snap): _offer_seen = _offer_seen or snap.get("you", {}).has("upgrade_offer"))
	_run.call_deferred()


func _run() -> void:
	_net.start_tutorial("Tester", {}, null)
	var t = _net.tutorial
	var gs = t.gs
	var bill_cards := _owned(gs, "bill")
	var wrong_checked := false
	while true:
		var s: Dictionary = t.current()
		if s.has("bot"):
			var at: int = t.step
			for _i in 200:
				await process_frame
				if t.step != at:
					break
			if t.step == at:
				return _fail("bot step %d never played" % at)
			continue
		if s.has("button"):
			if t.step == t.STEPS.size() - 1:
				break
			t.press_button()
			continue
		var want: Dictionary = s.expect
		if want.type == "place_card" and want.duck and not wrong_checked:
			wrong_checked = true
			var at: int = t.step
			_net.submit_intent({"type": "place_card", "card_id": _card(gs, false)})
			if t.step != at or _notices.is_empty():
				return _fail("placing a Safe when the Duck is asked for should be refused with a hint")
			if _net.allows({"type": "pass"}):
				return _fail("allows() should refuse a move the step doesn't ask for")
		var before: int = t.step
		_net.submit_intent(_intent_for(gs, want))
		if t.step == before:
			return _fail("step %d refused its own move %s: %s" % [before, want, _notices.back() if _notices.size() else ""])
		match before:
			10:
				if _owned(gs, "bill") != bill_cards - 1:
					return _fail("round 1: Bill should lose a card (%d -> %d)" % [bill_cards, _owned(gs, "bill")])
			21:
				if int(gs.players.you.points) != 1:
					return _fail("round 2: the right bet should score a point")
			33:
				if _owned(gs, "you") != 3:
					return _fail("round 3: you should be down to 3 cards, have %d" % _owned(gs, "you"))
	if _offer_seen:
		return _fail("a duck stamp offer reached the snapshot")
	var done := [false]
	t.finished.connect(func(): done[0] = true)
	t.press_button()
	if not done[0]:
		return _fail("Finish should end the tutorial")
	_net.leave_room()
	if _net.is_tutorial() or _net.last_snapshot.size() != 0:
		return _fail("leaving should end the session")
	print("PASS  verify_tutorial")
	quit(0)


func _intent_for(gs, want: Dictionary) -> Dictionary:
	match String(want.type):
		"place_card":
			return {"type": "place_card", "card_id": _card(gs, bool(want.duck))}
		"choose_discard":
			return {"type": "choose_discard", "card_id": String(gs.players.you.hand[0])}
		"pick_discard":
			return {"type": "pick_discard", "slot": 0}
	return want.duplicate()


func _card(gs, duck: bool) -> String:
	for cid in gs.players.you.hand:
		if bool(gs.cards[cid].is_duck) == duck:
			return String(cid)
	return ""


## Hand, stack and this round's face-up cards: everything not yet destroyed.
func _owned(gs, pid: String) -> int:
	var n: int = gs.players[pid].hand.size() + gs.players[pid].stack.size()
	for e in gs.flip_history:
		if String(e.owner_id) == pid:
			n += 1
	return n


func _fail(msg: String) -> void:
	print("FAIL  verify_tutorial: ", msg)
	quit(1)
