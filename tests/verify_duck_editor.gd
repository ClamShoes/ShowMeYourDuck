extends SceneTree

## Headless checks for DuckEditor drawing ops (no mouse needed).
## Run: godot --headless --path . --script tests/verify_duck_editor.gd
const DuckEditorScript = preload("res://scripts/ui/duck_editor.gd")
const DuckDrawing = preload("res://scripts/ui/duck_drawing.gd")

var _failed := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ed = DuckEditorScript.new()
	get_root().add_child(ed)
	ed.open(DuckDrawing.blank_image(), "bordered")
	_check("paint_line_changes_pixels", _paint_line(ed))
	_check("flood_fill_fills_enclosed_area", _flood_fill(ed))
	_check("eraser_clears_to_transparent", _eraser(ed))
	_check("undo_redo_restore_exactly", _undo_redo(ed))
	_check("export_fits_and_decodes", _export(ed))
	print("verify_duck_editor: %s" % ("PASS" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed else 0)


func _check(name: String, err: String) -> void:
	if err == "":
		print("PASS  ", name)
	else:
		_failed += 1
		print("FAIL  ", name, " - ", err)


func _paint_line(ed) -> String:
	ed.set_tool("brush")
	ed.set_brush_size(4)
	ed.set_color(Color.BLACK)
	ed.begin_edit()
	ed.paint_line(Vector2i(10, 10), Vector2i(130, 10))
	var img: Image = ed.image()
	for x in [10, 40, 70, 100, 130]:
		if not img.get_pixel(x, 10).is_equal_approx(Color.BLACK):
			return "gap in stroke at x=%s" % x
	if img.get_pixel(70, 30).a != 0.0:
		return "stroke leaked away from the line"
	return ""


func _flood_fill(ed) -> String:
	# Closed box from (20,40) to (60,80), fill inside with red.
	ed.set_color(Color.BLACK)
	ed.begin_edit()
	ed.paint_line(Vector2i(20, 40), Vector2i(60, 40))
	ed.paint_line(Vector2i(60, 40), Vector2i(60, 80))
	ed.paint_line(Vector2i(60, 80), Vector2i(20, 80))
	ed.paint_line(Vector2i(20, 80), Vector2i(20, 40))
	ed.set_color(Color.RED)
	ed.begin_edit()
	ed.flood_fill(Vector2i(40, 60))
	var img: Image = ed.image()
	if not img.get_pixel(40, 60).is_equal_approx(Color.RED):
		return "inside not filled"
	if img.get_pixel(100, 120).a != 0.0:
		return "fill escaped the box"
	return ""


func _eraser(ed) -> String:
	ed.set_tool("eraser")
	ed.set_brush_size(8)
	ed.begin_edit()
	ed.paint_line(Vector2i(40, 60), Vector2i(40, 60))
	if ed.image().get_pixel(40, 60).a != 0.0:
		return "eraser should leave transparent pixels"
	ed.set_tool("brush")
	return ""


func _undo_redo(ed) -> String:
	var before: PackedByteArray = ed.image().get_data()
	ed.set_color(Color.BLUE)
	ed.begin_edit()
	ed.paint_line(Vector2i(0, 150), Vector2i(143, 150))
	var after: PackedByteArray = ed.image().get_data()
	if after == before:
		return "stroke should change the image"
	ed.undo()
	if ed.image().get_data() != before:
		return "undo should restore the exact previous image"
	ed.redo()
	if ed.image().get_data() != after:
		return "redo should restore the stroke"
	return ""


func _export(ed) -> String:
	var png := DuckDrawing.encode(ed.image())
	if png.size() > DuckDrawing.MAX_BYTES:
		return "PNG too big: %s" % png.size()
	if DuckDrawing.decode(png) == null:
		return "exported PNG should pass decode"
	return ""
