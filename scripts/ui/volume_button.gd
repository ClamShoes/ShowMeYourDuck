extends Button
## Speaker button (lobby + table): opens a master volume slider and Mute toggle, saved by Sfx.

const Sounds = preload("res://scripts/audio/sfx.gd")
const TOUCH_PX := 48.0
const PANEL_W := 240.0

var _layer: CanvasLayer
var _panel: PanelContainer
var _slider: HSlider
var _mute: CheckBox


func _init() -> void:
	custom_minimum_size = Vector2(TOUCH_PX, TOUCH_PX)
	tooltip_text = "Volume"
	focus_mode = Control.FOCUS_NONE


func _ready() -> void:
	# Own layer so the panel paints above the table's card / pick / stamp layers.
	_layer = CanvasLayer.new()
	_layer.layer = 300
	add_child(_layer)
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	_layer.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "Volume"
	box.add_child(title)
	var s := Sounds.load_settings()
	_slider = HSlider.new()
	_slider.max_value = 100
	_slider.step = 1
	_slider.value = s.volume * 100.0
	_slider.custom_minimum_size = Vector2(0, TOUCH_PX)
	_slider.value_changed.connect(func(v: float):
		Sounds.set_volume(v / 100.0)
		queue_redraw())
	box.add_child(_slider)
	_mute = CheckBox.new()
	_mute.text = "Mute"
	_mute.button_pressed = s.muted
	_mute.custom_minimum_size = Vector2(0, TOUCH_PX)
	_mute.toggled.connect(func(on: bool):
		Sounds.set_muted(on)
		queue_redraw())
	box.add_child(_mute)
	pressed.connect(_toggle)


func _toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		var r := get_global_rect()
		var vp := get_viewport_rect().size
		_panel.reset_size()
		_panel.position = Vector2(clampf(r.end.x - _panel.size.x, 8.0, vp.x - _panel.size.x - 8.0), r.end.y + 6.0)


## Tap anywhere else closes the panel.
func _input(event: InputEvent) -> void:
	if not _panel.visible or not (event is InputEventMouseButton and event.pressed):
		return
	var p := get_global_mouse_position()
	if not _panel.get_global_rect().has_point(p) and not get_global_rect().has_point(p):
		_panel.visible = false


func _draw() -> void:
	var c := size * 0.5 + Vector2(-3, 0)
	var col := get_theme_color("font_color")
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-10, -4), c + Vector2(-4, -4), c + Vector2(3, -11),
		c + Vector2(3, 11), c + Vector2(-4, 4), c + Vector2(-10, 4),
	]), col)
	var volume := _slider.value / 100.0
	if _mute.button_pressed or volume <= 0.0:
		draw_line(c + Vector2(7, -5), c + Vector2(15, 5), col, 2.5)
		draw_line(c + Vector2(15, -5), c + Vector2(7, 5), col, 2.5)
		return
	for i in ceili(volume * 2.0):
		draw_arc(c + Vector2(3, 0), 6.0 + i * 5.0, -0.9, 0.9, 12, col, 2.0)
