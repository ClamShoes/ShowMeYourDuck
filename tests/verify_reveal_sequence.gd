extends SceneTree

## Headless check (real frames) for the reveal sequence: detach → drift → present → settle → park.
const PlayerMatScript = preload("res://scripts/ui/player_mat.gd")
const CardArt = preload("res://scripts/ui/card_art.gd")
const DuckDrawing = preload("res://scripts/ui/duck_drawing.gd")

var _fail := ""


func _init() -> void:
	call_deferred("_run")


func _info(stack: int) -> Dictionary:
	return {name = "P0", points = 0, hand_count = 0, stack_count = stack, passed = false, eliminated = false}


func _check(cond: bool, msg: String) -> bool:
	if not cond and _fail == "":
		_fail = msg
	return cond


## Commit a flip of the mat's top card and run frames until the sequence finishes.
## Returns {card, sec, max_scale, max_present, drift_ok, duck_presented}.
func _reveal(mat, is_duck: bool, cid: String, idx: int, mid_refresh_stack: int = -1) -> Dictionary:
	var top = mat.top_card()
	var out := {card = top, sec = 0.0, max_scale = 0.0, max_present = 0.0, drift_ok = false, duck_presented = false}
	if not _check(top != null, "no top card to flip"):
		return out
	var start_pos: Vector2 = top.position
	var done := [false]
	var on_done := func(_m): done[0] = true
	var on_duck := func(_m, _c): out.duck_presented = true
	mat.reveal_sequence_finished.connect(on_done)
	mat.duck_presented.connect(on_duck)
	top.scrub_flip(1.0)
	var count_before: int = mat.stack_size()
	mat.apply_revealed_to_top(is_duck, cid, idx)
	_check(top.get_parent() == mat, "%s: card must leave the stack box on commit" % cid)
	_check(mat.stack_size() == count_before - 1, "%s: stack count should drop on commit" % cid)
	_check(mat.top_card() != top, "%s: next token must be the new top" % cid)
	_check(mat.reveals_in_flight() == 1, "%s: one sequence should be in flight" % cid)
	if mid_refresh_stack >= 0:
		# Snapshot lands mid-sequence: must not touch the detached card.
		mat.refresh(_info(mid_refresh_stack), true)
	var t0 := Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - t0 < 5000:
		await process_frame
		if not is_instance_valid(top):
			break
		out.max_scale = maxf(out.max_scale, top.scale.x)
		out.max_present = maxf(out.max_present, float(top.present_height))
		var moved: Vector2 = top.position - start_pos
		if moved.dot(mat.reveal_dir) > PlayerMatScript.PRESENT_DRIFT * 0.5:
			out.drift_ok = true
	out.sec = (Time.get_ticks_msec() - t0) / 1000.0
	mat.reveal_sequence_finished.disconnect(on_done)
	mat.duck_presented.disconnect(on_duck)
	_check(done[0], "%s: reveal_sequence_finished never fired" % cid)
	return out


func _run() -> void:
	var root := Control.new()
	root.size = Vector2(1280, 720)
	get_root().add_child(root)

	var mat = PlayerMatScript.new()
	root.add_child(mat)
	mat.position = Vector2(535, 330)
	mat.setup("p0", Color.RED)
	mat.reveal_dir = Vector2.UP
	mat.refresh(_info(3), true)

	# Safe: fast present, lands in slot 0.
	var safe := await _reveal(mat, false, "c_safe", 0, 2)
	var card = safe.card
	if _fail == "":
		_check(card.position.distance_to(mat.reveal_slot_local(0)) < 0.5, "safe should end at reveal slot 0, got %s want %s" % [card.position, mat.reveal_slot_local(0)])
		_check(absf(card.scale.x - PlayerMatScript.REVEAL_SCALE) < 0.01, "safe should end at REVEAL_SCALE, got %s" % card.scale)
		_check(card.has_meta("parked_reveal"), "safe should be parked")
		_check(safe.sec < 1.6, "safe sequence too slow: %ss" % safe.sec)
		_check(safe.drift_ok, "safe should drift toward the table centre during the flip")
		_check(safe.max_scale > 1.0, "safe should present above rest scale (max %s)" % safe.max_scale)
		_check(safe.max_present > 0.9, "safe should lift toward the camera")
		_check(not safe.duck_presented, "safe must not emit duck_presented")
		_check(mat.reveals_in_flight() == 0, "no sequences should remain in flight")
		_check(mat.stack_size() == 2, "stack should hold 2 tokens after one flip")

	# Duck: longer hold + duck_presented + shake, lands in slot 1.
	var duck := {}
	if _fail == "":
		duck = await _reveal(mat, true, "c_duck", 1)
		var dcard = duck.card
		if _fail == "":
			_check(duck.duck_presented, "duck should emit duck_presented")
			_check(duck.sec > safe.sec + 0.4, "duck should hold longer (duck %ss vs safe %ss)" % [duck.sec, safe.sec])
			_check(duck.max_scale > 1.4, "duck should present bigger (max %s)" % duck.max_scale)
			_check(dcard.position.distance_to(mat.reveal_slot_local(1)) < 0.5, "duck should end at reveal slot 1")
			_check(absf(dcard.scale.x - PlayerMatScript.REVEAL_SCALE) < 0.01, "duck should end at REVEAL_SCALE")

	# Late sync must not duplicate cards that already landed.
	if _fail == "":
		var kids_before: int = mat.get_child_count()
		mat.sync_parked_reveals([
			{card_id = "c_safe", owner_id = "p0", is_duck = false},
			{card_id = "c_duck", owner_id = "p0", is_duck = true},
		])
		_check(mat.get_child_count() == kids_before, "sync after landing should not spawn duplicates")

	# Next round mid-sequence: taking the card ends the sequence (no stuck result hold).
	if _fail == "":
		var finished := [0]
		mat.reveal_sequence_finished.connect(func(_m): finished[0] += 1)
		mat.top_card().scrub_flip(1.0)
		mat.apply_revealed_to_top(false, "c_mid", 2)
		await process_frame
		var taken: Array = mat.take_parked_reveals()
		_check(taken.size() == 3, "take should return both parked cards and the in-flight one (got %d)" % taken.size())
		_check(mat.reveals_in_flight() == 0, "take mid-sequence must end the sequence")
		_check(finished[0] == 1, "take mid-sequence must emit reveal_sequence_finished once")
		for n in taken:
			n.queue_free()

	# Late join: parked reveals spawn straight into their slots.
	if _fail == "":
		var late = PlayerMatScript.new()
		root.add_child(late)
		late.setup("p1", Color.BLUE)
		late.reveal_dir = Vector2.DOWN
		late.refresh(_info(1), false)
		late.sync_parked_reveals([
			{card_id = "a", owner_id = "p1", is_duck = false},
			{card_id = "b", owner_id = "p1", is_duck = false},
		])
		for c in late.get_children():
			if String(c.get_meta("reveal_card_id", "")) == "b":
				_check(c.position.distance_to(late.reveal_slot_local(1)) < 0.5, "late-sync card b should sit in reveal slot 1")
				_check(absf(c.scale.x - PlayerMatScript.REVEAL_SCALE) < 0.01, "late-sync card should be REVEAL_SCALE")

	# Mini-duck confetti texture: default and custom drawing both fit the confetti size.
	if _fail == "":
		var tex := CardArt.mini_duck_texture("nobody")
		_check(tex != null and tex.get_width() <= 36 and tex.get_height() <= 44, "default mini duck should fit 36x44")
		var img := DuckDrawing.blank_image()
		img.fill(Color.RED)
		CardArt.set_players([{id = "drawer", duck_rev = 3}])
		CardArt.set_duck_image("drawer", 3, img)
		var mine := CardArt.mini_duck_texture("drawer")
		_check(mine != tex and mine.get_size() == Vector2(36, 44), "custom mini duck should be its own 36x44 texture")
		var px := mine.get_image().get_pixel(18, 22)
		_check(px.r > 0.9 and px.g < 0.1, "custom mini duck should use the drawing's pixels")

	if _fail != "":
		push_error(_fail)
		print("FAIL  verify_reveal_sequence — " + _fail)
		quit(1)
		return
	print("PASS  verify_reveal_sequence (safe %.2fs, duck %.2fs)" % [safe.sec, duck.sec])
	quit(0)
