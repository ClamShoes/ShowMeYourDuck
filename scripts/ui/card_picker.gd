class_name CardPicker
extends Control
## Modal grid of card backs or fronts. Emits picked(kind, id) and closes; the lobby saves/sends.

signal picked(kind: String, id: String)

const CardCatalog = preload("res://scripts/ui/card_catalog.gd")
const CardArt = preload("res://scripts/ui/card_art.gd")
const ScreenFit = preload("res://scripts/ui/screen_fit.gd")

const PANEL_SIZE := Vector2(980, 600)

var _title: Label
var _grid: GridContainer
var _kind := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: close())
	add_child(dim)

	var panel := PanelContainer.new()
	panel.position = (ScreenFit.BASE - PANEL_SIZE) * 0.5
	panel.size = PANEL_SIZE
	panel.add_theme_stylebox_override("panel", overlay_style())
	ScreenFit.centred_stage(self).add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var head := HBoxContainer.new()
	box.add_child(head)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(100, 48)
	close_btn.pressed.connect(close)
	head.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 7
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)


## kind: "back" or "front".
func open(kind: String, current_id: String) -> void:
	_kind = kind
	_title.text = "Choose your card back" if kind == "back" else "Choose your card front"
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var group := ButtonGroup.new()
	var entries: Dictionary = CardCatalog.BACKS if kind == "back" else CardCatalog.FRONTS
	for id in entries.keys():
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = id == current_id
		b.text = String(entries[id].get("label", id))
		b.icon = CardArt.back_texture_by_id(id) if kind == "back" else CardArt.safe_face_by_front(id)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.custom_minimum_size = Vector2(122, 168)
		b.pressed.connect(_on_pick.bind(String(id)))
		_grid.add_child(b)
	visible = true


## Opaque panel for modal overlays (the default theme panel is see-through).
static func overlay_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("16302e")
	sb.border_color = Color("f4c542")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(16)
	return sb


func close() -> void:
	visible = false


func _on_pick(id: String) -> void:
	picked.emit(_kind, id)
	close()
