extends Control
## Tutorial instruction card (left of the hand, clear of the 3-player seats) and a pulsing outline
## around whatever the current step wants you to touch. Never blocks clicks outside the card.

signal leave_requested

const ScreenFit = preload("res://scripts/ui/screen_fit.gd")
const SeatSpace = preload("res://scripts/ui/seat_space.gd")

const TOUCH_PX := 48.0
const PANEL_W := 380.0
const OUTLINE := Color("f4d35e")

var _tutorial
## target name -> global Rect2 on this screen; an empty rect means nothing to point at right now.
var _target_rect: Callable
var _panel: PanelContainer
var _text: Label
var _button: Button
var _target := ""
var _t := 0.0


func setup(tutorial, target_rect: Callable) -> void:
	_tutorial = tutorial
	_target_rect = target_rect
	tutorial.step_changed.connect(_on_step)
	tutorial.finished.connect(leave_requested.emit)
	tutorial.announce()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.12, 0.11, 0.94)
	sb.border_color = OUTLINE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "How to play"
	title.add_theme_color_override("font_color", OUTLINE)
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(PANEL_W - 28.0, 0)
	_text.add_theme_font_size_override("font_size", 19)
	box.add_child(_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var skip := Button.new()
	skip.text = "Skip tutorial"
	skip.custom_minimum_size = Vector2(130, TOUCH_PX)
	skip.pressed.connect(leave_requested.emit)
	row.add_child(skip)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	_button = Button.new()
	_button.custom_minimum_size = Vector2(110, TOUCH_PX)
	_button.pressed.connect(func(): _tutorial.press_button())
	row.add_child(_button)


func _on_step(text: String, target: String, button: String) -> void:
	_text.text = text
	_target = target
	_button.text = button
	_button.visible = button != ""


func _process(delta: float) -> void:
	_t += delta
	var safe := ScreenFit.safe_rect(get_viewport())
	var h := _panel.get_combined_minimum_size().y
	_panel.size = Vector2(PANEL_W, h)
	# Bottom edge level with the top of the hand, so it never covers your cards or the bid row.
	_panel.position = Vector2(safe.position.x + 24.0, SeatSpace.hand_pos(safe).y - 8.0 - h)
	queue_redraw()


func _draw() -> void:
	if _target == "" or not _target_rect.is_valid():
		return
	var r: Rect2 = _target_rect.call(_target)
	if r.size == Vector2.ZERO:
		return
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	draw_rect(r.grow(6.0 + 4.0 * pulse), Color(OUTLINE, 0.45 + 0.55 * pulse), false, 4.0)
