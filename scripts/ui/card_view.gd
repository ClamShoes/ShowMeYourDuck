class_name CardView
extends Control

signal dropped(card, at: Vector2)
signal pressed(card)

const SIZE := Vector2(92, 128)
const CORNER_RADIUS := 8
const HOVER_LIFT := -16.0
const HOVER_SCALE := 1.2
const HOVER_DURATION := 0.2

var card_id: String = ""
var is_duck: bool = false
var face_up: bool = true
var interactable: bool = false
var drag_enabled: bool = true

var _dragging := false
var _hovering := false
var _built := false
var _home_global := Vector2.ZERO
var _content: Control
var _face: Panel
var _back: Panel
var _label: Label
var _shadow: Panel
var _hover_tween: Tween


func setup(p_id: String, p_is_duck: bool, p_face_up: bool, p_interactable: bool, p_drag: bool = true) -> void:
	card_id = p_id
	is_duck = p_is_duck
	face_up = p_face_up
	interactable = p_interactable
	drag_enabled = p_drag
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not _built:
		_build()
		_built = true
	_refresh()


func _build() -> void:
	_content = Control.new()
	_content.size = SIZE
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	_shadow = Panel.new()
	_shadow.position = Vector2(6, 8)
	_shadow.size = SIZE
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow_sb := StyleBoxFlat.new()
	shadow_sb.bg_color = Color(0, 0, 0, 0.35)
	shadow_sb.set_corner_radius_all(CORNER_RADIUS)
	shadow_sb.set_border_width_all(0)
	_shadow.add_theme_stylebox_override("panel", shadow_sb)
	_content.add_child(_shadow)

	_back = Panel.new()
	_back.size = SIZE
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back_sb := StyleBoxFlat.new()
	back_sb.bg_color = Color("1f4f4a")
	back_sb.border_color = Color("c9a227")
	back_sb.set_border_width_all(3)
	back_sb.set_corner_radius_all(CORNER_RADIUS)
	_back.add_theme_stylebox_override("panel", back_sb)
	_content.add_child(_back)

	var back_mark := Label.new()
	back_mark.text = "SMYD"
	back_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	back_mark.set_anchors_preset(PRESET_FULL_RECT)
	back_mark.add_theme_font_size_override("font_size", 14)
	back_mark.add_theme_color_override("font_color", Color("f4d35e"))
	_back.add_child(back_mark)

	_face = Panel.new()
	_face.size = SIZE
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_face)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(PRESET_FULL_RECT)
	_label.add_theme_font_size_override("font_size", 18)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_face.add_child(_label)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _refresh() -> void:
	var sb := StyleBoxFlat.new()
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(CORNER_RADIUS)
	if is_duck:
		sb.bg_color = Color("f4c542")
		sb.border_color = Color("c45c14")
		_label.text = "DUCK"
		_label.add_theme_color_override("font_color", Color("3a2208"))
	else:
		sb.bg_color = Color("eef6e8")
		sb.border_color = Color("3d7a4a")
		_label.text = "SAFE"
		_label.add_theme_color_override("font_color", Color("1d4a28"))
	_face.add_theme_stylebox_override("panel", sb)
	_face.visible = face_up
	_back.visible = not face_up


func _on_mouse_entered() -> void:
	if not interactable or _dragging:
		return
	_hovering = true
	_play_hover(true)


func _on_mouse_exited() -> void:
	if _dragging:
		return
	_hovering = false
	_play_hover(false)


func _play_hover(selected: bool) -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	var target_scale := Vector2(HOVER_SCALE, HOVER_SCALE) if selected else Vector2.ONE
	var target_y := HOVER_LIFT if selected else 0.0
	_hover_tween.tween_property(self, "scale", target_scale, HOVER_DURATION)
	_hover_tween.tween_property(_content, "position:y", target_y, HOVER_DURATION)
	z_index = 5 if selected else 0


func remember_rest_position() -> void:
	pass


func _gui_input(event: InputEvent) -> void:
	if not interactable:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pressed.emit(self)
			if drag_enabled:
				if _hover_tween and _hover_tween.is_valid():
					_hover_tween.kill()
				scale = Vector2.ONE
				_content.position = Vector2.ZERO
				_dragging = true
				_home_global = global_position
				z_index = 40
			accept_event()
		else:
			if _dragging:
				_dragging = false
				z_index = 5 if _hovering else 0
				dropped.emit(self, get_global_mouse_position())
			accept_event()


func _process(_delta: float) -> void:
	if _dragging:
		global_position = get_global_mouse_position() - SIZE * 0.5
		var center := get_viewport_rect().size * 0.5
		var dx: float = (global_position.x - center.x) / max(center.x, 1.0)
		_shadow.position = Vector2(6 - dx * 10.0, 8)


func snap_home() -> void:
	global_position = _home_global
	_shadow.position = Vector2(6, 8)
	if _hovering:
		_play_hover(true)
	else:
		scale = Vector2.ONE
		_content.position = Vector2.ZERO
		z_index = 0
