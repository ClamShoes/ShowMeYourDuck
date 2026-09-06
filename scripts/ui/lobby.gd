extends Control

const GameTypes = preload("res://scripts/rules/types.gd")

var _name_edit: LineEdit
var _url_edit: LineEdit
var _code_edit: LineEdit
var _status: Label
var _lobby_panel: Panel
var _code_label: Label
var _player_list: VBoxContainer
var _start_btn: Button


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_build()
	Net.lobby_updated.connect(_on_lobby)
	Net.match_started.connect(_on_match_started)
	Net.connection_failed.connect(_on_fail)
	Net.notice.connect(func(msg): _status.text = msg)
	if Net.room_code != "":
		_show_lobby(true)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("0f2e2c")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "Show me your duck"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 48)
	title.size = Vector2(1280, 64)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("f4c542"))
	add_child(title)

	var sub := Label.new()
	sub.text = "A bluffing game. Don't flip the duck."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 108)
	sub.size = Vector2(1280, 28)
	add_child(sub)

	var form := VBoxContainer.new()
	form.position = Vector2(420, 170)
	form.size = Vector2(440, 420)
	form.add_theme_constant_override("separation", 10)
	add_child(form)

	form.add_child(_labeled("Your name", true))
	_name_edit = LineEdit.new()
	_name_edit.text = "Mallard"
	_name_edit.custom_minimum_size = Vector2(0, 36)
	form.add_child(_name_edit)

	form.add_child(_labeled("Server URL", false))
	_url_edit = LineEdit.new()
	_url_edit.text = Net.server_url
	_url_edit.custom_minimum_size = Vector2(0, 36)
	form.add_child(_url_edit)

	var create := Button.new()
	create.text = "Create room"
	create.custom_minimum_size = Vector2(0, 42)
	create.pressed.connect(_create_room)
	form.add_child(create)

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	form.add_child(join_row)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "Room code"
	_code_edit.custom_minimum_size = Vector2(220, 40)
	join_row.add_child(_code_edit)
	var join := Button.new()
	join.text = "Join"
	join.custom_minimum_size = Vector2(120, 40)
	join.pressed.connect(_join_room)
	join_row.add_child(join)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(_status)

	_lobby_panel = Panel.new()
	_lobby_panel.position = Vector2(900, 170)
	_lobby_panel.size = Vector2(340, 400)
	_lobby_panel.visible = false
	add_child(_lobby_panel)
	var lp := VBoxContainer.new()
	lp.set_anchors_preset(PRESET_FULL_RECT)
	lp.offset_left = 16
	lp.offset_top = 16
	lp.offset_right = -16
	lp.offset_bottom = -16
	lp.add_theme_constant_override("separation", 8)
	_lobby_panel.add_child(lp)
	_code_label = Label.new()
	_code_label.add_theme_font_size_override("font_size", 28)
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lp.add_child(_code_label)
	var hint := Label.new()
	hint.text = "Share this code"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lp.add_child(hint)
	_player_list = VBoxContainer.new()
	lp.add_child(_player_list)
	_start_btn = Button.new()
	_start_btn.text = "Start game"
	_start_btn.pressed.connect(func(): Net.start_match())
	lp.add_child(_start_btn)
	var leave := Button.new()
	leave.text = "Leave room"
	leave.pressed.connect(func(): Net.leave_room(); _show_lobby(false))
	lp.add_child(leave)


func _labeled(text: String, _big: bool) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _display_name() -> String:
	var n := _name_edit.text.strip_edges()
	if n == "":
		return "Mallard"
	return n


func _create_room() -> void:
	_status.text = "Connecting…"
	Net.server_url = _url_edit.text.strip_edges()
	Net.connect_and_create(_display_name())


func _join_room() -> void:
	_status.text = "Connecting…"
	Net.server_url = _url_edit.text.strip_edges()
	Net.connect_and_join(_code_edit.text.strip_edges().to_upper(), _display_name())


func _on_lobby(code: String, players: Array, is_host: bool) -> void:
	_code_label.text = code
	_start_btn.visible = is_host
	_start_btn.disabled = players.size() < GameTypes.MIN_PLAYERS or players.size() > GameTypes.MAX_PLAYERS
	_start_btn.text = "Start game (%s)" % players.size()
	for c in _player_list.get_children():
		if c.is_queued_for_deletion():
			continue
		_player_list.remove_child(c)
		c.queue_free()
	for p in players:
		var l := Label.new()
		var extra := " (host)" if p.get("host", false) else ""
		l.text = "• %s%s" % [p.name, extra]
		_player_list.add_child(l)
	_show_lobby(true)
	_status.text = "In room %s" % code


func _on_match_started() -> void:
	get_tree().change_scene_to_file("res://scenes/table.tscn")


func _on_fail(msg: String) -> void:
	_status.text = msg
	_show_lobby(false)


func _show_lobby(on: bool) -> void:
	_lobby_panel.visible = on
