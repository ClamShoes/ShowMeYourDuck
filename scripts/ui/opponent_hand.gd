extends Control
## One opponent's hand on this screen: face-down backs laid out exactly like the viewer's own hand
## box (SeatSpace.HAND_SIZE, centred HBox), then placed/rotated by SeatSpace.hand_xform. Same
## layout on both screens means a relayed slot index lands on the same card.

const CardScene = preload("res://scenes/card.tscn")
const SeatSpace = preload("res://scripts/ui/seat_space.gd")

## A placed/discarded card leaves before the snapshot drops hand_count; don't re-add it meanwhile.
const PENDING_OUT_MS := 1500
var player_id := ""
var _box: HBoxContainer
var _spacer: Control = null
var _held = null
var _hover_slot := -1
var _last_count := -1
var _pending_out := 0
var _pending_out_msec := 0


func setup(pid: String) -> void:
	player_id = pid
	size = SeatSpace.HAND_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = HBoxContainer.new()
	_box.size = SeatSpace.HAND_SIZE
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)


func _exit_tree() -> void:
	if _held != null and is_instance_valid(_held):
		_held.queue_free()
	_held = null


func place(xf: Transform2D) -> void:
	position = xf.origin
	rotation = xf.get_rotation()
	scale = xf.get_scale()


func centre_global() -> Vector2:
	return get_global_transform() * (size * 0.5)


func sync_count(n: int) -> void:
	if n != _last_count:
		_last_count = n
		_pending_out = 0
	if _pending_out > 0 and Time.get_ticks_msec() - _pending_out_msec > PENDING_OUT_MS:
		_pending_out = 0
	var want := maxi(n - (1 if _held != null else 0) - _pending_out, 0)
	var cards := _cards()
	while cards.size() > want:
		var c = cards.pop_back()
		_box.remove_child(c)
		c.queue_free()
	while cards.size() < want:
		var c = CardScene.instantiate()
		_box.add_child(c)
		c.setup_hidden(player_id)
		cards.append(c)


func set_hover(slot: int) -> void:
	_hover_slot = slot
	var cards := _cards()
	for i in cards.size():
		cards[i].set_remote_hover(i == slot)


## Owner's pointer moved (global, this screen): lean the hovered card or steer the held one.
func set_point(p: Vector2) -> void:
	if _held != null and is_instance_valid(_held):
		_held.follow_remote(p - CardView.SIZE * 0.5)
		return
	var c = _card_at(_hover_slot)
	if c != null:
		c.set_remote_point(p)


func begin_drag(slot: int, drag_layer: Control) -> void:
	if _held != null:
		drop_return(-1)
	var c = _card_at(slot)
	if c == null:
		return
	set_hover(-1)
	SeatSpace.reparent_keep_pose(c, drag_layer)
	# table._layout_hand clears unknown cards off the drag layer; this one is ours.
	c.set_meta("remote_hand", true)
	_held = c
	_ensure_spacer(slot)
	# Keeps the hand's seat angle and size: it's their card, seen from where they sit.
	c.follow_remote(c.position)


func move_gap(slot: int) -> void:
	if _spacer == null:
		return
	var cards := _cards()
	slot = clampi(slot, 0, cards.size())
	if slot == _spacer.get_index():
		return
	if not cards.is_empty():
		cards[mini(slot, cards.size() - 1)].play_quiver()
	_box.move_child(_spacer, slot)


func drop_return(slot: int) -> void:
	var c = _take_held_node()
	if c == null:
		return
	var idx := slot if slot >= 0 else (_spacer.get_index() if _spacer != null else _cards().size())
	_clear_spacer()
	c.get_parent().remove_child(c)
	_box.add_child(c)
	_box.move_child(c, clampi(idx, 0, _box.get_child_count() - 1))
	c.remove_meta("remote_hand")
	c.rotation = 0.0
	c.scale = Vector2.ONE
	c.juice()


## Held card leaves for the owner's mat; the caller owns the node from here.
func take_held():
	var c = _take_held_node()
	_clear_spacer()
	if c != null:
		_mark_pending_out()
	return c


## A hand card is being destroyed: the hovered one (the owner just tapped it) or the last.
func take_for_discard(drag_layer: Control):
	var cards := _cards()
	if cards.is_empty():
		return null
	var c = _card_at(_hover_slot)
	if c == null:
		c = cards[cards.size() - 1]
	set_hover(-1)
	SeatSpace.reparent_keep_pose(c, drag_layer)
	_mark_pending_out()
	return c


func _take_held_node():
	var c = _held
	_held = null
	if c == null or not is_instance_valid(c):
		return null
	c.stop_follow()
	return c


func _mark_pending_out() -> void:
	_pending_out = 1
	_pending_out_msec = Time.get_ticks_msec()


func _cards() -> Array:
	var out: Array = []
	for c in _box.get_children():
		if c != _spacer and not c.is_queued_for_deletion():
			out.append(c)
	return out


func _card_at(slot: int):
	var cards := _cards()
	return cards[slot] if slot >= 0 and slot < cards.size() else null


func _ensure_spacer(at_index: int) -> void:
	_clear_spacer()
	_spacer = Control.new()
	_spacer.custom_minimum_size = CardView.SIZE
	_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_spacer)
	_box.move_child(_spacer, clampi(at_index, 0, _box.get_child_count() - 1))


func _clear_spacer() -> void:
	if _spacer != null and is_instance_valid(_spacer):
		_spacer.queue_free()
	_spacer = null
