extends Control
## Duck upgrade overlay: pick 1 of the offered stamps, then place it on your duck (drag to move,
## wheel / -,+ to resize, Q/E or buttons to rotate, F to flip). Never blocks play: Later (or the table, when
## it's your turn) minimises it to a small "Finish your stamp" button.
## Emits finished(stamp_id, baked_image) on Done; the table saves and sends it.

signal finished(stamp_id: String, image: Image)

const CardArt = preload("res://scripts/ui/card_art.gd")
const DuckDrawing = preload("res://scripts/ui/duck_drawing.gd")
const DuckStamps = preload("res://scripts/ui/duck_stamps.gd")
const CardPickerScript = preload("res://scripts/ui/card_picker.gd")
const ScreenFit = preload("res://scripts/ui/screen_fit.gd")

const ZOOM := 3
const MIN_SCALE := 0.4
const MAX_SCALE := 2.5
const SCALE_STEP := 1.1
const ROT_STEP := PI / 12.0
const TILE := Vector2(240, 240)

var offer: Array = []
var stamp_id := ""
## Stamp centre in duck pixels.
var stamp_pos := Vector2(DuckDrawing.SIZE) * 0.5
var stamp_rot := 0.0
var stamp_scale := 1.0
## Mirrored left-to-right.
var stamp_flip := false

var _duck: Image
var _stamp_img: Image
var _dim: ColorRect
var _panel: Panel
var _offer_box: Control
var _tiles: HBoxContainer
var _place_box: Control
var _duck_rect: TextureRect
var _stamp_rect: TextureRect
var _minimised_btn: Button
var _grab := Vector2.ZERO
var _dragging := false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	close()


## Show the offer. Re-opening with the same offer resumes where the player left off.
func open(p_offer: Array, duck: Image) -> void:
	if p_offer != offer or _duck == null:
		offer = p_offer.duplicate()
		_duck = duck.duplicate() if duck != null else DuckDrawing.default_image()
		if _duck.get_format() != Image.FORMAT_RGBA8:
			_duck.convert(Image.FORMAT_RGBA8)
		_duck_rect.texture = ImageTexture.create_from_image(_duck)
		stamp_id = ""
		_fill_tiles()
	_show_step()
	restore()


func close() -> void:
	offer = []
	stamp_id = ""
	_duck = null
	_dragging = false
	_dim.visible = false
	_panel.visible = false
	_minimised_btn.visible = false


func is_active() -> bool:
	return not offer.is_empty()


func is_minimised() -> bool:
	return is_active() and _minimised_btn.visible


func minimise() -> void:
	if not is_active():
		return
	_dragging = false
	_dim.visible = false
	_panel.visible = false
	_minimised_btn.visible = true


func restore() -> void:
	if not is_active():
		return
	_dim.visible = true
	_panel.visible = true
	_minimised_btn.visible = false


func choose(id: String) -> void:
	if id not in offer:
		return
	stamp_id = id
	_stamp_img = CardArt._load_image(DuckStamps.art_path(id))
	_stamp_rect.texture = ImageTexture.create_from_image(_stamp_img)
	stamp_pos = Vector2(DuckDrawing.SIZE) * 0.5
	stamp_rot = 0.0
	stamp_scale = 1.0
	stamp_flip = false
	_show_step()
	_sync_stamp()


func flip() -> void:
	stamp_flip = not stamp_flip
	_sync_stamp()


func move_to(duck_px: Vector2) -> void:
	stamp_pos = duck_px.clamp(Vector2.ZERO, Vector2(DuckDrawing.SIZE))
	_sync_stamp()


func rotate_step(dir: int) -> void:
	stamp_rot = wrapf(stamp_rot + ROT_STEP * dir, -PI, PI)
	_sync_stamp()


func scale_by(f: float) -> void:
	stamp_scale = clampf(stamp_scale * f, MIN_SCALE, MAX_SCALE)
	_sync_stamp()


func baked() -> Image:
	return DuckStamps.bake(_duck, _stamp_img, stamp_pos, stamp_rot, stamp_scale, stamp_flip)


func done() -> void:
	if stamp_id == "":
		return
	var img := baked()
	var id := stamp_id
	close()
	finished.emit(id, img)


# --- UI ------------------------------------------------------------------------------

func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.set_anchors_preset(PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_panel = Panel.new()
	_panel.position = Vector2(140, 40)
	_panel.size = Vector2(1000, 640)
	_panel.add_theme_stylebox_override("panel", CardPickerScript.overlay_style())
	ScreenFit.centred_stage(self).add_child(_panel)

	_offer_box = Control.new()
	_offer_box.set_anchors_preset(PRESET_FULL_RECT)
	_panel.add_child(_offer_box)
	_offer_box.add_child(_title("A gift for your duck! Pick one."))
	_tiles = HBoxContainer.new()
	_tiles.position = Vector2(0, 170)
	_tiles.size = Vector2(1000, TILE.y)
	_tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	_tiles.add_theme_constant_override("separation", 40)
	_offer_box.add_child(_tiles)
	_offer_box.add_child(_button("Later", Vector2(846, 580), minimise))

	_place_box = Control.new()
	_place_box.set_anchors_preset(PRESET_FULL_RECT)
	_panel.add_child(_place_box)
	_place_box.add_child(_title("Put it on your duck"))
	var frame := Panel.new()
	frame.position = Vector2(60, 64)
	frame.size = Vector2(DuckDrawing.SIZE * ZOOM) + Vector2(8, 8)
	_place_box.add_child(frame)
	var canvas := Control.new()
	canvas.position = Vector2(4, 4)
	canvas.size = Vector2(DuckDrawing.SIZE * ZOOM)
	canvas.clip_contents = true
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.mouse_default_cursor_shape = Control.CURSOR_MOVE
	canvas.gui_input.connect(_on_canvas_input)
	frame.add_child(canvas)
	var bg := ColorRect.new()
	bg.color = Color("f3ead2")
	bg.size = canvas.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(bg)
	_duck_rect = _pixel_rect(canvas.size)
	canvas.add_child(_duck_rect)
	_stamp_rect = _pixel_rect(Vector2.ZERO)
	canvas.add_child(_stamp_rect)

	var tools := VBoxContainer.new()
	tools.position = Vector2(580, 120)
	tools.add_theme_constant_override("separation", 10)
	_place_box.add_child(tools)
	var hint := Label.new()
	hint.text = "Drag to move it.\nScroll or use the buttons to resize."
	tools.add_child(hint)
	for spec in [
		["Rotate left  (Q)", rotate_step.bind(-1)],
		["Rotate right  (E)", rotate_step.bind(1)],
		["Flip  (F)", flip],
		["Smaller  (-)", scale_by.bind(1.0 / SCALE_STEP)],
		["Bigger  (+)", scale_by.bind(SCALE_STEP)],
	]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(220, 48)
		b.pressed.connect(spec[1])
		tools.add_child(b)
	_place_box.add_child(_button("Later", Vector2(700, 580), minimise))
	_place_box.add_child(_button("Done", Vector2(846, 580), done))

	_minimised_btn = Button.new()
	_minimised_btn.text = "Finish your stamp"
	_minimised_btn.custom_minimum_size = Vector2(200, 44)
	_minimised_btn.add_theme_font_size_override("font_size", 18)
	_minimised_btn.pressed.connect(restore)
	add_child(_minimised_btn)
	_minimised_btn.set_anchors_and_offsets_preset(PRESET_BOTTOM_LEFT, PRESET_MODE_MINSIZE, 12)
	_minimised_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _fill_tiles() -> void:
	for c in _tiles.get_children():
		c.queue_free()
	for id in offer:
		var b := Button.new()
		b.custom_minimum_size = TILE
		b.pressed.connect(choose.bind(String(id)))
		var art := _pixel_rect(TILE - Vector2(40, 40))
		art.position = Vector2(20, 20)
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture = ImageTexture.create_from_image(CardArt._load_image(DuckStamps.art_path(String(id))))
		b.add_child(art)
		_tiles.add_child(b)


func _show_step() -> void:
	_offer_box.visible = stamp_id == ""
	_place_box.visible = stamp_id != ""


func _sync_stamp() -> void:
	if _stamp_img == null:
		return
	var sz := Vector2(_stamp_img.get_size()) * ZOOM
	_stamp_rect.size = sz
	_stamp_rect.pivot_offset = sz * 0.5
	_stamp_rect.position = stamp_pos * ZOOM - sz * 0.5
	_stamp_rect.rotation = stamp_rot
	_stamp_rect.scale = Vector2(-stamp_scale if stamp_flip else stamp_scale, stamp_scale)


func _on_canvas_input(event: InputEvent) -> void:
	var px: Vector2 = event.position / ZOOM if "position" in event else Vector2.ZERO
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_dragging = true
				# Grabbing the stamp keeps the offset; clicking elsewhere drops it there.
				var r := Vector2(_stamp_img.get_size()).length() * 0.5 * stamp_scale
				_grab = px - stamp_pos if px.distance_to(stamp_pos) <= r else Vector2.ZERO
				move_to(px - _grab)
			MOUSE_BUTTON_WHEEL_UP:
				scale_by(SCALE_STEP)
			MOUSE_BUTTON_WHEEL_DOWN:
				scale_by(1.0 / SCALE_STEP)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		move_to(px - _grab)


func _unhandled_key_input(event: InputEvent) -> void:
	if not _place_box.visible or not _panel.visible or not event.pressed:
		return
	match event.keycode:
		KEY_Q:
			rotate_step(-1)
		KEY_E:
			rotate_step(1)
		KEY_F:
			flip()
		KEY_MINUS, KEY_KP_SUBTRACT:
			scale_by(1.0 / SCALE_STEP)
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			scale_by(SCALE_STEP)
		_:
			return
	get_viewport().set_input_as_handled()


func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(0, 16)
	l.size = Vector2(1000, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 28)
	return l


func _button(text: String, pos: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(130, 48)
	b.pressed.connect(cb)
	return b


func _pixel_rect(size_px: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.size = size_px
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
