extends SceneTree

## Headless smoke check for Card_Flip scrub → play rest settle.
const CardScene = preload("res://scenes/card.tscn")
const CardArt = preload("res://scripts/ui/card_art.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var root := Node.new()
	root.name = "SettleRoot"
	get_root().add_child(root)

	var duck = CardScene.instantiate()
	root.add_child(duck)
	duck.setup_stack_token(true)
	# Full scrub window → clip at SCRUB_END_SEC; finish plays from there.
	duck.scrub_flip(1.0)

	var duck_settled := [false]
	duck.reveal_settled.connect(func(_c): duck_settled[0] = true)
	duck.set_revealed_face(true)
	if duck.get("_settling_face_up") != true:
		push_error("expected settling after set_revealed_face(duck)")
		quit(1)
		return
	if duck.is_duck != true:
		push_error("expected is_duck after reveal")
		quit(1)
		return
	if duck._card_front.texture != CardArt.face_texture("", true) or duck._card_back.texture != CardArt.back_texture(""):
		push_error("duck reveal should use the owner's back + duck face")
		quit(1)
		return

	# Mid-settle should still be playing Card_Flip, not instantly at rest.
	await process_frame
	await process_frame
	if duck_settled[0]:
		push_error("settle finished too fast — flip completion likely skipped")
		quit(1)
		return

	var elapsed := 0.0
	while not duck_settled[0] and elapsed < 3.0:
		await process_frame
		elapsed += 1.0 / 60.0
	if not duck_settled[0]:
		push_error("reveal_settled did not fire for duck")
		quit(1)
		return
	if not duck.face_up or not duck.card_flipped:
		push_error("expected face-up rest after duck settle")
		quit(1)
		return
	if duck._card_front.z_index < duck._card_back.z_index:
		push_error("after settle past edge, cardBack2 must paint above cardBack")
		quit(1)
		return

	# Scrub seeks Card_Flip into the first 0.46s and stays paused.
	var probe = CardScene.instantiate()
	root.add_child(probe)
	probe.setup_stack_token(true)
	probe.scrub_flip(0.0)
	if abs(float(probe.get("_anim_time")) - 0.0) > 0.001:
		push_error("t=0 expected anim_time 0")
		quit(1)
		return
	probe.scrub_flip(0.5)
	var expected_mid := 0.5 * float(probe.SCRUB_END_SEC)
	if abs(float(probe.get("_anim_time")) - expected_mid) > 0.01:
		push_error("t=0.5 expected anim_time ~%s, got %s" % [expected_mid, probe.get("_anim_time")])
		quit(1)
		return
	if probe._anim == null:
		push_error("missing Anim player")
		quit(1)
		return
	# Godot still reports is_playing while paused; speed 0 means scrub hold.
	if abs(probe._anim.get_playing_speed()) > 0.001:
		push_error("scrub should leave Card_Flip paused")
		quit(1)
		return
	probe.scrub_flip(1.0)
	if abs(float(probe.get("_anim_time")) - float(probe.SCRUB_END_SEC)) > 0.01:
		push_error("t=1 expected anim_time == SCRUB_END_SEC")
		quit(1)
		return

	# Unrevealed scrub: owner's back + blank frame (no Duck/Safe on the face sprite yet).
	var scrub = CardScene.instantiate()
	root.add_child(scrub)
	scrub.setup_stack_token(true)
	scrub.scrub_flip(0.4)
	if scrub._card_front.texture != CardArt.blank_face_texture("") or scrub._card_back.texture != CardArt.back_texture(""):
		push_error("scrub should keep the owner's back + blank face")
		quit(1)
		return
	# Mouse maps linearly over the scrub window only (160px → 1.0).
	if abs(scrub.scrub_t_from_mouse_dx(80.0) - 0.5) > 0.01:
		push_error("80px should map to ~0.5 scrub progress")
		quit(1)
		return
	if scrub.scrub_t_from_mouse_dx(160.0) < 0.999:
		push_error("160px should complete scrub window")
		quit(1)
		return
	# Opponent mat across the table: the card turns toward screen-left, so the drag must too.
	var across := Control.new()
	across.rotation = PI * 0.9
	root.add_child(across)
	var opp = CardScene.instantiate()
	across.add_child(opp)
	opp.setup_stack_token(true)
	if opp.scrub_t_from_mouse_dx(-80.0) < 0.49 or opp.scrub_t_from_mouse_dx(80.0) > 0.001:
		push_error("on an upside-down mat, dragging left should flip (got %s left, %s right)" % [
			opp.scrub_t_from_mouse_dx(-80.0), opp.scrub_t_from_mouse_dx(80.0)])
		quit(1)
		return

	# Safe settle
	var safe = CardScene.instantiate()
	root.add_child(safe)
	safe.setup_stack_token(true)
	safe.scrub_flip(1.0)
	var safe_settled := [false]
	safe.reveal_settled.connect(func(_c): safe_settled[0] = true)
	safe.set_revealed_face(false)
	if safe.is_duck:
		push_error("expected non-duck after safe reveal")
		quit(1)
		return
	if safe._card_front.texture != CardArt.face_texture("", false) or safe._card_back.texture != CardArt.back_texture(""):
		push_error("safe reveal should use the owner's back + safe face")
		quit(1)
		return
	elapsed = 0.0
	while not safe_settled[0] and elapsed < 3.0:
		await process_frame
		elapsed += 1.0 / 60.0
	if not safe_settled[0]:
		push_error("reveal_settled did not fire for safe")
		quit(1)
		return

	# Abort path
	var card2 = CardScene.instantiate()
	root.add_child(card2)
	card2.setup_stack_token(true)
	card2.scrub_flip(0.3)
	card2.abort_flip()
	if card2.get("_settling_face_up") == true:
		push_error("abort should not set settling")
		quit(1)
		return

	print("PASS  verify_flip_settle")
	quit(0)
