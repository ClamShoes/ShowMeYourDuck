extends Control

const GameTypes = preload("res://scripts/rules/types.gd")
const PlayerCosmetics = preload("res://scripts/ui/player_cosmetics.gd")
const CardArt = preload("res://scripts/ui/card_art.gd")
const DuckDrawing = preload("res://scripts/ui/duck_drawing.gd")
const CardPickerScript = preload("res://scripts/ui/card_picker.gd")
const DuckEditorScript = preload("res://scripts/ui/duck_editor.gd")
const ScreenFit = preload("res://scripts/ui/screen_fit.gd")
const VolumeButtonScript = preload("res://scripts/ui/volume_button.gd")
const SEAT_COLORS: Array = preload("res://scripts/ui/table.gd").SEAT_COLORS
const Sounds = preload("res://scripts/audio/sfx.gd")
const TOUCH_PX := 48.0

const THUMB_BACK := Vector2(24, 32)
const THUMB_DUCK := Vector2(29, 35)
const SHARE_HINT := "Share this code"

const GOLD := Color("f4c542")
const DIM_TEXT := Color("8fa9a3")
const DARK_TEXT := Color("1a1a1a")
const COLUMN_TOP := 156.0
const COLUMN_W := 520.0
const COLUMN_H := 480.0

var _name_edit: LineEdit
var _code_edit: LineEdit
var _status: Label
var _menu_box: VBoxContainer
var _room_box: VBoxContainer
var _code_field: LineEdit
var _code_hint: Label
var _min_players := GameTypes.MIN_PLAYERS
var _player_list: VBoxContainer
var _start_btn: Button
var _preview_back: TextureButton
var _preview_safe: TextureButton
var _preview_duck: TextureButton
var _picker
var _editor

var _cosmetics: Dictionary = {}
var _duck_img: Image = null
var _last_players: Array = []
var _sent_name := ""


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_cosmetics = PlayerCosmetics.load_local()
	_duck_img = DuckDrawing.load_local()
	_build()
	_refresh_preview()
	if _duck_img != null:
		Net.set_duck_drawing(DuckDrawing.encode(_duck_img))
	Net.lobby_updated.connect(_on_lobby)
	Net.match_started.connect(_on_match_started)
	Net.connection_failed.connect(_on_fail)
	Net.notice.connect(func(msg): _status.text = msg)
	Net.duck_art_updated.connect(func(_pid): _rebuild_player_rows())
	if Net.room_code != "":
		_on_lobby(Net.room_code, Net.lobby_players, Net.is_host, Net.min_players)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("0f2e2c")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	var stage := ScreenFit.centred_stage(self)

	var title := Label.new()
	title.text = "Show me your duck"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 28)
	title.size = Vector2(ScreenFit.BASE.x, 76)
	title.add_theme_font_size_override("font_size", 60)
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_color_override("font_outline_color", Color("0a1f1d"))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 4)
	stage.add_child(title)

	var sub := Label.new()
	sub.text = "A bluffing game. Don't flip the duck."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 104)
	sub.size = Vector2(ScreenFit.BASE.x, 28)
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color("cfe3dc"))
	stage.add_child(sub)

	_build_you_panel(_panel(stage, Vector2(80, COLUMN_TOP)))

	var right := _panel(stage, Vector2(680, COLUMN_TOP))
	_menu_box = _column_box(right)
	_build_menu(_menu_box)
	_room_box = _column_box(right)
	_room_box.visible = false
	_build_room(_room_box)

	_status = Label.new()
	_status.position = Vector2(680, COLUMN_TOP + COLUMN_H + 8)
	_status.size = Vector2(COLUMN_W, 48)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage.add_child(_status)

	_picker = CardPickerScript.new()
	add_child(_picker)
	_picker.picked.connect(_on_card_picked)
	_editor = DuckEditorScript.new()
	add_child(_editor)
	_editor.finished.connect(_on_duck_finished)

	var volume := VolumeButtonScript.new()
	volume.anchor_left = 1.0
	volume.anchor_right = 1.0
	volume.offset_left = -16.0 - TOUCH_PX
	volume.offset_right = -16.0
	volume.offset_top = 16.0
	volume.offset_bottom = 16.0 + TOUCH_PX
	add_child(volume)


## Left column: your name and cards. Stays usable in a room (renames and card changes go live).
func _build_you_panel(panel: PanelContainer) -> void:
	var box := _column_box(panel)
	box.add_child(_heading("You"))
	box.add_child(_heading("Name", 16, DIM_TEXT))
	_name_edit = LineEdit.new()
	_name_edit.text = PlayerCosmetics.load_name()
	_sent_name = PlayerCosmetics.clean_name(_name_edit.text)
	_name_edit.max_length = PlayerCosmetics.MAX_NAME_LEN
	_name_edit.custom_minimum_size = Vector2(0, TOUCH_PX)
	_name_edit.text_submitted.connect(func(_t): _commit_name())
	_name_edit.focus_exited.connect(_commit_name)
	box.add_child(_name_edit)

	box.add_child(_heading("Your cards", 16, DIM_TEXT))
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 28)
	box.add_child(cards)
	_preview_back = _preview_slot(cards, "Back", "Change card back", _open_picker.bind("back"))
	_preview_safe = _preview_slot(cards, "Safe", "Change card front", _open_picker.bind("front"))
	_preview_duck = _preview_slot(cards, "Duck", "Draw your duck", _open_editor)
	var hint := _heading("Tap a card to change it", 16, DIM_TEXT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


## Right column when not in a room.
func _build_menu(box: VBoxContainer) -> void:
	box.add_child(_heading("Play"))
	var create := Button.new()
	create.text = "Create room"
	create.custom_minimum_size = Vector2(0, TOUCH_PX + 8)
	create.pressed.connect(_create_room)
	_primary(create)
	box.add_child(create)

	var or_join := _heading("or join a friend's room", 16, DIM_TEXT)
	or_join.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(or_join)
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	box.add_child(join_row)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "Room code"
	_code_edit.custom_minimum_size = Vector2(220, TOUCH_PX)
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_edit.text_submitted.connect(func(_t): _join_room())
	join_row.add_child(_code_edit)
	var join := Button.new()
	join.text = "Join"
	join.custom_minimum_size = Vector2(120, TOUCH_PX)
	join.pressed.connect(_join_room)
	join_row.add_child(join)

	box.add_child(_spacer())
	var how := Button.new()
	how.text = "How to play"
	how.custom_minimum_size = Vector2(0, TOUCH_PX)
	how.pressed.connect(func(): Net.start_tutorial(_display_name(), _cosmetics, _duck_img))
	box.add_child(how)


## Right column when in a room.
func _build_room(box: VBoxContainer) -> void:
	box.add_child(_heading("Room"))
	# Read-only LineEdit so the code can be selected and Ctrl+C'd (works in the browser too).
	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 8)
	box.add_child(code_row)
	_code_field = LineEdit.new()
	_code_field.editable = false
	_code_field.selecting_enabled = true
	_code_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_field.custom_minimum_size = Vector2(0, TOUCH_PX)
	_code_field.add_theme_font_size_override("font_size", 32)
	_code_field.add_theme_color_override("font_uneditable_color", GOLD)
	code_row.add_child(_code_field)
	var copy := Button.new()
	copy.text = "Copy"
	copy.custom_minimum_size = Vector2(88, TOUCH_PX)
	copy.pressed.connect(_copy_code)
	code_row.add_child(copy)
	_code_hint = Label.new()
	_code_hint.text = SHARE_HINT
	_code_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_code_hint.add_theme_color_override("font_color", DIM_TEXT)
	box.add_child(_code_hint)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_player_list = VBoxContainer.new()
	_player_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_player_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_player_list)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	var leave := Button.new()
	leave.text = "Leave room"
	leave.custom_minimum_size = Vector2(0, TOUCH_PX)
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.pressed.connect(func(): Net.leave_room(); _show_lobby(false))
	actions.add_child(leave)
	_start_btn = Button.new()
	_start_btn.text = "Start game"
	_start_btn.custom_minimum_size = Vector2(0, TOUCH_PX)
	_start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_btn.size_flags_stretch_ratio = 1.6
	_start_btn.pressed.connect(func(): Net.start_match())
	_primary(_start_btn)
	actions.add_child(_start_btn)


func _panel(stage: Control, pos: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", CardPickerScript.overlay_style())
	p.position = pos
	p.size = Vector2(COLUMN_W, COLUMN_H)
	stage.add_child(p)
	return p


func _column_box(parent: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	parent.add_child(box)
	return box


func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


func _heading(text: String, font_size := 26, color := GOLD) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


## Gold call-to-action look (Create room, Start game).
func _primary(b: Button) -> void:
	for state in [["normal", GOLD], ["hover", Color("f8d66e")], ["pressed", Color("d9a92a")], ["focus", GOLD], ["disabled", Color("5d6b5a")]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = state[1]
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(8)
		if state[0] == "focus":
			sb.draw_center = false
			sb.border_color = Color.WHITE
			sb.set_border_width_all(2)
		b.add_theme_stylebox_override(state[0], sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, DARK_TEXT)
	b.add_theme_color_override("font_disabled_color", Color("b8c4b4"))
	b.add_theme_font_size_override("font_size", 20)


func _preview_slot(parent: Control, caption: String, tip: String, on_press: Callable) -> TextureButton:
	var col := VBoxContainer.new()
	parent.add_child(col)
	var tex := TextureButton.new()
	tex.custom_minimum_size = Vector2(CardArt.CARD_SIZE)
	tex.ignore_texture_size = true
	tex.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tex.tooltip_text = tip
	tex.pressed.connect(on_press)
	tex.mouse_entered.connect(func(): tex.modulate = Color(1.15, 1.15, 1.15))
	tex.mouse_exited.connect(func(): tex.modulate = Color.WHITE)
	col.add_child(tex)
	var l := Label.new()
	l.text = caption
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", DIM_TEXT)
	col.add_child(l)
	return tex


func _refresh_preview() -> void:
	CardArt.set_local_preview(_cosmetics, _duck_img)
	_preview_back.texture_normal = CardArt.back_texture(CardArt.LOCAL_ID)
	_preview_safe.texture_normal = CardArt.face_texture(CardArt.LOCAL_ID, false)
	_preview_duck.texture_normal = CardArt.face_texture(CardArt.LOCAL_ID, true)


func _open_picker(kind: String) -> void:
	_picker.open(kind, String(_cosmetics.card_back_id if kind == "back" else _cosmetics.card_front_id))


func _on_card_picked(kind: String, id: String) -> void:
	if kind == "back":
		_cosmetics.card_back_id = id
	else:
		_cosmetics.card_front_id = id
	PlayerCosmetics.save_local(_cosmetics)
	Net.set_cosmetics(_cosmetics)
	_refresh_preview()


func _open_editor() -> void:
	_editor.open(_duck_img, String(_cosmetics.card_front_id))


func _on_duck_finished(img: Image) -> void:
	_duck_img = img
	DuckDrawing.save_local(img)
	# A redrawn duck starts over: no stamps earned, no destroy powers.
	PlayerCosmetics.save_progress({})
	_cosmetics.duck_progress = PlayerCosmetics.load_progress()
	Net.set_cosmetics(_cosmetics)
	_refresh_preview()
	Net.set_duck_drawing(DuckDrawing.encode(img))


func _display_name() -> String:
	var n := PlayerCosmetics.clean_name(_name_edit.text)
	PlayerCosmetics.save_name(n)
	return n


## Saves the name and, when in a room, renames you there for everyone.
func _commit_name() -> void:
	var n := _display_name()
	if n == _sent_name:
		return
	_sent_name = n
	Net.set_display_name(n)


func _create_room() -> void:
	_status.text = "Connecting…"
	Net.connect_and_create(_display_name(), _cosmetics)


func _join_room() -> void:
	_status.text = "Connecting…"
	Net.connect_and_join(_code_edit.text.strip_edges().to_upper(), _display_name(), _cosmetics)


func _on_lobby(code: String, players: Array, is_host: bool, min_players: int) -> void:
	_code_field.text = code
	_min_players = min_players
	var n := players.size()
	_start_btn.visible = is_host
	_start_btn.disabled = n < min_players or n > GameTypes.MAX_PLAYERS
	_start_btn.text = "Start game (%s/%s)" % [n, min_players] if n < min_players else "Start game (%s)" % n
	_code_hint.text = _share_hint(n)
	if _room_box.visible and n > _last_players.size():
		Sounds.play("player_join")
	if not _room_box.visible:
		_status.text = ""
	_last_players = players
	_rebuild_player_rows()
	_show_lobby(true)


func _share_hint(n: int) -> String:
	if n < _min_players:
		return "%s — need at least %s players" % [SHARE_HINT, _min_players]
	return SHARE_HINT


func _copy_code() -> void:
	if _code_field.text == "":
		return
	DisplayServer.clipboard_set(_code_field.text)
	_code_hint.text = "Copied!"
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(_code_hint):
			_code_hint.text = _share_hint(_last_players.size()))


func _rebuild_player_rows() -> void:
	for c in _player_list.get_children():
		if c.is_queued_for_deletion():
			continue
		_player_list.remove_child(c)
		c.queue_free()
	for i in _last_players.size():
		var p: Dictionary = _last_players[i]
		var row := _tile(_player_list, SEAT_COLORS[i % SEAT_COLORS.size()], false)
		row.add_child(_thumb(CardArt.back_texture_by_id(String(p.get("card_back_id", ""))), THUMB_BACK))
		var duck: Image = CardArt.duck_image_of(String(p.get("player_id", "")))
		if duck == null:
			duck = DuckDrawing.default_image()
		row.add_child(_thumb(ImageTexture.create_from_image(duck), THUMB_DUCK))
		var l := Label.new()
		l.text = "%s%s" % [p.name, " (you)" if String(p.get("player_id", "")) == Net.player_id else ""]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(l)
		if p.get("host", false):
			row.add_child(_host_badge())
	for i in maxi(0, _min_players - _last_players.size()):
		var row := _tile(_player_list, DIM_TEXT, true)
		var l := Label.new()
		l.text = "Waiting for player…"
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l.add_theme_color_override("font_color", DIM_TEXT)
		row.add_child(l)


## A player row: dark tile with a seat-coloured left edge. Returns the row to fill.
func _tile(parent: Control, accent: Color, empty: bool) -> HBoxContainer:
	var tile := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.12) if empty else Color("0c2321")
	sb.border_color = Color(accent, 0.5) if empty else accent
	sb.border_width_left = 6
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	tile.add_theme_stylebox_override("panel", sb)
	tile.custom_minimum_size = Vector2(0, THUMB_DUCK.y + 8)
	parent.add_child(tile)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	tile.add_child(row)
	return row


func _host_badge() -> Label:
	var badge := Label.new()
	badge.text = "HOST"
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", DARK_TEXT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = GOLD
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	badge.add_theme_stylebox_override("normal", sb)
	return badge


func _thumb(tex: Texture2D, size_px: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.custom_minimum_size = size_px
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return t


## Android back button: close a pop-up, then leave the room, then quit.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if _editor != null and _editor.visible:
		_editor.visible = false
	elif _picker != null and _picker.visible:
		_picker.close()
	elif _room_box != null and _room_box.visible:
		Net.leave_room()
		_show_lobby(false)
	else:
		get_tree().quit()


func _on_match_started() -> void:
	get_tree().change_scene_to_file("res://scenes/table.tscn")


func _on_fail(msg: String) -> void:
	_status.text = msg
	_show_lobby(false)


func _show_lobby(on: bool) -> void:
	_menu_box.visible = not on
	_room_box.visible = on
