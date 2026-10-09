extends SceneTree

## Headless checks for the duck upgrade overlay (StampPicker), driven through its public API.
## Run: godot --headless --path . --script tests/verify_stamp_picker.gd
const StampPickerScript = preload("res://scripts/ui/stamp_picker.gd")
const DuckDrawing = preload("res://scripts/ui/duck_drawing.gd")

var _failed := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var picker = StampPickerScript.new()
	get_root().add_child(picker)
	_check("starts_closed", _starts_closed(picker))
	_check("offer_then_place", _offer_then_place(picker))
	_check("later_and_reopen_keeps_state", _later_keeps_state(picker))
	_check("transform_clamps", _transform_clamps(picker))
	_check("flip_toggles_and_changes_bake", _flip(picker))
	_check("done_emits_baked_image", _done_bakes(picker))
	print("verify_stamp_picker: %s" % ("PASS" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed else 0)


func _check(name: String, err: String) -> void:
	if err == "":
		print("PASS  ", name)
	else:
		_failed += 1
		print("FAIL  ", name, " - ", err)


func _starts_closed(picker) -> String:
	if picker.is_active() or picker.is_minimised():
		return "picker should start closed"
	return ""


func _offer_then_place(picker) -> String:
	picker.open(["top_hat", "katana", "eyes_star"], DuckDrawing.default_image())
	if not picker.is_active() or picker.is_minimised() or picker.stamp_id != "":
		return "open should show the offer step"
	picker.choose("monocle")
	if picker.stamp_id != "":
		return "a stamp outside the offer must be ignored"
	picker.choose("top_hat")
	if picker.stamp_id != "top_hat":
		return "choosing a tile should move to placing"
	return ""


func _later_keeps_state(picker) -> String:
	picker.move_to(Vector2(70, 30))
	picker.rotate_step(1)
	picker.minimise()
	if not picker.is_minimised():
		return "Later should minimise"
	picker.open(["top_hat", "katana", "eyes_star"], DuckDrawing.default_image())
	if picker.is_minimised() or picker.stamp_id != "top_hat" or picker.stamp_pos != Vector2(70, 30):
		return "reopening with the same offer should resume (stamp %s at %s)" % [picker.stamp_id, picker.stamp_pos]
	if not is_equal_approx(picker.stamp_rot, PI / 12.0):
		return "rotation should be kept, got %s" % picker.stamp_rot
	return ""


func _transform_clamps(picker) -> String:
	for i in 40:
		picker.scale_by(1.1)
	if not is_equal_approx(picker.stamp_scale, picker.MAX_SCALE):
		return "scale should clamp at %s, got %s" % [picker.MAX_SCALE, picker.stamp_scale]
	for i in 40:
		picker.scale_by(1.0 / 1.1)
	if not is_equal_approx(picker.stamp_scale, picker.MIN_SCALE):
		return "scale should clamp at %s" % picker.MIN_SCALE
	picker.scale_by(3.0)
	picker.move_to(Vector2(-50, 999))
	if picker.stamp_pos != Vector2(0, DuckDrawing.SIZE.y):
		return "position should stay on the duck, got %s" % picker.stamp_pos
	picker.move_to(Vector2(72, 40))
	return ""


func _flip(picker) -> String:
	var unflipped: Image = picker.baked()
	picker.flip()
	if not picker.stamp_flip:
		return "flip() should mirror the stamp"
	if picker.baked().get_data() == unflipped.get_data():
		return "a flipped stamp should bake differently"
	picker.flip()
	if picker.stamp_flip:
		return "flip() again should undo it"
	picker.flip()
	var pos: Vector2 = picker.stamp_pos
	var rot: float = picker.stamp_rot
	var sc: float = picker.stamp_scale
	picker.choose("katana")
	if picker.stamp_flip:
		return "choosing a stamp should reset the flip"
	picker.choose("top_hat")
	picker.move_to(pos)
	picker.stamp_rot = rot
	picker.scale_by(sc / picker.stamp_scale)
	picker.flip()
	return ""


func _done_bakes(picker) -> String:
	var got := []
	picker.finished.connect(func(id, img): got.append([id, img]))
	picker.done()
	if got.size() != 1 or String(got[0][0]) != "top_hat":
		return "Done should emit once with the stamp id"
	var img: Image = got[0][1]
	var base := DuckDrawing.default_image()
	if img.get_size() != base.get_size():
		return "baked duck must keep its size"
	if img.get_data() == base.get_data():
		return "baked duck should differ from the base"
	if DuckDrawing.decode(DuckDrawing.encode(img)) == null:
		return "baked duck must be sendable"
	if picker.is_active():
		return "Done should close the picker"
	return ""
