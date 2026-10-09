extends Control

const GameTypes = preload("res://scripts/rules/types.gd")
const CardScene = preload("res://scenes/card.tscn")
const CardArt = preload("res://scripts/ui/card_art.gd")
const PlayerMatScript = preload("res://scripts/ui/player_mat.gd")
const DiscardFxScript = preload("res://scripts/ui/discard_fx.gd")
const GameProtocol = preload("res://scripts/net/protocol.gd")
const StatusTextScript = preload("res://scripts/ui/status_text.gd")
const DiscardPickScript = preload("res://scripts/ui/discard_pick.gd")
const StampPickerScript = preload("res://scripts/ui/stamp_picker.gd")
const DuckDrawing = preload("res://scripts/ui/duck_drawing.gd")
const DuckStamps = preload("res://scripts/ui/duck_stamps.gd")
const PlayerCosmetics = preload("res://scripts/ui/player_cosmetics.gd")

const SEAT_COLORS := [
	Color("e07a3d"),
	Color("3d9be0"),
	Color("5cb85c"),
	Color("c05ce0"),
	Color("e0c03d"),
	Color("e05c7a"),
]

const PLACE_FLIGHT_SEC := 0.45

var _bid_amount := 1
var _status: Label
var _banner: Label
var _hand_box: HBoxContainer
var _scoreboard: VBoxContainer
var _mats_root: Control
var _drag_canvas: CanvasLayer
var _drag_layer: Control
var _mats: Dictionary = {}
var _bid_row: HBoxContainer
var _bid_label: Label
var _next_round_btn: Button
var _ui_canvas: CanvasLayer
var _error: Label
var _render_queued := false
var _pending_reveal_pid := ""
var _pending_reveal_prev_card_id := ""
var _last_applied_reveal_hist := 0
## Last discard seq handled; -1 until the first snapshot (joining never replays an old discard).
var _last_discard_seq := -1
## Discards waiting for the Duck reveal to finish: [{player_id, seq, card_id, is_duck, view}]
var _discard_queue: Array = []
var _discards_playing := 0
## Centre row while the Duck's owner picks the challenger's discard.
var _pick_row = null
var _stamp_picker = null
## Offer already answered with Done; ignored until the server's snapshot clears it.
var _stamp_sent_offer: Array = []
var _was_acting := false
var _reveal_send_t := -1.0
var _reveal_send_msec := 0
## card_id -> true while flying from mat to hand after Next round
var _flight_pending: Dictionary = {}
## Local placer FX in progress — hide the new stack token until the flip finishes.
var _local_placing_card_id := ""
## Stack slot the placed card will occupy; only that token is hidden during the flight.
var _local_placing_slot := -1
var _local_hand_order: Array = []
var _hand_spacer: Control = null
var _dragging_card = null
## Card mid local place flight/flip — must not be freed by hand layout.
var _placing_card = null
var _last_reorder_idx := -1

const REVEAL_SEND_MS := 80
const REVEAL_SEND_MIN_DT := 0.05
const RETURN_FLIGHT_SEC := 0.45
const TABLE_SHAKE_SEC := 0.45
const TABLE_SHAKE_PX := 10.0
## Discarded cards fly to screen centre at this scale before being destroyed.
const DISCARD_PRESENT_SCALE := 1.7
## Temporary: in-game panel to preview every discard style.
const DISCARD_DEMO := true

var _shake_tween: Tween
var _shake_base: Array = []


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_build_chrome()
	Net.match_updated.connect(_on_net_update)
	if not Net.notice.is_connected(_on_net_notice):
		Net.notice.connect(_on_net_notice)
	if not Net.reveal_progress.is_connected(_on_remote_reveal_progress):
		Net.reveal_progress.connect(_on_remote_reveal_progress)
	if not Net.reveal_cancel.is_connected(_on_remote_reveal_cancel):
		Net.reveal_cancel.connect(_on_remote_reveal_cancel)
	if not Net.discard_hover.is_connected(_on_remote_discard_hover):
		Net.discard_hover.connect(_on_remote_discard_hover)
	_queue_render()


func _on_net_notice(msg: String) -> void:
	if _error:
		_error.text = msg


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
	_hand_box.position = Vector2(280, 560)
	_hand_box.size = Vector2(720, 150)
	_hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_hand_box)

	# Bottom-right, growing up/left as rows are added; clear of the hand (ends x 1000).
	var board_panel := PanelContainer.new()
	var board_sb := StyleBoxFlat.new()
	board_sb.bg_color = Color(0, 0, 0, 0.28)
	board_sb.set_corner_radius_all(8)
	board_sb.set_content_margin_all(8)
	board_panel.add_theme_stylebox_override("panel", board_sb)
	board_panel.custom_minimum_size = Vector2(220, 0)
	board_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board_panel)
	board_panel.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT, PRESET_MODE_MINSIZE, 12)
	board_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	board_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_scoreboard = VBoxContainer.new()
	_scoreboard.add_theme_constant_override("separation", 4)
	board_panel.add_child(_scoreboard)

	# Separate canvas layer so dragged cards always paint above mats/hand/UI.
	_drag_canvas = CanvasLayer.new()
	_drag_canvas.layer = 100
	add_child(_drag_canvas)
	_drag_layer = Control.new()
	_drag_layer.set_anchors_preset(PRESET_FULL_RECT)
	_drag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_canvas.add_child(_drag_layer)

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

	# Above the drag canvas so the host always sees it when a round ends.
	_ui_canvas = CanvasLayer.new()
	_ui_canvas.layer = 200
	add_child(_ui_canvas)
	_next_round_btn = Button.new()
	_next_round_btn.text = "Next round"
	_next_round_btn.visible = false
	_next_round_btn.custom_minimum_size = Vector2(220, 56)
	_next_round_btn.add_theme_font_size_override("font_size", 22)
	_next_round_btn.pressed.connect(_on_next_round_pressed)
	_ui_canvas.add_child(_next_round_btn)
	# Own layer so the centre pick row (added to _ui_canvas later) never paints over it.
	var stamp_canvas := CanvasLayer.new()
	stamp_canvas.layer = 250
	add_child(stamp_canvas)
	_stamp_picker = StampPickerScript.new()
	_stamp_picker.finished.connect(_on_stamp_finished)
	stamp_canvas.add_child(_stamp_picker)
	# if DISCARD_DEMO:
	# 	_build_discard_demo()

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
	CardArt.set_players(snap.get("players", []))
	# Resolve reveal face on the pre-rebuild top token, then layout (stack count drops).
	# Before the status/banner so a deciding flip holds the result text this same frame.
	_apply_new_reveal(snap)
	_apply_new_discard(snap, viewer)
	if not _discard_queue.is_empty() and _reveals_in_flight() == 0:
		_flush_discards()
	_status.text = _status_text(snap, viewer)
	_banner.text = _banner_text(snap)
	_layout_mats(snap, viewer)
	_sync_pick_row(snap, viewer)
	_update_scoreboard(snap)
	_hide_local_placing_stack_token()
	var flight_nodes := _take_parked_if_new_hand(snap)
	_mark_flight_pending(flight_nodes, viewer)
	_layout_hand(snap)
	if not flight_nodes.is_empty():
		call_deferred("_start_return_flights", flight_nodes, viewer)
	_sync_parked_reveals(snap)
	_update_bid_row(snap, viewer)
	_update_next_round_btn(snap)
	_sync_stamp_picker(snap, viewer)


## Duck upgrade overlay for the Duck's owner: opens once the destroy FX is done, never blocks
## play, and gets out of the way whenever it's this player's move.
func _sync_stamp_picker(snap: Dictionary, viewer: String) -> void:
	var offer: Array = snap.get("you", {}).get("upgrade_offer", [])
	if offer.is_empty():
		_stamp_sent_offer = []
		if _stamp_picker.is_active():
			_stamp_picker.close()
	elif offer != _stamp_sent_offer and not _stamp_picker.is_active() \
			and _discards_in_flight() == 0 and _reveals_in_flight() == 0:
		var duck := DuckDrawing.load_local()
		_stamp_picker.open(offer, duck if duck != null else DuckDrawing.default_image())
	var acting := _viewer_must_act(snap, viewer)
	if acting and not _was_acting:
		_stamp_picker.minimise()
	_was_acting = acting


func _viewer_must_act(snap: Dictionary, viewer: String) -> bool:
	match int(snap.get("phase", -1)):
		GameTypes.Phase.PLACE_INITIAL:
			var me := _player_info(snap, viewer)
			return not me.is_empty() and not bool(me.get("placed_initial", true)) and not bool(me.get("eliminated", false))
		GameTypes.Phase.PLACE_OR_BID, GameTypes.Phase.BIDDING, GameTypes.Phase.REVEAL:
			return String(snap.get("current_player_id", "")) == viewer
		GameTypes.Phase.CHOOSE_DISCARD:
			return String(snap.get("discard_chooser_id", "")) == viewer
	return false


func _on_stamp_finished(stamp_id: String, img: Image) -> void:
	_stamp_sent_offer = _snapshot().get("you", {}).get("upgrade_offer", []).duplicate()
	DuckDrawing.save_local(img)
	var progress := PlayerCosmetics.load_progress()
	DuckStamps.apply_stamp(progress, stamp_id)
	PlayerCosmetics.save_progress(progress)
	Net.apply_duck_upgrade(stamp_id, DuckDrawing.encode(img), progress)


func _reveals_in_flight() -> int:
	var n := 0
	for mat in _mats.values():
		if is_instance_valid(mat):
			n += mat.reveals_in_flight()
	return n


func _discards_in_flight() -> int:
	return _discard_queue.size() + _discards_playing


## Round/game result waits until the deciding flip and any discard have finished animating.
func _holding_result(snap: Dictionary) -> bool:
	var phase := int(snap.get("phase", -1))
	if phase != GameTypes.Phase.ROUND_OVER and phase != GameTypes.Phase.GAME_OVER:
		return false
	return _reveals_in_flight() > 0 or _discards_in_flight() > 0


## New permanent discard in the snapshot: queue/play its destroy FX. Only the loser's snapshot
## carries card_id, so only they see the face; everyone else gets the loser's back.
func _apply_new_discard(snap: Dictionary, viewer: String) -> void:
	var ev: Dictionary = snap.get("last_discard", {})
	var seq := int(ev.get("seq", 0))
	if _last_discard_seq < 0 or seq < _last_discard_seq:
		_last_discard_seq = seq
		return
	if seq == _last_discard_seq:
		return
	_last_discard_seq = seq
	var job := {
		player_id = String(ev.get("player_id", "")),
		seq = seq,
		card_id = String(ev.get("card_id", "")),
		is_duck = bool(ev.get("is_duck", false)),
		style = String(ev.get("style", "rip")),
		view = null,
	}
	var slot := int(ev.get("slot", -1))
	if slot >= 0 and _pick_row != null:
		var picked = _pick_row.take(slot)
		if picked:
			picked.reparent(_drag_layer, true)
			picked.set_meta("discard_fx", true)
			job.view = picked
	elif job.player_id == viewer and job.card_id != "":
		var view = _find_hand_card(job.card_id)
		if view:
			# Off the hand now so the rebuild can't free it; stays visible until the FX starts.
			view.reparent(_drag_layer, true)
			view.set_meta("discard_fx", true)
			view.interactable = false
			view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			job.view = view
	if _reveals_in_flight() > 0:
		_discard_queue.append(job)
	else:
		_start_discard(job)


func _flush_discards() -> void:
	var jobs := _discard_queue.duplicate()
	_discard_queue.clear()
	for job in jobs:
		_start_discard(job)


func _start_discard(job: Dictionary) -> void:
	_discards_playing += 1
	var view = job.view
	var tex: Texture2D
	var center: Vector2
	var sc := PlayerMatScript.TOKEN_SCALE
	if view != null and is_instance_valid(view):
		var owner_id := String(view.owner_id) if String(view.owner_id) != "" else String(job.player_id)
		tex = CardArt.face_texture(owner_id, bool(job.is_duck)) if job.card_id != "" else CardArt.back_texture(owner_id)
		var xf: Transform2D = view.get_global_transform()
		center = xf * (CardView.SIZE * 0.5)
		sc = xf.get_scale().x
		view.visible = false
	else:
		view = null
		tex = CardArt.face_texture(job.player_id, bool(job.is_duck)) if job.card_id != "" else CardArt.back_texture(job.player_id)
		var mat = _mats.get(job.player_id)
		center = mat.global_position + PlayerMatScript.MAT_SIZE * 0.5 if mat else get_viewport_rect().size * 0.5
	var fx = DiscardFxScript.play(
		_drag_layer, tex, center, sc, job.style, hash("%s|%d" % [job.player_id, job.seq]),
		get_viewport_rect().size * 0.5, DISCARD_PRESENT_SCALE
	)
	fx.finished.connect(_on_discard_finished.bind(view))


## Temporary (DISCARD_DEMO): one button per discard style, local only.
func _build_discard_demo() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var lbl := Label.new()
	lbl.text = "FX demo (temp):"
	lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(lbl)
	for style in DiscardFxScript.STYLES + ["random"]:
		var b := Button.new()
		b.text = String(style).capitalize()
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(_play_discard_demo.bind(style))
		row.add_child(b)
	_ui_canvas.add_child(row)
	row.position = Vector2(1250.0 - row.get_combined_minimum_size().x, 54)


## Fly your first hand card's look (it stays in hand) to centre and destroy it.
func _play_discard_demo(style: String) -> void:
	if style == "random":
		style = DiscardFxScript.STYLES[randi() % DiscardFxScript.STYLES.size()]
	var vp := get_viewport_rect().size
	var src := Vector2(vp.x * 0.5, vp.y - 80.0)
	var sc := 1.0
	var tex: Texture2D = CardArt.face_texture(_viewer_id(), true)
	for child in _hand_box.get_children():
		if child == _hand_spacer or child.is_queued_for_deletion() or child.get("card_id") == null:
			continue
		tex = CardArt.face_texture(String(child.owner_id), bool(child.is_duck))
		var xf: Transform2D = child.get_global_transform()
		src = xf * (CardView.SIZE * 0.5)
		sc = xf.get_scale().x
		break
	DiscardFxScript.play(_drag_layer, tex, src, sc, style, randi(), vp * 0.5, DISCARD_PRESENT_SCALE)


func _on_discard_finished(_fx, view) -> void:
	_discards_playing = maxi(_discards_playing - 1, 0)
	if view != null and is_instance_valid(view):
		view.queue_free()
	_queue_render()


func _flip_line(snap: Dictionary) -> String:
	var hist: Array = snap.get("flip_history", [])
	if hist.is_empty():
		return ""
	var last: Dictionary = hist[hist.size() - 1]
	if last.is_duck:
		return "A DUCK! Challenge failed."
	if int(snap.get("flips_remaining", 0)) > 0:
		return "Safe. %s left to flip." % snap.flips_remaining
	return "Safe!"


func _on_reveal_sequence_started(_mat) -> void:
	_queue_render()


func _on_reveal_sequence_finished(_mat) -> void:
	if not _discard_queue.is_empty() and _reveals_in_flight() == 0:
		_flush_discards()
	_queue_render()


func _on_duck_presented(_mat, card) -> void:
	_shake_table()
	if is_instance_valid(card):
		_burst_mini_ducks(card.get_global_transform() * (CardView.SIZE * 0.5), String(card.owner_id))


func _shake_table() -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
		_apply_table_shake(0.0)
	_shake_base = [_mats_root.position, _hand_box.position]
	_shake_tween = create_tween()
	_shake_tween.tween_method(_apply_table_shake, 1.0, 0.0, TABLE_SHAKE_SEC)


func _apply_table_shake(k: float) -> void:
	if _shake_base.size() < 2:
		return
	var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * TABLE_SHAKE_PX * k
	_mats_root.position = _shake_base[0] + off
	_hand_box.position = _shake_base[1] + off


## One-shot burst of tiny copies of the owner's duck drawing, above everything.
func _burst_mini_ducks(at: Vector2, owner_id: String) -> void:
	var p := CPUParticles2D.new()
	p.texture = CardArt.mini_duck_texture(owner_id)
	p.position = at
	p.amount = 30
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 1.4
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 160.0
	p.initial_velocity_max = 320.0
	p.gravity = Vector2(0, 260)
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 0.45
	p.scale_amount_max = 0.9
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.7, Color.WHITE)
	p.color_ramp = fade
	_ui_canvas.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)


func _status_text(snap: Dictionary, viewer: String) -> String:
	if _holding_result(snap):
		return "Revealing…" if _reveals_in_flight() > 0 else "Discarding…"
	return StatusTextScript.for_viewer(snap, viewer)


func _banner_text(snap: Dictionary) -> String:
	if int(snap.phase) == GameTypes.Phase.GAME_OVER and not _holding_result(snap):
		var winner := _player_name(snap, String(snap.winner_id))
		return "%s wins!" % winner
	if _discards_in_flight() > 0 and _reveals_in_flight() == 0:
		var loser := String(snap.get("last_discard", {}).get("player_id", ""))
		return "%s loses a card!" % _player_name(snap, loser)
	return _flip_line(snap)


func _player_name(snap: Dictionary, pid: String) -> String:
	for p in snap.players:
		if p.id == pid:
			return String(p.name)
	return pid


func _layout_mats(snap: Dictionary, viewer: String) -> void:
	var ids: Array = []
	for p in snap.players:
		ids.append(String(p.id))
	if viewer in ids:
		while String(ids[0]) != viewer:
			ids.append(ids.pop_front())
	var wanted: Dictionary = {}
	for pid in ids:
		wanted[pid] = true
	for pid in _mats.keys():
		if not wanted.has(pid):
			var old = _mats[pid]
			_mats.erase(pid)
			if is_instance_valid(old):
				old.queue_free()
	var n := ids.size()
	var seats := PlayerMatScript.seat_layout(n)
	var phase := int(snap.phase)
	var challenger := String(snap.get("challenger_id", ""))
	var own_stack_left := 0
	var me := _player_info(snap, viewer)
	if not me.is_empty():
		own_stack_left = int(me.get("stack_count", 0))
	for i in n:
		var pid: String = String(ids[i])
		var info := _player_info(snap, pid)
		var mat
		if _mats.has(pid) and is_instance_valid(_mats[pid]):
			mat = _mats[pid]
		else:
			mat = PlayerMatScript.new()
			_mats_root.add_child(mat)
			mat.setup(pid, SEAT_COLORS[i % SEAT_COLORS.size()])
			mat.stack_top_reveal_released.connect(_on_stack_reveal_released)
			mat.stack_top_reveal_scrub.connect(_on_stack_reveal_scrub)
			mat.reveal_sequence_started.connect(_on_reveal_sequence_started)
			mat.reveal_sequence_finished.connect(_on_reveal_sequence_finished)
			mat.duck_presented.connect(_on_duck_presented)
			_mats[pid] = mat
		mat.position = seats[i].pos
		mat.reveal_dir = seats[i].dir
		var top_revealable := false
		if phase == GameTypes.Phase.REVEAL and challenger == viewer:
			if own_stack_left > 0:
				top_revealable = pid == viewer and int(info.stack_count) > 0
			else:
				top_revealable = pid != viewer and int(info.stack_count) > 0
		mat.refresh(info, top_revealable)


## Duck-owner pick: show the challenger's shuffled cards at centre once the Duck reveal lands.
func _sync_pick_row(snap: Dictionary, viewer: String) -> void:
	var slots := int(snap.get("discard_slots", 0))
	var key := ""
	if int(snap.phase) == GameTypes.Phase.CHOOSE_DISCARD and slots > 0 and _reveals_in_flight() == 0:
		key = "%s|%s|%d" % [snap.challenger_id, snap.discard_chooser_id, slots]
	if _pick_row != null and _pick_row.key != key:
		_pick_row.queue_free()
		_pick_row = null
	if key != "" and _pick_row == null:
		_pick_row = DiscardPickScript.new()
		_pick_row.key = key
		_drag_layer.add_child(_pick_row)
		_pick_row.build(snap, viewer)
		_pick_row.hovered.connect(Net.send_discard_hover)
		_pick_row.picked.connect(func(slot: int): _submit(GameProtocol.pick_discard(slot)))
	# The challenger's cards are in the row; don't show them twice.
	_hand_box.visible = not (_pick_row != null and String(snap.challenger_id) == viewer)


func _on_remote_discard_hover(slot: int) -> void:
	if _pick_row != null:
		_pick_row.set_remote_hover(slot)


func _update_scoreboard(snap: Dictionary) -> void:
	_clear(_scoreboard)
	for p in snap.players:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var back := TextureRect.new()
		back.texture = CardArt.back_texture(String(p.id))
		back.custom_minimum_size = Vector2(18, 24)
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(back)
		var nm := Label.new()
		nm.text = String(p.name)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		nm.add_theme_font_size_override("font_size", 15)
		row.add_child(nm)
		var pts := Label.new()
		pts.text = str(p.points)
		pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pts.add_theme_font_size_override("font_size", 15)
		row.add_child(pts)
		_scoreboard.add_child(row)


func _player_info(snap: Dictionary, pid: String) -> Dictionary:
	for p in snap.players:
		if p.id == pid:
			return p
	return {}


func _layout_hand(snap: Dictionary) -> void:
	if not snap.has("you"):
		_clear(_hand_box)
		_local_hand_order.clear()
		_clear_hand_spacer()
		return
	var phase := int(snap.phase)
	var viewer := _viewer_id()
	var can_play := false
	if phase == GameTypes.Phase.PLACE_INITIAL:
		var me := _player_info(snap, viewer)
		can_play = not bool(me.get("placed_initial", false))
	elif phase == GameTypes.Phase.PLACE_OR_BID:
		can_play = String(snap.current_player_id) == viewer
	var can_discard := phase == GameTypes.Phase.CHOOSE_DISCARD and String(snap.challenger_id) == viewer and int(snap.get("discard_slots", 0)) == 0

	var wanted: Dictionary = {}
	for card in snap.you.hand:
		wanted[String(card.id)] = card

	# Drop ids that left the hand; append newly dealt ids.
	var next_order: Array = []
	for cid in _local_hand_order:
		if wanted.has(String(cid)):
			next_order.append(String(cid))
	for card in snap.you.hand:
		var cid := String(card.id)
		if cid not in next_order:
			next_order.append(cid)
	_local_hand_order = next_order

	for child in _hand_box.get_children():
		if child.is_queued_for_deletion():
			continue
		if child == _hand_spacer:
			continue
		if not wanted.has(child.card_id):
			_hand_box.remove_child(child)
			child.queue_free()

	if _drag_layer:
		for child in _drag_layer.get_children():
			if child.is_queued_for_deletion():
				continue
			if child == _dragging_card or child == _placing_card:
				continue
			if child.has_meta("local_place_fx") or child.has_meta("discard_fx"):
				continue
			if child.has_meta("parked_reveal") or child.has_meta("linger_reveal") or child.has_meta("reveal_card_id"):
				continue
			if child.get("card_id") != null and not wanted.has(String(child.card_id)):
				_drag_layer.remove_child(child)
				child.queue_free()

	var existing: Dictionary = {}
	for child in _hand_box.get_children():
		if child.is_queued_for_deletion() or child == _hand_spacer:
			continue
		existing[child.card_id] = child

	var order_index := 0
	for cid_v in _local_hand_order:
		var cid := String(cid_v)
		if not wanted.has(cid):
			continue
		# Dragged / placing card lives on the drag layer — don't spawn a duplicate in hand.
		if _dragging_card != null and is_instance_valid(_dragging_card) and String(_dragging_card.card_id) == cid:
			continue
		if _placing_card != null and is_instance_valid(_placing_card) and String(_placing_card.card_id) == cid:
			continue
		var card: Dictionary = wanted[cid]
		var view
		if existing.has(cid):
			view = existing[cid]
			_hand_box.move_child(view, order_index)
			view.set_drag_layer(_drag_layer)
		else:
			view = CardScene.instantiate()
			_hand_box.add_child(view)
			_hand_box.move_child(view, order_index)
			view.set_drag_layer(_drag_layer)
			view.dropped.connect(_on_card_dropped)
			view.pressed.connect(_on_card_pressed)
			view.drag_started.connect(_on_card_drag_started)
			if _flight_pending.has(cid):
				view.modulate.a = 0.0
				view.mouse_filter = Control.MOUSE_FILTER_IGNORE
				view.set_meta("awaiting_flight", true)
		view.setup(cid, bool(card.is_duck), true, can_play or can_discard, can_play, String(card.get("owner_id", _viewer_id())))
		view.remember_rest_position()
		if _flight_pending.has(cid):
			view.modulate.a = 0.0
			view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			view.set_meta("awaiting_flight", true)
		order_index += 1

	# Keep spacer at the drag insert slot if still dragging.
	if _hand_spacer != null and is_instance_valid(_hand_spacer) and _dragging_card != null:
		_hand_box.move_child(_hand_spacer, clampi(_last_reorder_idx, 0, _hand_box.get_child_count() - 1))

	_idle_hand_not_under_mouse()


func _idle_hand_not_under_mouse() -> void:
	var mouse := get_global_mouse_position()
	for child in _hand_box.get_children():
		if child == _hand_spacer or child.is_queued_for_deletion():
			continue
		if not child.has_method("force_idle"):
			continue
		if child.get_global_rect().has_point(mouse):
			continue
		child.force_idle()


func _force_idle_hand(except = null) -> void:
	for child in _hand_box.get_children():
		if child == _hand_spacer or child == except:
			continue
		if child.has_method("force_idle"):
			child.force_idle()


func _on_card_drag_started(card) -> void:
	_dragging_card = card
	_last_reorder_idx = card.get_hand_index()
	_force_idle_hand(card)
	_ensure_hand_spacer(card.get_hand_index())


func _ensure_hand_spacer(at_index: int) -> void:
	_clear_hand_spacer()
	_hand_spacer = Control.new()
	_hand_spacer.custom_minimum_size = Vector2(96, 128)
	_hand_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand_box.add_child(_hand_spacer)
	_hand_box.move_child(_hand_spacer, clampi(at_index, 0, _hand_box.get_child_count() - 1))


func _clear_hand_spacer() -> void:
	if _hand_spacer != null and is_instance_valid(_hand_spacer):
		_hand_spacer.queue_free()
	_hand_spacer = null


func _process(_delta: float) -> void:
	if _dragging_card == null or not is_instance_valid(_dragging_card):
		_dragging_card = null
		return
	if not _dragging_card.is_dragging():
		# Card ended drag this frame via its own _process; drop handler clears state.
		return
	_reorder_hand_while_dragging(_dragging_card)


func _reorder_hand_while_dragging(card) -> void:
	if _hand_spacer == null or not is_instance_valid(_hand_spacer):
		return
	var mouse := get_global_mouse_position()
	if not _hand_box.get_global_rect().grow(24).has_point(mouse):
		return
	_hand_box.remove_child(_hand_spacer)
	var target := 0
	for child in _hand_box.get_children():
		var mid: float = child.global_position.x + child.size.x * 0.5
		if mouse.x < mid:
			break
		target += 1
	if target == _last_reorder_idx:
		_hand_box.add_child(_hand_spacer)
		_hand_box.move_child(_hand_spacer, clampi(target, 0, _hand_box.get_child_count() - 1))
		return
	var displaced = null
	if target < _hand_box.get_child_count():
		displaced = _hand_box.get_child(clampi(target, 0, _hand_box.get_child_count() - 1))
	elif _hand_box.get_child_count() > 0 and target > _last_reorder_idx:
		displaced = _hand_box.get_child(_hand_box.get_child_count() - 1)
	_hand_box.add_child(_hand_spacer)
	_hand_box.move_child(_hand_spacer, clampi(target, 0, _hand_box.get_child_count() - 1))
	_last_reorder_idx = target
	card.set_hand_index(_hand_spacer.get_index())
	if displaced != null and displaced.has_method("play_quiver"):
		displaced.play_quiver()


func _hand_insert_index_for_x(mouse_x: float) -> int:
	var idx := 0
	for child in _hand_box.get_children():
		if child == _hand_spacer:
			continue
		var mid: float = child.global_position.x + child.size.x * 0.5
		if mouse_x < mid:
			return idx
		idx += 1
	return idx


func _sync_local_order_from_hand() -> void:
	_local_hand_order.clear()
	for child in _hand_box.get_children():
		if child == _hand_spacer:
			continue
		if child.get("card_id") != null and String(child.card_id) != "":
			_local_hand_order.append(String(child.card_id))


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


func _update_next_round_btn(snap: Dictionary) -> void:
	if _next_round_btn == null:
		return
	# Prefer phase_name so int enum drift between client/server can't hide the button.
	var phase_name := String(snap.get("phase_name", ""))
	if phase_name == "":
		var phase := int(snap.get("phase", -1))
		if phase >= 0 and phase < GameTypes.Phase.size():
			phase_name = String(GameTypes.Phase.keys()[phase])
	var show := phase_name == "ROUND_OVER" and not _holding_result(snap) and bool(snap.get("you_are_host", true))
	_next_round_btn.visible = show
	if not show:
		return
	if snap.has("you_are_host"):
		Net.is_host = bool(snap.you_are_host)
	var vp := get_viewport_rect().size
	_next_round_btn.custom_minimum_size = Vector2(280, 64)
	_next_round_btn.size = Vector2(280, 64)
	var btn_h := 64.0
	var y := clampf(vp.y * 0.15, 12.0, maxf(12.0, vp.y - btn_h - 12.0))
	_next_round_btn.position = Vector2((vp.x - 280.0) * 0.5, y)
	_next_round_btn.disabled = false
	_next_round_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_next_round_btn.text = "Next round"
	_next_round_btn.tooltip_text = "Start the next hand"


func _on_next_round_pressed() -> void:
	var snap := _snapshot()
	if snap.has("you_are_host"):
		Net.is_host = bool(snap.you_are_host)
	_error.text = "Starting next round…"
	_submit(GameProtocol.next_round())


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
	var insert_at := 0
	if _hand_spacer != null and is_instance_valid(_hand_spacer):
		insert_at = _hand_spacer.get_index()
	_clear_hand_spacer()
	_dragging_card = null
	_last_reorder_idx = -1

	if int(snap.phase) == GameTypes.Phase.CHOOSE_DISCARD:
		card.return_to_hand(insert_at)
		_sync_local_order_from_hand()
		_force_idle_hand()
		return
	var viewer := _viewer_id()
	var mat = _mats.get(viewer)
	if mat and mat.contains_point(at):
		_submit(GameProtocol.place_card(card.card_id))
		# Keep alive across snapshot hand layout (drag_layer used to free this card).
		_placing_card = card
		card.set_meta("local_place_fx", true)
		# Don't drop top_level — keep painting above mats during flight.
		card.top_level = true
		card.z_as_relative = false
		card.z_index = 4096
		card.visible = true
		_play_local_place(card, mat)
		_force_idle_hand()
	else:
		card.return_to_hand(insert_at)
		_sync_local_order_from_hand()
		_force_idle_hand()


## Placer-only place FX. Other clients never call this.
func _play_local_place(card, mat) -> void:
	if card == null or not is_instance_valid(card):
		return
	_local_placing_card_id = String(card.card_id)
	_local_placing_slot = mat.stack_size() if mat and mat.has_method("stack_size") else -1
	var target := Vector2.ZERO
	if mat and mat.has_method("next_stack_slot_global"):
		target = mat.next_stack_slot_global()
	else:
		target = card.global_position
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.interactable = false
	card.drag_enabled = false
	card.top_level = true
	card.z_as_relative = false
	card.z_index = 4096
	if card.has_signal("place_flip_finished"):
		if not card.place_flip_finished.is_connected(_on_local_place_flip_finished):
			card.place_flip_finished.connect(_on_local_place_flip_finished, CONNECT_ONE_SHOT)
	if card.has_method("play_flip_to_face_down"):
		card.play_flip_to_face_down()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(card, "global_position", target, PLACE_FLIGHT_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var token_scale := Vector2(PlayerMatScript.TOKEN_SCALE, PlayerMatScript.TOKEN_SCALE)
	tw.tween_property(card, "scale", token_scale, PLACE_FLIGHT_SEC)
	# Hide the snapshot stack token if it already spawned this frame.
	_hide_local_placing_stack_token()


func _hide_local_placing_stack_token() -> void:
	if _local_placing_card_id == "" or _local_placing_slot < 0:
		return
	var mat = _mats.get(_viewer_id())
	if mat == null or not mat.has_method("stack_token"):
		return
	# Until the snapshot appends it, this slot is empty; never hide earlier tokens.
	var token = mat.stack_token(_local_placing_slot)
	if token == null:
		return
	token.visible = false
	token.set_meta("awaiting_place_fx", true)


func _on_local_place_flip_finished(card) -> void:
	_local_placing_card_id = ""
	_local_placing_slot = -1
	if _placing_card == card:
		_placing_card = null
	var mat = _mats.get(_viewer_id())
	if mat and mat.has_method("stack_token"):
		for i in mat.stack_size():
			var token = mat.stack_token(i)
			if token and token.has_meta("awaiting_place_fx"):
				token.visible = true
				token.remove_meta("awaiting_place_fx")
				if token.has_method("juice"):
					token.juice()
	if card == null or not is_instance_valid(card):
		return
	if card.has_meta("local_place_fx"):
		card.remove_meta("local_place_fx")
	if card.has_method("hide_after_place"):
		card.hide_after_place()
	else:
		card.visible = false
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _clear(node: Node) -> void:
	for child in node.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.remove_child(child)
		child.queue_free()


func _on_stack_reveal_scrub(mat, _card, t: float) -> void:
	var snap := _snapshot()
	if int(snap.phase) != GameTypes.Phase.REVEAL:
		return
	if String(snap.get("challenger_id", "")) != _viewer_id():
		return
	_maybe_send_reveal_progress(String(mat.player_id), t)


func _maybe_send_reveal_progress(target_player_id: String, t: float) -> void:
	var now := Time.get_ticks_msec()
	var dt := absf(t - _reveal_send_t)
	if _reveal_send_t >= 0.0 and dt < REVEAL_SEND_MIN_DT and (now - _reveal_send_msec) < REVEAL_SEND_MS:
		return
	_reveal_send_t = t
	_reveal_send_msec = now
	Net.send_reveal_progress(target_player_id, t)


func _on_stack_reveal_released(mat, card, t: float) -> void:
	var snap := _snapshot()
	if int(snap.phase) != GameTypes.Phase.REVEAL:
		if card and card.has_method("abort_flip"):
			card.abort_flip()
		_reveal_send_t = -1.0
		return
	# t is scrub-window progress 0..1 (1.0 == Card_Flip at SCRUB_END_SEC).
	if t < 1.0:
		if card and card.has_method("abort_flip"):
			card.abort_flip()
		Net.send_reveal_cancel(String(mat.player_id))
		_reveal_send_t = -1.0
		return
	# Flush a last progress near commit so remotes aren't stuck mid-tilt.
	Net.send_reveal_progress(String(mat.player_id), t)
	_reveal_send_t = -1.0
	_pending_reveal_pid = String(mat.player_id)
	var prev: Dictionary = snap.get("last_revealed", {})
	_pending_reveal_prev_card_id = String(prev.get("card_id", ""))
	_submit(GameProtocol.flip(_pending_reveal_pid))


func _on_remote_reveal_progress(target_player_id: String, t: float) -> void:
	var snap := _snapshot()
	if int(snap.phase) != GameTypes.Phase.REVEAL:
		return
	var mat = _mats.get(target_player_id)
	if mat and mat.has_method("apply_remote_scrub"):
		mat.apply_remote_scrub(t)


func _on_remote_reveal_cancel(target_player_id: String) -> void:
	var mat = _mats.get(target_player_id)
	if mat and mat.has_method("apply_remote_cancel"):
		mat.apply_remote_cancel()


func _apply_new_reveal(snap: Dictionary) -> void:
	var hist: Array = snap.get("flip_history", [])
	var hist_size := hist.size()
	if hist_size == 0:
		_last_applied_reveal_hist = 0
		return
	if hist_size <= _last_applied_reveal_hist:
		return
	var revealed: Dictionary = snap.get("last_revealed", {})
	if revealed.is_empty():
		return
	var card_id := String(revealed.get("card_id", ""))
	# Challenger may still be waiting on their pending flip; ignore stale snapshots.
	if _pending_reveal_pid != "":
		if String(revealed.get("target_player_id", "")) != _pending_reveal_pid:
			return
		if card_id == _pending_reveal_prev_card_id:
			return
	var target := String(revealed.get("target_player_id", ""))
	# This card's index among the target's flips = earlier flips of the same mat.
	var reveal_index := 0
	for i in hist_size - 1:
		if String(hist[i].get("target_player_id", "")) == target:
			reveal_index += 1
	var mat = _mats.get(target)
	if mat and mat.has_method("apply_revealed_to_top"):
		mat.apply_revealed_to_top(bool(revealed.get("is_duck", false)), card_id, reveal_index)
	_last_applied_reveal_hist = hist_size
	_pending_reveal_pid = ""
	_pending_reveal_prev_card_id = ""


func _sync_parked_reveals(snap: Dictionary) -> void:
	var phase := int(snap.get("phase", -1))
	var hist: Array = snap.get("flip_history", [])
	if phase == GameTypes.Phase.PLACE_INITIAL or hist.is_empty():
		# Flights own the nodes; only clear leftovers that weren't taken.
		for mat in _mats.values():
			if mat and mat.has_method("clear_parked_reveals"):
				mat.clear_parked_reveals()
		return
	# Only the loser's snapshot names the destroyed card, so only their mat drops it.
	var destroyed := String(snap.get("last_discard", {}).get("card_id", ""))
	# Group history by target mat.
	var by_target: Dictionary = {}
	for e in hist:
		if destroyed != "" and String(e.get("card_id", "")) == destroyed:
			continue
		var tid := String(e.get("target_player_id", e.get("owner_id", "")))
		if not by_target.has(tid):
			by_target[tid] = []
		by_target[tid].append(e)
	for pid in _mats.keys():
		var mat = _mats[pid]
		if mat == null or not mat.has_method("sync_parked_reveals"):
			continue
		mat.sync_parked_reveals(by_target.get(pid, []))


## Pull parked reveals off mats when a new hand starts (for return flights).
func _take_parked_if_new_hand(snap: Dictionary) -> Array:
	var phase := int(snap.get("phase", -1))
	if phase != GameTypes.Phase.PLACE_INITIAL:
		return []
	var out: Array = []
	for mat in _mats.values():
		if mat == null or not mat.has_method("take_parked_reveals"):
			continue
		var nodes: Array = mat.take_parked_reveals()
		for n in nodes:
			if not is_instance_valid(n):
				continue
			# Reparent off the mat immediately so clear_parked won't free them.
			var gp: Vector2 = n.global_position
			var sc: Vector2 = n.scale
			if n.get_parent():
				n.get_parent().remove_child(n)
			if _drag_layer:
				_drag_layer.add_child(n)
			else:
				add_child(n)
			n.top_level = true
			n.global_position = gp
			n.scale = sc
			n.z_index = 50
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
			out.append(n)
	return out


func _reveal_owner_of(node: Node) -> String:
	var owner_id := String(node.get_meta("reveal_owner_id", ""))
	if owner_id != "":
		return owner_id
	if node.get("owner_id") != null and String(node.owner_id) != "":
		return String(node.owner_id)
	var cid := String(node.get_meta("reveal_card_id", ""))
	if cid == "" and node.get("card_id") != null:
		cid = String(node.card_id)
	var us := cid.find("_")
	if us > 0:
		return cid.substr(0, us)
	return ""


func _mark_flight_pending(nodes: Array, viewer: String) -> void:
	for node in nodes:
		if not is_instance_valid(node):
			continue
		var cid := String(node.get_meta("reveal_card_id", ""))
		if cid == "" and node.get("card_id") != null:
			cid = String(node.card_id)
		if cid == "":
			continue
		if _reveal_owner_of(node) == viewer:
			_flight_pending[cid] = true


func _start_return_flights(nodes: Array, viewer: String) -> void:
	if nodes.is_empty():
		return
	if _drag_layer == null:
		for n in nodes:
			if is_instance_valid(n):
				n.queue_free()
		_flight_pending.clear()
		return
	# Layout may have run before flyers moved; refresh dest after one frame if needed.
	for node in nodes:
		if not is_instance_valid(node):
			continue
		var cid := String(node.get_meta("reveal_card_id", ""))
		if cid == "" and node.get("card_id") != null:
			cid = String(node.card_id)
		var owner_id := _reveal_owner_of(node)
		# Already on drag layer from take; keep current transform as start.
		var start_gp: Vector2 = node.global_position
		node.z_index = 50
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var dest := start_gp
		var to_hand := owner_id == viewer and cid != ""
		if to_hand:
			var hand_view = _find_hand_card(cid)
			if hand_view:
				dest = hand_view.global_position
			else:
				dest = _hand_box.global_position + _hand_box.size * 0.5 - Vector2(48, 64)
		else:
			var mat = _mats.get(owner_id)
			if mat:
				dest = mat.global_position + Vector2(mat.size.x * 0.5 - 36, mat.size.y * 0.55)

		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(node, "global_position", dest, RETURN_FLIGHT_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		if to_hand:
			tw.tween_property(node, "scale", Vector2.ONE, RETURN_FLIGHT_SEC)
		else:
			tw.tween_property(node, "modulate:a", 0.0, RETURN_FLIGHT_SEC)
		tw.set_parallel(false)
		tw.tween_callback(_on_return_flight_done.bind(node, cid, to_hand))


func _find_hand_card(card_id: String):
	for child in _hand_box.get_children():
		if child == _hand_spacer or child.is_queued_for_deletion():
			continue
		if String(child.get("card_id")) == card_id:
			return child
	return null


func _on_return_flight_done(node: Node, card_id: String, to_hand: bool) -> void:
	if is_instance_valid(node):
		node.queue_free()
	if to_hand and card_id != "":
		_flight_pending.erase(card_id)
		var hand_view = _find_hand_card(card_id)
		if hand_view:
			hand_view.modulate.a = 1.0
			hand_view.mouse_filter = Control.MOUSE_FILTER_STOP
			if hand_view.has_meta("awaiting_flight"):
				hand_view.remove_meta("awaiting_flight")
