extends SceneTree

## Headless check (real frames): every discard style presents at the target, then finishes,
## frees itself, and breaks the card. One extra run destroys in place (no target).
const DiscardFxScript = preload("res://scripts/ui/discard_fx.gd")
const CardArt = preload("res://scripts/ui/card_art.gd")

const FROM := Vector2(300, 600)
const TARGET := Vector2(640, 360)
const TARGET_SCALE := 1.7


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var root := Node2D.new()
	get_root().add_child(root)
	var tex := CardArt.back_texture("")
	var runs := []
	for style in DiscardFxScript.STYLES:
		runs.append({"style": style, "present": true})
	runs.append({"style": "explode", "present": false})
	for run in runs:
		var fail := await _check(root, tex, String(run.style), bool(run.present))
		if fail != "":
			print("FAIL  verify_discard_fx %s%s — %s" % [run.style, "" if run.present else " (in place)", fail])
			quit(1)
			return
	print("PASS  verify_discard_fx")
	quit(0)


func _check(root: Node, tex: Texture2D, style: String, present: bool) -> String:
	var fx
	if present:
		fx = DiscardFxScript.play(root, tex, FROM, 0.75, style, 42, TARGET, TARGET_SCALE)
	else:
		fx = DiscardFxScript.play(root, tex, FROM, 0.75, style, 42)
	var done := [false]
	fx.finished.connect(func(_f): done[0] = true)
	var max_pieces := 0
	var max_progress := 0.0
	var saw_present: bool = fx.is_presenting()
	var landed := {}
	var t0 := Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - t0 < 3500:
		await process_frame
		if not is_instance_valid(fx):
			continue
		if fx.is_presenting():
			if fx.piece_count() > 0:
				return "no pieces while presenting"
		elif landed.is_empty():
			landed = {"pos": fx.global_position, "scale": fx.scale.x}
		max_pieces = maxi(max_pieces, fx.piece_count())
		max_progress = maxf(max_progress, fx.progress)
	await process_frame
	if present != saw_present:
		return "presenting should be %s at start" % present
	if not done[0]:
		return "never emitted finished"
	if is_instance_valid(fx):
		return "should free itself after finishing"
	var want_pos := TARGET if present else FROM
	var want_scale := TARGET_SCALE if present else 0.75
	if landed.is_empty() or landed.pos.distance_to(want_pos) > 1.0 or absf(landed.scale - want_scale) > 0.02:
		return "destroy should start at %s x%.2f (got %s)" % [want_pos, want_scale, landed]
	if style == "burn" and max_progress < 0.99:
		return "burn progress should reach 1 (max %s)" % max_progress
	if style != "burn" and max_pieces < 2:
		return "should break the card into pieces (max %d)" % max_pieces
	print("ok    %s%s (%d pieces, %.2fs)" % [style, " presented" if present else " in place", max_pieces, (Time.get_ticks_msec() - t0) / 1000.0])
	return ""
