extends SceneTree

## Headless checks for the Balatro-style feel layer (CardView._update_visual + CardJuice).
## Run: godot --headless --path . --script tests/verify_card_feel.gd
const CardScene = preload("res://scenes/card.tscn")
const CardJuice = preload("res://scripts/ui/card_juice.gd")
const DT := 1.0 / 60.0

var _failed := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var root := Node.new()
	get_root().add_child(root)
	_check("juice_settles", _juice_settles(root))
	_check("hidden_sprite_never_tilted", _hidden_sprite_never_tilted(root))
	_check("idle_float_bounded", _idle_float_bounded(root))
	_check("drag_spring_converges", _drag_spring_converges())
	_check("flip_lift_up_while_scrubbing", _flip_lift_up_while_scrubbing(root))
	_check("flip_lift_returns_after_abort", await _flip_lift_returns_after_abort(root))
	_check("flip_lift_returns_after_settle", await _flip_lift_returns_after_settle(root))
	print("verify_card_feel: %s" % ("PASS" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed else 0)


func _check(name: String, err: String) -> void:
	if err == "":
		print("PASS  ", name)
	else:
		_failed += 1
		print("FAIL  ", name, " — ", err)


func _still_card(root: Node, token: bool) -> CardView:
	var c: CardView = CardScene.instantiate()
	root.add_child(c)
	c.set_process(false)
	c.idle_bob_px = 0.0
	c.idle_rock_deg = 0.0
	if token:
		c.setup_stack_token(true, "")
	else:
		c.setup("x", false, true, true, true, "")
	return c


func _step(c: CardView, seconds: float) -> void:
	for _i in int(seconds / DT):
		c._update_visual(DT)


func _juice_settles(root: Node) -> String:
	var c := _still_card(root, false)
	c.juice(0.2, 8.0)
	_step(c, 0.1)
	if absf(c._card_back.scale.x - 1.0) < 0.01 and absf(c._card_back.rotation) < 0.001:
		return "pop should visibly move scale/rotation"
	_step(c, 0.5)
	if absf(c._card_back.scale.x - 1.0) > 0.001 or absf(c._card_back.rotation) > 0.001:
		return "pop should settle to scale 1 / rotation 0 within 0.6s, got %s / %s" % [c._card_back.scale.x, c._card_back.rotation]
	return ""


func _tilt_of(spr: Sprite2D) -> Vector2:
	var m := spr.material as ShaderMaterial
	return Vector2(float(m.get_shader_parameter("tilt_x")), float(m.get_shader_parameter("tilt_y")))


func _hidden_sprite_never_tilted(root: Node) -> String:
	# Face-down token hovered: tilt may go on the back, never on the (hidden) face.
	var c := _still_card(root, true)
	c._set_hover(true)
	c.tilt_max_deg = 20.0
	for _i in 60:
		c._update_visual(DT)
		if _tilt_of(c._card_front) != Vector2.ZERO:
			return "face sprite tilted while face-down"
	# Mid-scrub (still before the edge) the face must stay untilted too.
	c.scrub_flip(0.9)
	for _i in 30:
		c._update_visual(DT)
		if _tilt_of(c._card_front) != Vector2.ZERO:
			return "face sprite tilted mid-scrub"
	# Face-up hand card hovered: the back is now the hidden one.
	var h := _still_card(root, false)
	h._set_hover(true)
	h.tilt_max_deg = 20.0
	for _i in 60:
		h._update_visual(DT)
		if _tilt_of(h._card_back) != Vector2.ZERO:
			return "back sprite tilted while face-up"
	return ""


func _idle_float_bounded(root: Node) -> String:
	var c: CardView = CardScene.instantiate()
	root.add_child(c)
	c.set_process(false)
	c.setup("x", false, true, false, false, "")
	var max_dy := 0.0
	var max_rot := 0.0
	for _i in 600:
		c._update_visual(DT)
		max_dy = maxf(max_dy, absf(c._card_back.position.y - CardView.REST_POS.y))
		max_rot = maxf(max_rot, absf(rad_to_deg(c._card_back.rotation)))
	if max_dy > c.idle_bob_px + 0.01 or max_rot > c.idle_rock_deg + 0.01:
		return "idle exceeded bounds: %s px / %s deg" % [max_dy, max_rot]
	if max_dy < 0.1:
		return "idle float should move the card"
	return ""


func _drag_spring_converges() -> String:
	var c: CardView = CardScene.instantiate()
	var x := Vector2.ZERO
	var v := Vector2.ZERO
	var target := Vector2(300, -120)
	var peak := 0.0
	for _i in 90:
		var r := CardJuice.spring_v2(x, v, target, c.drag_spring_k, c.drag_spring_damping, DT)
		x = r[0]
		v = r[1]
		peak = maxf(peak, x.x)
	c.free()
	if x.distance_to(target) > 1.0:
		return "drag spring should reach the mouse within 1.5s, off by %s" % x.distance_to(target)
	if peak > target.x * 1.25:
		return "drag spring overshoot too large: %s" % peak
	return ""


func _flip_lift_up_while_scrubbing(root: Node) -> String:
	var c := _still_card(root, true)
	c.scrub_flip(1.0)
	c._update_visual(DT)
	if c._card_back.position.y >= CardView.REST_POS.y - 1.0:
		return "card should rise while turning edge-on"
	return ""


func _flip_lift_returns_after_abort(root: Node) -> String:
	var c := _still_card(root, true)
	c.scrub_flip(1.0)
	c.abort_flip()
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 1500:
		await process_frame
	c._update_visual(DT)
	if absf(c._card_back.position.y - CardView.REST_POS.y) > 0.01:
		return "lift should return to rest after abort, y=%s" % c._card_back.position.y
	return ""


func _flip_lift_returns_after_settle(root: Node) -> String:
	var c := _still_card(root, true)
	c.scrub_flip(1.0)
	var settled := [false]
	c.reveal_settled.connect(func(_c): settled[0] = true)
	c.set_revealed_face(false)
	c.set_process(true)
	var start := Time.get_ticks_msec()
	while not settled[0] and Time.get_ticks_msec() - start < 3000:
		await process_frame
	if not settled[0]:
		return "reveal did not settle"
	c.set_process(false)
	_step(c, 0.6)
	if absf(c._card_back.position.y - CardView.REST_POS.y) > 0.01:
		return "lift should be 0 after settle, y=%s" % c._card_back.position.y
	if absf(c._card_front.scale.x - 1.0) > 0.001:
		return "settle pop should finish at scale 1, got %s" % c._card_front.scale.x
	return ""
