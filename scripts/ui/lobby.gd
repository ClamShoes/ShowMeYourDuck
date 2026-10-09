extends Control

const GameTypes = preload("res://scripts/rules/types.gd")
const PlayerCosmetics = preload("res://scripts/ui/player_cosmetics.gd")
const CardArt = preload("res://scripts/ui/card_art.gd")
const DuckDrawing = preload("res://scripts/ui/duck_drawing.gd")
const CardPickerScript = preload("res://scripts/ui/card_picker.gd")
const DuckEditorScript = preload("res://scripts/ui/duck_editor.gd")
const ScreenFit = preload("res://scripts/ui/screen_fit.gd")
const TOUCH_PX := 48.0

const THUMB_BACK := Vector2(24, 32)
const THUMB_DUCK := Vector2(29, 35)
const SHARE_HINT := "Share this code"

var _name_edit: LineEdit
var _code_edit: LineEdit
var _status: Label
var _lobby_panel: Panel
var _code_field: LineEdit
var _code_hint: Label
var _min_players := GameTypes.MIN_PLAYERS
var _player_list: VBoxContainer
var _start_btn: Button
var _preview_back: TextureRect
var _preview_safe: TextureRect
var _preview_duck: TextureRect
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
	title.position = Vector2(0, 48)
	title.size = Vector2(ScreenFit.BASE.x, 64)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("f4c542"))
	stage.add_child(title)

	var sub := Label.new()
	sub.text = "A bluffing game. Don't flip the duck."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 108)
	sub.size = Vector2(ScreenFit.BASE.x, 28)
	stage.add_child(sub)

	var form := VBoxContainer.new()
	form.position = Vector2(60, 170)
	form.size = Vector2(400, 420)
	form.add_theme_constant_override("separation", 10)
	stage.add_child(form)

	form.add_child(_labeled("Your name"))
	_name_edit = LineEdit.new()
	_name_edit.text = PlayerCosmetics.load_name()
	_sent_name = PlayerCosmetics.clean_name(_name_edit.text)
	_name_edit.max_length = PlayerCosmetics.MAX_NAME_LEN
	_name_edit.custom_minimum_size = Vector2(0, TOUCH_PX)
	_name_edit.text_submitted.connect(func(_t): _commit_name())
	_name_edit.focus_exited.connect(_commit_name)
	form.add_child(_name_edit)

	var create := Button.new()
	create.text = "Create room"
	create.custom_minimum_size = Vector2(0, TOUCH_PX)
	create.pressed.connect(_create_room)
	form.add_child(create)

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	form.add_child(join_row)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "Room code"
	_code_edit.custom_minimum_size = Vector2(220, TOUCH_PX)
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(_code_edit)
	var join := Button.new()
	join.text = "Join"
	join.custom_minimum_size = Vector2(120, TOUCH_PX)
	join.pressed.connect(_join_room)
	join_row.add_child(join)

	var how := Button.new()
	how.text = "How to play"
	how.custom_minimum_size = Vector2(0, TOUCH_PX)
	how.pressed.connect(func(): Net.start_tutorial(_display_name(), _cosmetics, _duck_img))
	form.add_child(how)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(_status)

	_build_cards_panel(stage)

	_lobby_panel = Panel.new()
	_lobby_panel.position = Vector2(900, 170)
	_lobby_panel.size = Vector2(340, 470)
	_lobby_panel.visible = false
	stage.add_child(_lobby_panel)
	var lp := VBoxContainer.new()
	lp.set_anchors_preset(PRESET_FULL_RECT)
	lp.offset_left = 16
	lp.offset_top = 16
	lp.offset_right = -16
	lp.offset_bottom = -16
	lp.add_theme_constant_override("separation", 8)
	_lobby_panel.add_child(lp)
	# Read-only LineEdit so the code can be selected and Ctrl+C'd (works in the browser too).
	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 8)
	lp.add_child(code_row)
	_code_field = LineEdit.new()
	_code_field.editable = false
	_code_field.selecting_enabled = true
	_code_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_field.custom_minimum_size = Vector2(0, 44)
	_code_field.add_theme_font_size_override("font_size", 28)
	_code_field.add_theme_color_override("font_uneditable_color", Color.WHITE)
	code_row.add_child(_code_field)
	var copy := Button.new()
	copy.text = "Copy"
	copy.custom_minimum_size = Vector2(72, TOUCH_PX)
	copy.pressed.connect(_copy_code)
	code_row.add_child(copy)
	_code_hint = Label.new()
	_code_hint.text = SHARE_HINT
	_code_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lp.add_child(_code_hint)
	_player_list = VBoxContainer.new()
	_player_list.add_theme_constant_override("separation", 6)
	lp.add_child(_player_list)
	_start_btn = Button.new()
	_start_btn.text = "Start game"
	_start_btn.custom_minimum_size = Vector2(0, TOUCH_PX)
	_start_btn.pressed.connect(func(): Net.start_match())
	lp.add_child(_start_btn)
	var leave := Button.new()
	leave.text = "Leave room"
	leave.custom_minimum_size = Vector2(0, TOUCH_PX)
	leave.pressed.connect(func(): Net.leave_room(); _show_lobby(false))
	lp.add_child(leave)

	_picker = CardPickerScript.new()
	add_child(_picker)
	_picker.picked.connect(_on_card_picked)
	_editor = DuckEditorScript.new()
	add_child(_editor)
	_editor.finished.connect(_on_duck_finished)


func _build_cards_panel(stage: Control) -> void:
	var panel := Panel.new()
	panel.position = Vector2(500, 170)
	panel.size = Vector2(360, 300)
	stage.add_child(panel)
	var box := VBoxContainer.new()
	box.set_anchors_preset(PRESET_FULL_RECT)
	box.offset_left = 20
	box.offset_top = 14
	box.offset_right = -20
	box.offset_bottom = -14
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(_labeled("Your cards"))

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	box.add_child(cards)
	_preview_back = _preview_slot(cards, "Back")
	_preview_safe = _preview_slot(cards, "Safe")
	_preview_duck = _preview_slot(cards, "Duck")

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	for spec in [["Card back", _open_picker.bind("back")], ["Card front", _open_picker.bind("front")], ["Draw duck", _open_editor]]:
		var b := Button.new()
		b.text = spec[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, TOUCH_PX)
		b.pressed.connect(spec[1])
		buttons.add_child(b)


func _preview_slot(parent: Control, caption: String) -> TextureRect:
	var col := VBoxContainer.new()
	parent.add_child(col)
	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(CardArt.CARD_SIZE)
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	col.add_child(tex)
	var l := Label.new()
	l.text = caption
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	return tex


func _labeled(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _refresh_preview() -> void:
	CardArt.set_local_preview(_cosmetics, _duck_img)
	_preview_back.texture = CardArt.back_texture(CardArt.LOCAL_ID)
	_preview_safe.texture = CardArt.face_texture(CardArt.LOCAL_ID, false)
	_preview_duck.texture = CardArt.face_texture(CardArt.LOCAL_ID, true)


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
	_last_players = players
	_rebuild_player_rows()
	_show_lobby(true)
	_status.text = "In room %s" % code


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
	for p in _last_players:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_player_list.add_child(row)
		row.add_child(_thumb(CardArt.back_texture_by_id(String(p.get("card_back_id", ""))), THUMB_BACK))
		var duck: Image = CardArt.duck_image_of(String(p.get("player_id", "")))
		if duck == null:
			duck = DuckDrawing.default_image()
		row.add_child(_thumb(ImageTexture.create_from_image(duck), THUMB_DUCK))
		var l := Label.new()
		l.text = "%s%s" % [p.name, " (host)" if p.get("host", false) else ""]
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)


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
	elif _lobby_panel != null and _lobby_panel.visible:
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
	_lobby_panel.visible = on
