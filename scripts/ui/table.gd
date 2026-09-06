extends Control

const GameTypes = preload("res://scripts/rules/types.gd")
const CardViewScript = preload("res://scripts/ui/card_view.gd")
const PlayerMatScript = preload("res://scripts/ui/player_mat.gd")
const GameProtocol = preload("res://scripts/net/protocol.gd")

const SEAT_COLORS := [
	Color("e07a3d"),
	Color("3d9be0"),
	Color("5cb85c"),
	Color("c05ce0"),
	Color("e0c03d"),
	Color("e05c7a"),
]

var _bid_amount := 1
var _status: Label
var _banner: Label
var _hand_box: HBoxContainer
var _mats_root: Control
var _mats: Dictionary = {}
var _bid_row: HBoxContainer
var _bid_label: Label
var _error: Label
var _render_queued := false


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_build_chrome()
	Net.match_updated.connect(_on_net_update)
	_queue_render()


func _build_chrome() -> void:
	var bg := ColorRect.new()
	bg.color = Color("14352f")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_status = Label.new()
	_status.position = Vector2(24, 12)
	_status.size = Vector2(900, 36)
	_status.add_theme_font_size_override("font_size", 22)
	add_child(_status)

	var back := Button.new()
	back.text = "Leave"
	back.position = Vector2(1140, 12)
	back.size = Vector2(110, 36)
	back.pressed.connect(_leave)
	add_child(back)

	_banner = Label.new()
	_banner.position = Vector2(24, 48)
	_banner.size = Vector2(1230, 28)
	_banner.add_theme_color_override("font_color", Color("f4d35e"))
	add_child(_banner)

	_mats_root = Control.new()
	_mats_root.set_anchors_preset(PRESET_FULL_RECT)
	_mats_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mats_root)

	_hand_box = HBoxContainer.new()
	_hand_box.position = Vector2(300, 560)
	_hand_box.size = Vector2(680, 140)
	_hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_hand_box)

	_bid_row = HBoxContainer.new()
	_bid_row.position = Vector2(430, 508)
	_bid_row.size = Vector2(420, 44)
	_bid_row.add_theme_constant_override("separation", 8)
	add_child(_bid_row)

	var minus := Button.new()
	minus.text = "-"
	minus.custom_minimum_size = Vector2(40, 40)
	minus.pressed.connect(func(): _bid_amount = max(1, _bid_amount - 1); _sync_bid_label())
	_bid_row.add_child(minus)

	_bid_label = Label.new()
	_bid_label.custom_minimum_size = Vector2(80, 40)
	_bid_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bid_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bid_row.add_child(_bid_label)

	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(40, 40)
	plus.pressed.connect(func(): _bid_amount += 1; _sync_bid_label())
	_bid_row.add_child(plus)

	var bid_btn := Button.new()
	bid_btn.text = "Bid"
	bid_btn.custom_minimum_size = Vector2(80, 40)
	bid_btn.pressed.connect(_on_bid_pressed)
	_bid_row.add_child(bid_btn)

	var pass_btn := Button.new()
	pass_btn.text = "Pass"
	pass_btn.custom_minimum_size = Vector2(80, 40)
	pass_btn.pressed.connect(func(): _submit(GameProtocol.pass_bid()))
	_bid_row.add_child(pass_btn)

	_error = Label.new()
	_error.position = Vector2(24, 680)
	_error.size = Vector2(1230, 28)
	_error.add_theme_color_override("font_color", Color("ff8a7a"))
	add_child(_error)


func _on_net_update(_snap: Dictionary) -> void:
	_queue_render()


func _leave() -> void:
	Net.leave_room()
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _snapshot() -> Dictionary:
	return Net.last_snapshot


func _viewer_id() -> String:
	return Net.player_id


func _queue_render() -> void:
	if _render_queued:
		return
	_render_queued = true
	call_deferred("_render")


func _submit(intent: Dictionary) -> Dictionary:
	Net.submit_intent(intent)
	_error.text = ""
	return {"ok": true, "error": ""}


func _render() -> void:
	_render_queued = false
	var snap: Dictionary = _snapshot()
	if snap.is_empty():
		return
	var viewer := _viewer_id()
	_status.text = _status_text(snap, viewer)
	_banner.text = _banner_text(snap)
	_layout_mats(snap, viewer)
	_layout_hand(snap)
	_update_bid_row(snap, viewer)


func _status_text(snap: Dictionary, viewer: String) -> String:
	var phase := int(snap.phase)
	match phase:
		GameTypes.Phase.PLACE_INITIAL:
			var me := _player_info(snap, viewer)
			if me.get("placed_initial", false):
				return "Waiting for everyone to play their opening card…"
			return "Everyone plays one card face-down onto their mat."
		GameTypes.Phase.PLACE_OR_BID:
			if snap.current_player_id == viewer:
				return "Play another card, or open the bidding."
			return "Waiting for a card or a bid…"
		GameTypes.Phase.BIDDING:
			return "Bidding — current bid %s. Raise or pass." % snap.current_bid
		GameTypes.Phase.REVEAL:
			if snap.challenger_id == viewer:
				return "Flip %s more. Your stack first, then tap another mat." % snap.flips_remaining
			return "Watch the challenge…"
		GameTypes.Phase.CHOOSE_DISCARD:
			return "You hit your own Duck. Tap a card in your hand to discard it forever."
		GameTypes.Phase.GAME_OVER:
			return "Game over."
		_:
			return "Show me your duck"


func _banner_text(snap: Dictionary) -> String:
	if int(snap.phase) == GameTypes.Phase.GAME_OVER:
		var winner := _player_name(snap, String(snap.winner_id))
		return "%s wins!" % winner
	if snap.flip_history.size() > 0:
		var last: Dictionary = snap.flip_history[snap.flip_history.size() - 1]
		if last.is_duck:
			return "A DUCK! Challenge failed."
		return "Safe. %s left to flip." % snap.flips_remaining
	return ""


func _player_name(snap: Dictionary, pid: String) -> String:
	for p in snap.players:
		if p.id == pid:
			return String(p.name)
	return pid


func _layout_mats(snap: Dictionary, viewer: String) -> void:
	_clear(_mats_root)
	_mats.clear()
	var ids: Array = []
	for p in snap.players:
		ids.append(String(p.id))
	if viewer in ids:
		while String(ids[0]) != viewer:
			ids.append(ids.pop_front())
	var n := ids.size()
	var positions := _seat_positions(n)
	for i in n:
		var pid: String = String(ids[i])
		var info := _player_info(snap, pid)
		var mat = PlayerMatScript.new()
		_mats_root.add_child(mat)
		mat.setup(pid, SEAT_COLORS[i % SEAT_COLORS.size()])
		mat.position = positions[i]
		var turn := String(snap.current_player_id) == pid
		if int(snap.phase) == GameTypes.Phase.PLACE_INITIAL:
			turn = not bool(info.get("placed_initial", false)) and not bool(info.get("eliminated", false))
		elif int(snap.phase) == GameTypes.Phase.REVEAL or int(snap.phase) == GameTypes.Phase.CHOOSE_DISCARD:
			turn = String(snap.challenger_id) == pid
		mat.refresh(info, turn, pid == viewer)
		mat.gui_input.connect(_on_mat_input.bind(pid))
		_mats[pid] = mat


func _player_info(snap: Dictionary, pid: String) -> Dictionary:
	for p in snap.players:
		if p.id == pid:
			return p
	return {}


func _seat_positions(n: int) -> Array:
	var bottom := Vector2(535, 330)
	var top := Vector2(535, 90)
	var left := Vector2(40, 210)
	var right := Vector2(1030, 210)
	var top_left := Vector2(180, 90)
	var top_right := Vector2(890, 90)
	match n:
		2:
			return [bottom, top]
		3:
			return [bottom, top_left, top_right]
		4:
			return [bottom, left, top, right]
		5:
			return [bottom, left, top_left, top_right, right]
		_:
			return [bottom, left, top_left, top, top_right, right]


func _layout_hand(snap: Dictionary) -> void:
	if not snap.has("you"):
		_clear(_hand_box)
		return
	var phase := int(snap.phase)
	var viewer := _viewer_id()
	var can_play := false
	if phase == GameTypes.Phase.PLACE_INITIAL:
		var me := _player_info(snap, viewer)
		can_play = not bool(me.get("placed_initial", false))
	elif phase == GameTypes.Phase.PLACE_OR_BID:
		can_play = String(snap.current_player_id) == viewer
	var can_discard := phase == GameTypes.Phase.CHOOSE_DISCARD and String(snap.challenger_id) == viewer

	var wanted: Dictionary = {}
	for card in snap.you.hand:
		wanted[String(card.id)] = card

	for child in _hand_box.get_children():
		if child.is_queued_for_deletion():
			continue
		if not wanted.has(child.card_id):
			_hand_box.remove_child(child)
			child.queue_free()

	var existing: Dictionary = {}
	for child in _hand_box.get_children():
		if child.is_queued_for_deletion():
			continue
		existing[child.card_id] = child

	var order_index := 0
	for card in snap.you.hand:
		var cid := String(card.id)
		var view
		if existing.has(cid):
			view = existing[cid]
			_hand_box.move_child(view, order_index)
		else:
			view = CardViewScript.new()
			_hand_box.add_child(view)
			_hand_box.move_child(view, order_index)
			view.dropped.connect(_on_card_dropped)
			view.pressed.connect(_on_card_pressed)
		view.setup(cid, bool(card.is_duck), true, can_play or can_discard, can_play)
		view.remember_rest_position()
		order_index += 1


func _update_bid_row(snap: Dictionary, viewer: String) -> void:
	var phase := int(snap.phase)
	var my_turn := String(snap.current_player_id) == viewer
	var show := my_turn and (phase == GameTypes.Phase.PLACE_OR_BID or phase == GameTypes.Phase.BIDDING)
	_bid_row.visible = show
	var max_bid: int = maxi(1, int(snap.cards_in_play))
	if phase == GameTypes.Phase.BIDDING:
		_bid_amount = clampi(maxi(_bid_amount, int(snap.current_bid) + 1), 1, max_bid)
	else:
		_bid_amount = clampi(_bid_amount, 1, max_bid)
	_sync_bid_label()
	_bid_row.get_child(4).visible = phase == GameTypes.Phase.BIDDING # Pass


func _sync_bid_label() -> void:
	_bid_label.text = str(_bid_amount)


func _on_bid_pressed() -> void:
	var snap := _snapshot()
	if int(snap.phase) == GameTypes.Phase.PLACE_OR_BID:
		_submit(GameProtocol.open_bid(_bid_amount))
	else:
		_submit(GameProtocol.raise_bid(_bid_amount))


func _on_card_pressed(card) -> void:
	var snap := _snapshot()
	if int(snap.phase) == GameTypes.Phase.CHOOSE_DISCARD:
		_submit(GameProtocol.choose_discard(card.card_id))


func _on_card_dropped(card, at: Vector2) -> void:
	var snap := _snapshot()
	if int(snap.phase) == GameTypes.Phase.CHOOSE_DISCARD:
		card.snap_home()
		return
	var viewer := _viewer_id()
	var mat = _mats.get(viewer)
	if mat and mat.contains_point(at):
		var result := _submit(GameProtocol.place_card(card.card_id))
		if not result.get("ok", true):
			card.snap_home()
	else:
		card.snap_home()


func _clear(node: Node) -> void:
	for child in node.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.remove_child(child)
		child.queue_free()


func _on_mat_input(event: InputEvent, pid: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var snap := _snapshot()
		if int(snap.phase) == GameTypes.Phase.REVEAL:
			_submit(GameProtocol.flip(pid))
