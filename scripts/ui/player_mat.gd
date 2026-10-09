class_name PlayerMat
extends Panel

signal stack_top_pressed(mat, event: InputEvent)
signal stack_top_reveal_released(mat, card, t: float)
signal stack_top_reveal_scrub(mat, card, t: float)
signal reveal_sequence_started(mat)
signal reveal_sequence_finished(mat)
signal duck_presented(mat, card)

const CardScene = preload("res://scenes/card.tscn")
const ScreenFit = preload("res://scripts/ui/screen_fit.gd")

const MAT_SIZE := Vector2(210, 168)
const TOKEN_SCALE := 0.75
## Top-left of where card 0 appears (mat coords). Fan step keeps every card's left edge visible.
const STACK_ORIGIN := Vector2(10, 56)
const STACK_STEP := Vector2(18, 4)
## Flipped cards rest smaller, in a row on the mat's table-centre side (local top: the table rotates
## each mat so local UP faces the centre). Right-anchored so it never covers the stack's top token,
## which fans from the left.
const REVEAL_SCALE := 0.6
const REVEAL_ROW_Y := -10.0
const REVEAL_ROW_STEP := 30.0
const PARKED_Z := 20
const PRESENT_Z := 60
## Reveal sequence: drift toward the table centre while the flip clip finishes, present toward the
## camera, hold (longer + shake for a Duck), then settle into the reveal slot.
const PRESENT_DRIFT := 70.0
const DRIFT_SCALE := 0.9
const MIN_DRIFT_SEC := 0.2
const SAFE_PRESENT_SCALE := 1.15
const SAFE_PRESENT_IN_SEC := 0.18
const SAFE_HOLD_SEC := 0.22
const DUCK_PRESENT_SCALE := 1.6
const DUCK_PRESENT_IN_SEC := 0.35
const DUCK_HOLD_SEC := 0.9
const DUCK_SHAKE_SEC := 0.7
const DUCK_SHAKE_DEG := 10.0
const SETTLE_SEC := 0.35

var player_id: String = ""
var seat_color: Color = Color.WHITE

var _stack_box: Control
var _stack_count := 0
var _top_revealable := false
## card_id -> parked face-up CardView (kept until Next round)
var _parked: Dictionary = {}
var _sequences := 0


## Card node position for stack slot i (mat coords). Cards scale around their centre,
## so the node sits up-left of where the card is drawn.
static func slot_local(i: int) -> Vector2:
	return STACK_ORIGIN + STACK_STEP * i - CardView.SIZE * 0.5 * (1.0 - TOKEN_SCALE)


## Card node position for the i-th flipped card (mat coords).
static func reveal_slot_local(i: int) -> Vector2:
	var drawn := CardView.SIZE * REVEAL_SCALE
	var top_left := Vector2(MAT_SIZE.x - 10.0 - drawn.x - REVEAL_ROW_STEP * i, REVEAL_ROW_Y)
	return top_left - CardView.SIZE * 0.5 * (1.0 - REVEAL_SCALE)


## Table seats for n players, viewer first: [{pos, dir}] where dir faces the table centre.
## Positions are designed for 1280x720; extra width spreads the side seats toward the edges of
## `area` (the screen's safe rect) and everything else stays centred.
static func seat_layout(n: int, area := Rect2(Vector2.ZERO, ScreenFit.BASE)) -> Array:
	var extra := area.size - ScreenFit.BASE
	var at := func(base: Vector2, kx: float) -> Vector2:
		return (area.position + base + extra * Vector2(kx, 0.5)).round()
	var bottom := {pos = at.call(Vector2(535, 330), 0.5), dir = Vector2.UP}
	var top := {pos = at.call(Vector2(535, 90), 0.5), dir = Vector2.DOWN}
	var left := {pos = at.call(Vector2(40, 210), 0.0), dir = Vector2.RIGHT}
	var right := {pos = at.call(Vector2(1030, 210), 1.0), dir = Vector2.LEFT}
	var top_left := {pos = at.call(Vector2(180, 90), 0.25), dir = Vector2.DOWN}
	var top_right := {pos = at.call(Vector2(890, 90), 0.75), dir = Vector2.DOWN}
	match n:
		1:
			return [bottom]
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


func _ready() -> void:
	custom_minimum_size = MAT_SIZE
	pivot_offset = MAT_SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(p_id: String, color: Color) -> void:
	player_id = p_id
	seat_color = color
	_apply_style()
	if _stack_box != null:
		return

	# Covers the whole mat so slot_local() positions apply directly.
	_stack_box = Control.new()
	_stack_box.position = Vector2.ZERO
	_stack_box.size = MAT_SIZE
	_stack_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stack_box)


func _apply_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(seat_color.r, seat_color.g, seat_color.b, 0.12)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	add_theme_stylebox_override("panel", sb)


func refresh(info: Dictionary, top_revealable: bool = false) -> void:
	if _stack_box == null:
		setup(player_id, seat_color)
	modulate = Color(0.45, 0.45, 0.45, 1) if info.eliminated else Color.WHITE
	_top_revealable = top_revealable
	_rebuild_stack(int(info.stack_count), top_revealable)


func top_card():
	if _stack_box == null or _stack_box.get_child_count() == 0:
		return null
	return _stack_box.get_child(_stack_box.get_child_count() - 1)


func stack_size() -> int:
	return _stack_count


func stack_token(i: int):
	if _stack_box == null or i < 0 or i >= _stack_box.get_child_count():
		return null
	return _stack_box.get_child(i)


func _node_is_reveal_card(c: Node, cid: String) -> bool:
	if not is_instance_valid(c):
		return false
	if String(c.get_meta("reveal_card_id", "")) == cid:
		return true
	if c.get("card_id") != null and String(c.card_id) == cid and (
		c.has_meta("linger_reveal") or c.has_meta("parked_reveal")
	):
		return true
	return false


## Rules accepted a flip of this mat's top card: lift it out of the stack, finish the flip while
## drifting toward the table centre, present it toward the camera, then settle into reveal slot
## `reveal_index` (this card's index among this mat's flips).
func apply_revealed_to_top(is_duck: bool, card_id: String = "", reveal_index: int = -1) -> void:
	var top = top_card()
	if top == null or not top.has_method("set_revealed_face"):
		return
	if reveal_index < 0:
		reveal_index = _parked.size()
	# Stack cards are always the mat owner's.
	top.owner_id = player_id
	top.set_meta("reveal_owner_id", player_id)
	top.set_meta("linger_reveal", true)
	if card_id != "":
		top.set_meta("reveal_card_id", card_id)
		top.card_id = card_id
	top.is_duck = is_duck
	# Off the stack now so the next token is free to scrub while this one animates.
	top.reparent(self, true)
	_stack_count = maxi(_stack_count - 1, 0)
	_set_top_interactable(_top_revealable)
	top.interactable = false
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.z_index = PARKED_Z
	_run_reveal_sequence(top, is_duck, reveal_index)


func reveals_in_flight() -> int:
	return _sequences


func _run_reveal_sequence(card: Node, is_duck: bool, idx: int) -> void:
	_sequences += 1
	card.set_meta("revealing", true)
	card.tree_exiting.connect(_finish_sequence.bind(card, false), CONNECT_ONE_SHOT)
	reveal_sequence_started.emit(self)
	var present_pos: Vector2 = present_point(card)
	var drift_sec := maxf(card.flip_remaining_sec(), MIN_DRIFT_SEC)
	var drift := card.create_tween().set_parallel(true)
	drift.tween_property(card, "position", present_pos, drift_sec) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	drift.tween_property(card, "scale", Vector2.ONE * DRIFT_SCALE, drift_sec) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	card.set_meta("reveal_tween", drift)
	# Connect first: set_revealed_face settles synchronously when the clip is already at its end.
	card.reveal_settled.connect(
		func(_c): _present(card, is_duck, idx, drift, present_pos), CONNECT_ONE_SHOT
	)
	card.set_revealed_face(is_duck)


## Where a flipped card drifts to while its flip finishes (node position, mat coords; local UP
## faces the table centre).
func present_point(card: Node) -> Vector2:
	return card.position + Vector2.UP * PRESENT_DRIFT


## Safe presents in place in the mat's own frame; a Duck turns upright for this screen and
## presents at the screen centre before settling back into the reveal row.
func _present(card: Node, is_duck: bool, idx: int, drift: Tween, present_pos: Vector2) -> void:
	if not is_instance_valid(card) or not card.has_meta("revealing"):
		return
	card.z_index = PRESENT_Z
	var in_sec := DUCK_PRESENT_IN_SEC if is_duck else SAFE_PRESENT_IN_SEC
	var s := DUCK_PRESENT_SCALE if is_duck else SAFE_PRESENT_SCALE
	var tw := card.create_tween()
	card.set_meta("reveal_tween", tw)
	tw.tween_property(card, "scale", Vector2.ONE * s, in_sec).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(card, "present_height", 1.0, in_sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if is_duck:
		present_pos = get_global_transform().affine_inverse() * (get_viewport_rect().size * 0.5) - CardView.SIZE * 0.5
		tw.parallel().tween_property(card, "rotation", wrapf(-rotation, -PI, PI), in_sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Clip ended before the drift did (flip was mostly scrubbed already): finish the move here.
	if is_duck or (drift and drift.is_valid() and drift.is_running()):
		if drift and drift.is_valid():
			drift.kill()
		tw.parallel().tween_property(card, "position", present_pos, in_sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if is_duck:
		tw.tween_callback(func():
			card.shake(DUCK_SHAKE_SEC, DUCK_SHAKE_DEG)
			duck_presented.emit(self, card)
		)
	tw.tween_interval(DUCK_HOLD_SEC if is_duck else SAFE_HOLD_SEC)
	tw.tween_callback(func(): card.z_index = PARKED_Z + 1)
	tw.tween_property(card, "position", reveal_slot_local(idx), SETTLE_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(card, "scale", Vector2.ONE * REVEAL_SCALE, SETTLE_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(card, "present_height", 0.0, SETTLE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if is_duck:
		tw.parallel().tween_property(card, "rotation", 0.0, SETTLE_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		card.juice()
		_finish_sequence(card, true)
	)


## Report done (and park when `park`). Also runs on tree exit mid-sequence (Next round flight,
## mat freed) so the table never waits forever on a result hold.
func _finish_sequence(card: Node, park: bool) -> void:
	if not is_instance_valid(card) or not card.has_meta("revealing"):
		return
	card.remove_meta("revealing")
	if card.has_meta("reveal_tween"):
		var tw = card.get_meta("reveal_tween")
		if tw is Tween and tw.is_valid():
			tw.kill()
		card.remove_meta("reveal_tween")
	if park and card.get_parent() == self:
		card.z_index = PARKED_Z
		card.set_meta("parked_reveal", true)
		var cid := String(card.get_meta("reveal_card_id", card.card_id))
		if cid == "":
			cid = "reveal_%s" % card.get_instance_id()
		_parked[cid] = card
	_sequences = maxi(_sequences - 1, 0)
	reveal_sequence_finished.emit(self)


func apply_remote_scrub(t: float) -> void:
	var top = top_card()
	if top == null:
		return
	if top.get("_settling_face_up") == true:
		return
	if top.has_method("scrub_flip"):
		top.scrub_flip(t)


func apply_remote_cancel() -> void:
	var top = top_card()
	if top == null:
		return
	if top.get("_settling_face_up") == true:
		return
	if top.has_method("abort_flip"):
		top.abort_flip()


## Ensure face-up parked cards match flip_history entries for this mat.
func sync_parked_reveals(entries: Array) -> void:
	var want: Dictionary = {}
	for i in entries.size():
		var e: Dictionary = entries[i]
		var cid := String(e.get("card_id", ""))
		if cid == "":
			continue
		want[cid] = e
		if _parked.has(cid) and is_instance_valid(_parked[cid]):
			_parked[cid].set_meta("reveal_owner_id", String(e.get("owner_id", "")))
			continue
		# A card mid reveal sequence parks itself when it lands.
		var already := false
		for c in get_children():
			if _node_is_reveal_card(c, cid):
				c.set_meta("reveal_owner_id", String(e.get("owner_id", "")))
				already = true
				break
		if already:
			continue
		_spawn_parked_reveal(cid, bool(e.get("is_duck", false)), i, String(e.get("owner_id", "")))
	# Drop parked cards no longer in history (Next round / new hand).
	var drop: Array = []
	for cid in _parked.keys():
		if not want.has(cid):
			drop.append(cid)
	for cid in drop:
		var node = _parked[cid]
		_parked.erase(cid)
		if is_instance_valid(node):
			node.queue_free()


## Detach parked reveals for flight animation. Caller owns the nodes.
func take_parked_reveals() -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for cid in _parked.keys():
		var node = _parked[cid]
		if is_instance_valid(node) and not seen.has(node):
			out.append(node)
			seen[node] = true
	_parked.clear()
	for c in get_children():
		if not is_instance_valid(c):
			continue
		if not (c.has_meta("linger_reveal") or c.has_meta("parked_reveal")):
			continue
		if seen.has(c):
			continue
		out.append(c)
		seen[c] = true
	# Next round can start mid-sequence; the caller's flight owns position/scale from here.
	for c in out:
		_finish_sequence(c, false)
		c.set("present_height", 0.0)
	return out


func clear_parked_reveals() -> void:
	for cid in _parked.keys():
		var node = _parked[cid]
		if is_instance_valid(node):
			node.queue_free()
	_parked.clear()
	# Also clear any lingering settle cards parented to the mat.
	for c in get_children():
		if c.has_meta("linger_reveal") or c.has_meta("parked_reveal"):
			c.queue_free()


func _rebuild_stack(count: int, top_revealable: bool) -> void:
	if _stack_box == null:
		return
	# Diff when possible so scrub mid-flight isn't wiped on unrelated snapshot noise.
	if count == _stack_count and _stack_box.get_child_count() == count:
		_set_top_interactable(top_revealable)
		return
	var old_count := _stack_count
	_stack_count = count
	if count < old_count or count == 0 or _stack_box.get_child_count() != old_count:
		for c in _stack_box.get_children():
			_stack_box.remove_child(c)
			c.queue_free()
		for i in count:
			_add_token(i, top_revealable and i == count - 1)
		return
	# count increased: append new tokens (landing pop on every screen)
	for i in range(old_count, count):
		_add_token(i, top_revealable and i == count - 1)
		var landed = top_card()
		if landed and landed.has_method("juice"):
			landed.juice()
	_set_top_interactable(top_revealable)


## Late join / missed animation: appear already settled in reveal slot `idx`.
func _spawn_parked_reveal(card_id: String, is_duck: bool, idx: int, owner_id: String = "") -> void:
	var token = CardScene.instantiate()
	add_child(token)
	token.scale = Vector2(REVEAL_SCALE, REVEAL_SCALE)
	token.position = reveal_slot_local(maxi(idx, 0))
	token.setup_stack_token(false, owner_id if owner_id != "" else player_id)
	token.card_id = card_id
	token.set_meta("reveal_card_id", card_id)
	token.set_meta("parked_reveal", true)
	if owner_id != "":
		token.set_meta("reveal_owner_id", owner_id)
	if token.has_method("show_face_up_rest"):
		token.show_face_up_rest(is_duck)
	token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	token.z_index = PARKED_Z
	_parked[card_id] = token


func _add_token(index: int, revealable: bool) -> void:
	var token = CardScene.instantiate()
	_stack_box.add_child(token)
	token.position = slot_local(index)
	token.scale = Vector2(TOKEN_SCALE, TOKEN_SCALE)
	token.setup_stack_token(revealable, player_id)
	if not token.reveal_released.is_connected(_on_top_reveal_released):
		token.reveal_released.connect(_on_top_reveal_released)
	if token.has_signal("reveal_scrub") and not token.reveal_scrub.is_connected(_on_top_reveal_scrub):
		token.reveal_scrub.connect(_on_top_reveal_scrub)


func _set_top_interactable(revealable: bool) -> void:
	var top = top_card()
	if top == null:
		return
	top.interactable = revealable
	top.reveal_mode = true
	top.drag_enabled = false
	top.mouse_filter = Control.MOUSE_FILTER_STOP if revealable else Control.MOUSE_FILTER_IGNORE
	if top.has_signal("reveal_scrub") and not top.reveal_scrub.is_connected(_on_top_reveal_scrub):
		top.reveal_scrub.connect(_on_top_reveal_scrub)
	if not top.reveal_released.is_connected(_on_top_reveal_released):
		top.reveal_released.connect(_on_top_reveal_released)


func _on_top_reveal_released(card, t: float) -> void:
	stack_top_reveal_released.emit(self, card, t)


func _on_top_reveal_scrub(card, t: float) -> void:
	stack_top_reveal_scrub.emit(self, card, t)


func contains_point(global_pt: Vector2) -> bool:
	return get_global_rect().has_point(global_pt)


## Global centre of stack slot `i` (default: the next one a place will fill). Mats may be rotated;
## subtract CardView.SIZE / 2 for the node position of a centre-pivoted card on an unrotated parent.
func stack_slot_centre_global(i: int = -1) -> Vector2:
	if i < 0:
		i = _stack_count
	return get_global_transform() * (slot_local(i) + CardView.SIZE * 0.5)
