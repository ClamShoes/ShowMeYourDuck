class_name DuckEditor
extends Control
## MS Paint-style editor for the player's duck. Draws on a DuckDrawing.SIZE image shown ZOOMx
## over the card front's emblem area. Emits finished(image) on Done; Cancel discards edits.
## Drawing ops are public (paint_line, flood_fill, undo, redo, ...) so tests can drive them.

signal finished(image: Image)

const CardArt = preload("res://scripts/ui/card_art.gd")
const DuckDrawing = preload("res://scripts/ui/duck_drawing.gd")
const CardPickerScript = preload("res://scripts/ui/card_picker.gd")
const ScreenFit = preload("res://scripts/ui/screen_fit.gd")

const ZOOM := 3
const BRUSH_SIZES := [2, 4, 8, 14]
const MAX_UNDO := 30
const FILL_TOLERANCE := 0.08
const PALETTE := [
	"000000", "ffffff", "7f7f7f", "c3c3c3",
	"880015", "ed1c24", "ff7f27", "f4a300",
	"ffd23f", "fff200", "b5e61d", "22b14c",
	"0e6b3a", "99d9ea", "00a2e8", "3f48cc",
	"a349a4", "ffaec9", "7a4a24", "e8c9a0",
]

var tool := "brush"
var brush_size := 4
var color := Color("ffd23f")

var _img: Image
var _tex: ImageTexture
var _undo: Array[Image] = []
var _redo: Array[Image] = []
var _front_id := ""
var _stroking := false
var _last := Vector2i.ZERO
var _line_start := Vector2i.ZERO
var _line_base: Image

var _canvas: TextureRect
var _underlay: TextureRect
var _preview: TextureRect
var _swatch: ColorRect
var _custom: ColorPickerButton
var _status: Label
var _tool_buttons: Dictionary = {}
var _size_buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_img = DuckDrawing.blank_image()
	_tex = ImageTexture.create_from_image(_img)
	_build()


# --- public drawing API --------------------------------------------------------------

func open(img: Image, front_id: String) -> void:
	_front_id = front_id
	_img = img.duplicate() if img != null else DuckDrawing.default_image()
	if _img.get_format() != Image.FORMAT_RGBA8:
		_img.convert(Image.FORMAT_RGBA8)
	_undo.clear()
	_redo.clear()
	_stroking = false
	_underlay.texture = ImageTexture.create_from_image(CardArt.emblem_area_image(front_id))
	_status.text = ""
	_sync_canvas()
	_refresh_preview()
	visible = true


func image() -> Image:
	return _img


## Snapshot for undo; call once before each stroke/fill/clear.
func begin_edit() -> void:
	_undo.append(_img.duplicate())
	if _undo.size() > MAX_UNDO:
		_undo.pop_front()
	_redo.clear()


func paint_line(a: Vector2i, b: Vector2i) -> void:
	var c := Color(0, 0, 0, 0) if tool == "eraser" else color
	var r := brush_size * 0.5
	var steps := maxi(1, ceili(Vector2(a).distance_to(Vector2(b)) / maxf(r * 0.5, 0.5)))
	for i in steps + 1:
		_stamp(Vector2(a).lerp(Vector2(b), float(i) / steps), r, c)
	_sync_canvas()


func flood_fill(p: Vector2i) -> void:
	var size := _img.get_size()
	if not Rect2i(Vector2i.ZERO, size).has_point(p):
		return
	var target := _img.get_pixelv(p)
	var fill := color
	if _close(target, fill, 0.001):
		return
	var seen := PackedByteArray()
	seen.resize(size.x * size.y)
	var stack: Array[Vector2i] = [p]
	while not stack.is_empty():
		var q: Vector2i = stack.pop_back()
		if q.x < 0 or q.y < 0 or q.x >= size.x or q.y >= size.y:
			continue
		var idx := q.y * size.x + q.x
		if seen[idx]:
			continue
		seen[idx] = 1
		if not _close(_img.get_pixelv(q), target, FILL_TOLERANCE):
			continue
		_img.set_pixelv(q, fill)
		stack.append(Vector2i(q.x + 1, q.y))
		stack.append(Vector2i(q.x - 1, q.y))
		stack.append(Vector2i(q.x, q.y + 1))
		stack.append(Vector2i(q.x, q.y - 1))
	_sync_canvas()


func pick_color(p: Vector2i) -> void:
	if not Rect2i(Vector2i.ZERO, _img.get_size()).has_point(p):
		return
	var c := _img.get_pixelv(p)
	if c.a > 0.0:
		set_color(Color(c.r, c.g, c.b, 1.0))


func set_color(c: Color) -> void:
	color = c
	if _swatch:
		_swatch.color = c
	if _custom:
		_custom.color = c
	if tool == "eraser" or tool == "picker":
		set_tool("brush")


func set_tool(t: String) -> void:
	tool = t
	for k in _tool_buttons:
		_tool_buttons[k].set_pressed_no_signal(k == t)


func set_brush_size(s: int) -> void:
	brush_size = s
	for k in _size_buttons:
		_size_buttons[k].set_pressed_no_signal(k == s)


func undo() -> void:
	if _undo.is_empty():
		return
	_redo.append(_img)
	_img = _undo.pop_back()
	_sync_canvas()
	_refresh_preview()


func redo() -> void:
	if _redo.is_empty():
		return
	_undo.append(_img)
	_img = _redo.pop_back()
	_sync_canvas()
	_refresh_preview()


func clear_canvas() -> void:
	begin_edit()
	_img.fill(Color(0, 0, 0, 0))
	_sync_canvas()
	_refresh_preview()


func load_default() -> void:
	begin_edit()
	_img = DuckDrawing.default_image()
	_sync_canvas()
	_refresh_preview()


# --- UI ------------------------------------------------------------------------------

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	add_child(dim)

	var panel := Panel.new()
	panel.position = Vector2(40, 24)
	panel.size = Vector2(1200, 672)
	panel.add_theme_stylebox_override("panel", CardPickerScript.overlay_style())
	ScreenFit.centred_stage(self).add_child(panel)

	var title := Label.new()
	title.text = "Draw your duck"
	title.position = Vector2(24, 12)
	title.add_theme_font_size_override("font_size", 26)
	panel.add_child(title)

	# Tools column
	var tools := VBoxContainer.new()
	tools.position = Vector2(24, 64)
	tools.custom_minimum_size = Vector2(170, 0)
	tools.add_theme_constant_override("separation", 6)
	panel.add_child(tools)
	var tool_group := ButtonGroup.new()
	for spec in [["brush", "Brush"], ["eraser", "Eraser"], ["fill", "Fill"], ["line", "Line"], ["picker", "Eyedropper"]]:
		var b := Button.new()
		b.text = spec[1]
		b.toggle_mode = true
		b.button_group = tool_group
		b.custom_minimum_size = Vector2(170, 48)
		b.pressed.connect(set_tool.bind(spec[0]))
		tools.add_child(b)
		_tool_buttons[spec[0]] = b
	tools.add_child(_caption("Brush size"))
	var sizes := HBoxContainer.new()
	tools.add_child(sizes)
	var size_group := ButtonGroup.new()
	for s in BRUSH_SIZES:
		var b := Button.new()
		b.text = str(s)
		b.toggle_mode = true
		b.button_group = size_group
		b.custom_minimum_size = Vector2(38, 48)
		b.pressed.connect(set_brush_size.bind(s))
		sizes.add_child(b)
		_size_buttons[s] = b
	tools.add_child(_caption("Edit"))
	for spec in [["Undo  (Ctrl+Z)", undo], ["Redo  (Ctrl+Y)", redo], ["Clear", clear_canvas], ["Start from default duck", load_default]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(170, 48)
		b.pressed.connect(spec[1])
		tools.add_child(b)

	# Canvas: card emblem area underneath, drawing on top, both ZOOMx with crisp pixels.
	var canvas_size := Vector2(DuckDrawing.SIZE * ZOOM)
	var frame := Panel.new()
	frame.position = Vector2(230, 64)
	frame.size = canvas_size + Vector2(8, 8)
	panel.add_child(frame)
	_underlay = _pixel_rect(canvas_size)
	_underlay.position = Vector2(4, 4)
	frame.add_child(_underlay)
	_canvas = _pixel_rect(canvas_size)
	_canvas.position = Vector2(4, 4)
	_canvas.texture = _tex
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.mouse_default_cursor_shape = Control.CURSOR_CROSS
	_canvas.gui_input.connect(_on_canvas_input)
	frame.add_child(_canvas)

	# Colours + preview column
	var right := VBoxContainer.new()
	right.position = Vector2(700, 64)
	right.custom_minimum_size = Vector2(470, 0)
	right.add_theme_constant_override("separation", 8)
	panel.add_child(right)
	right.add_child(_caption("Colour"))
	var palette := GridContainer.new()
	palette.columns = 10
	palette.add_theme_constant_override("h_separation", 4)
	palette.add_theme_constant_override("v_separation", 4)
	right.add_child(palette)
	for hex in PALETTE:
		var sw := Button.new()
		sw.custom_minimum_size = Vector2(40, 40)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(hex)
		sb.set_border_width_all(2)
		sb.border_color = Color(0, 0, 0, 0.5)
		for st in ["normal", "hover", "pressed", "focus"]:
			sw.add_theme_stylebox_override(st, sb)
		sw.pressed.connect(set_color.bind(Color(hex)))
		palette.add_child(sw)
	var cur_row := HBoxContainer.new()
	cur_row.add_theme_constant_override("separation", 8)
	right.add_child(cur_row)
	cur_row.add_child(_caption("Current"))
	_swatch = ColorRect.new()
	_swatch.custom_minimum_size = Vector2(48, 32)
	_swatch.color = color
	cur_row.add_child(_swatch)
	_custom = ColorPickerButton.new()
	_custom.text = "Custom…"
	_custom.custom_minimum_size = Vector2(120, 32)
	_custom.edit_alpha = false
	_custom.color = color
	_custom.color_changed.connect(set_color)
	cur_row.add_child(_custom)

	right.add_child(_caption("On your card"))
	_preview = _pixel_rect(Vector2(CardArt.CARD_SIZE * 2))
	_preview.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	right.add_child(_preview)

	_status = Label.new()
	_status.add_theme_color_override("font_color", Color("f4d35e"))
	_status.position = Vector2(230, 620)
	_status.size = Vector2(440, 30)
	panel.add_child(_status)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.position = Vector2(900, 608)
	cancel.size = Vector2(130, 48)
	cancel.pressed.connect(func(): visible = false)
	panel.add_child(cancel)
	var done := Button.new()
	done.text = "Done"
	done.position = Vector2(1044, 608)
	done.size = Vector2(130, 48)
	done.pressed.connect(_on_done)
	panel.add_child(done)

	set_tool(tool)
	set_brush_size(brush_size)


func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _pixel_rect(size_px: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = size_px
	t.size = size_px
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _on_done() -> void:
	if DuckDrawing.encode(_img).size() > DuckDrawing.MAX_BYTES:
		_status.text = "Too detailed to send - simplify it a little (fill big areas)."
		return
	visible = false
	finished.emit(_img.duplicate())


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed:
		return
	if event.is_command_or_control_pressed():
		if event.keycode == KEY_Z and not event.shift_pressed:
			undo()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Y or (event.keycode == KEY_Z and event.shift_pressed):
			redo()
			get_viewport().set_input_as_handled()


func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var p := _to_px(event.position)
		if event.pressed:
			_press(p)
		elif _stroking:
			_stroking = false
			_refresh_preview()
	elif event is InputEventMouseMotion and _stroking and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_drag(_to_px(event.position))


func _press(p: Vector2i) -> void:
	match tool:
		"fill":
			begin_edit()
			flood_fill(p)
			_refresh_preview()
		"picker":
			pick_color(p)
		"line":
			begin_edit()
			_stroking = true
			_line_start = p
			_line_base = _img.duplicate()
			paint_line(p, p)
		_:
			begin_edit()
			_stroking = true
			_last = p
			paint_line(p, p)


func _drag(p: Vector2i) -> void:
	if tool == "line":
		_img.copy_from(_line_base)
		paint_line(_line_start, p)
	else:
		paint_line(_last, p)
		_last = p


func _to_px(local: Vector2) -> Vector2i:
	var p := Vector2i((local / ZOOM).floor())
	return p.clamp(Vector2i.ZERO, DuckDrawing.SIZE - Vector2i.ONE)


func _stamp(center: Vector2, r: float, c: Color) -> void:
	var size := _img.get_size()
	var ri := ceili(r)
	var cx := roundi(center.x)
	var cy := roundi(center.y)
	for dy in range(-ri, ri + 1):
		var y := cy + dy
		if y < 0 or y >= size.y:
			continue
		for dx in range(-ri, ri + 1):
			var x := cx + dx
			if x < 0 or x >= size.x or dx * dx + dy * dy > r * r:
				continue
			_img.set_pixel(x, y, c)


func _close(a: Color, b: Color, tol: float) -> bool:
	if a.a < 0.01 and b.a < 0.01:
		return true
	return absf(a.r - b.r) <= tol and absf(a.g - b.g) <= tol and absf(a.b - b.b) <= tol and absf(a.a - b.a) <= tol


func _sync_canvas() -> void:
	if _tex == null:
		return
	if _tex.get_size() == Vector2(_img.get_size()):
		_tex.update(_img)
	else:
		_tex.set_image(_img)


func _refresh_preview() -> void:
	if _preview:
		_preview.texture = ImageTexture.create_from_image(CardArt.duck_face_image(_front_id, _img))
