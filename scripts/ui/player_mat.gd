class_name PlayerMat
extends Panel

var player_id: String = ""
var seat_color: Color = Color.WHITE

var _name_label: Label
var _meta_label: Label
var _stack_box: Control
var _passed: Label


func _ready() -> void:
	custom_minimum_size = Vector2(210, 168)
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(p_id: String, color: Color) -> void:
	player_id = p_id
	seat_color = color
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r, color.g, color.b, 0.22)
	sb.border_color = color
	sb.set_border_width_all(3)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	add_theme_stylebox_override("panel", sb)

	_name_label = Label.new()
	_name_label.position = Vector2(12, 8)
	_name_label.size = Vector2(186, 24)
	_name_label.add_theme_font_size_override("font_size", 18)
	add_child(_name_label)

	_meta_label = Label.new()
	_meta_label.position = Vector2(12, 32)
	_meta_label.size = Vector2(186, 20)
	_meta_label.add_theme_font_size_override("font_size", 14)
	_meta_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	add_child(_meta_label)

	_passed = Label.new()
	_passed.text = "PASSED"
	_passed.visible = false
	_passed.position = Vector2(120, 8)
	_passed.add_theme_color_override("font_color", Color("f4d35e"))
	add_child(_passed)

	_stack_box = Control.new()
	_stack_box.position = Vector2(16, 58)
	_stack_box.size = Vector2(178, 96)
	_stack_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stack_box)


func refresh(info: Dictionary, is_turn: bool, is_self: bool) -> void:
	var nm := String(info.name)
	if is_self:
		nm += " (you)"
	if is_turn:
		nm = "> " + nm
	_name_label.text = nm
	_meta_label.text = "Pts %s   Hand %s   Stack %s" % [info.points, info.hand_count, info.stack_count]
	_passed.visible = info.passed and not info.eliminated
	modulate = Color(0.45, 0.45, 0.45, 1) if info.eliminated else Color.WHITE
	_rebuild_stack(int(info.stack_count))


func _rebuild_stack(count: int) -> void:
	for c in _stack_box.get_children():
		c.queue_free()
	for i in count:
		var token := Panel.new()
		token.position = Vector2(i * 14, i * 8)
		token.size = Vector2(70, 96)
		token.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("1f4f4a")
		sb.border_color = Color("c9a227")
		sb.set_border_width_all(2)
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_left = 6
		sb.corner_radius_bottom_right = 6
		token.add_theme_stylebox_override("panel", sb)
		_stack_box.add_child(token)


func contains_point(global_pt: Vector2) -> bool:
	return get_global_rect().has_point(global_pt)
