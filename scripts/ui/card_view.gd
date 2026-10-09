class_name CardView
extends Control
## One card: hand (drag to play) or stack token (scrub Card_Flip, then play the rest).
## Visual tree: scenes/card.tscn. Anim / Card_Flip drives only the shader flip rotation;
## everything else about how the card looks (lift, scale, sway, tilt, float, shadow) is
## written by _update_visual each frame.

signal dropped(card, at: Vector2)
signal pressed(card)
## Challenger horizontal scrub 0..1 over the scrub window (for live net relay).
signal reveal_scrub(card, t: float)
## Scrub ended (release or auto-commit at end of scrub window).
signal reveal_released(card, t: float)
signal drag_started(card)
signal drag_cancelled(card)
## Card_Flip finished the second half — safe to park / advance UI.
signal reveal_settled(card)
## Local place: face-up→face-down flip finished.
signal place_flip_finished(card)

const SIZE := Vector2(96, 128)
const REST_POS := Vector2(48, 64)
const SHADOW_OFFSET := Vector2(6, 8)
## Mouse pixels to drag through the full scrub window (0 → SCRUB_END_SEC).
const PIXELS_PER_SCRUB := 160.0
## First segment of Card_Flip is mouse-driven; past this the clip plays itself.
const SCRUB_END_SEC := 0.46
const ABORT_SEEK_SEC := 0.28
const FLIP_ANIM := "Card_Flip"
## Card_Flip swaps back → face at this clip time.
const FLIP_EDGE_SEC := 0.5
const HOVER_Z := 5

const CardArt = preload("res://scripts/ui/card_art.gd")
const CardJuice = preload("res://scripts/ui/card_juice.gd")

## Driven by Card_Flip track `.:card_flipped` near ~0.47s.
@export var card_flipped: bool = false

@export_group("Feel")
@export var hover_lift := 14.0
@export var hover_scale := 1.08
## Degrees of 3D lean toward the mouse at the card's edge. Negate to flip the lean direction.
@export var tilt_max_deg := 12.0
@export var spring_k := 220.0
@export var spring_damping := 20.0
@export var drag_spring_k := 520.0
@export var drag_spring_damping := 36.0
## In-plane swing (degrees) per px/s of horizontal drag speed.
@export var sway_per_speed := 0.012
@export var sway_max_deg := 12.0
@export var idle_bob_px := 1.5
@export var idle_rock_deg := 1.2
@export var idle_speed := 1.6
@export var pop_scale := 0.1
@export var pop_rot_deg := 3.0
@export var flip_lift_px := 10.0
@export var flip_scale := 0.1
@export var shadow_alpha := 0.35
## Sprite rise at present_height 1 (reveal "toward the camera").
@export var present_lift_px := 18.0
@export_group("")

## 0..1, tweened by the reveal sequence: lifts the sprite and drops/fades the shadow.
var present_height := 0.0

var card_id: String = ""
## Player whose back/front art this card wears.
var owner_id: String = ""
var is_duck: bool = false
## False for unrevealed stack tokens — face sprite gets the owner's blank frame, never Duck/Safe.
var face_known: bool = false
var face_up: bool = true
var interactable: bool = false
var drag_enabled: bool = true
## Stack token: input is scrub-flip, not hand drag.
var reveal_mode: bool = false

var _dragging := false
var _hovering := false
var _remote_hover := false
var _scrubbing := false
var _settling_face_up := false
var _place_flipping := false
## 0..1 progress through the scrub window only (1.0 == SCRUB_END_SEC on the clip).
var _scrub_t := 0.0
## Current Card_Flip seek time in seconds.
var _anim_time := 0.0
var _abort_tween: Tween
var _place_flip_tween: Tween
var _press_x := 0.0
var _hand_parent: Node = null
var _hand_index := 0
var _drag_layer: Node = null
var _materials_unique := false
var _front_mat_saved: Material = null
var _flip_finished_connected := false

# Feel state (see _update_visual).
var _time := 0.0
var _idle_phase := 0.0
var _idle_w := 1.0
var _lift := 0.0
var _lift_v := 0.0
var _hscale := 1.0
var _hscale_v := 0.0
var _tilt := Vector2.ZERO
var _tilt_v := Vector2.ZERO
var _sway := 0.0
var _sway_v := 0.0
var _drag_pos := Vector2.ZERO
var _drag_vel := Vector2.ZERO
var _pop_t := CardJuice.POP_DUR
var _pop_scale_amt := 0.0
var _pop_rot_amt := 0.0
var _shake_t := 0.0
var _shake_dur := 0.0
var _shake_amp := 0.0

@onready var _card_back: Sprite2D = $cardBack
@onready var _card_front: Sprite2D = $cardBack2
@onready var _shadow_back: Sprite2D = $cardBack/shadow
@onready var _shadow_front: Sprite2D = $cardBack2/shadow
@onready var _anim: AnimationPlayer = $Anim


func _ready() -> void:
	_bind_nodes()
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Instance id, never card identity — idle motion must not hint Duck vs Safe.
	_idle_phase = float(get_instance_id() % 997) * 0.731
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	_ensure_flip_finished_connected()
	_apply_card_art()
	_sync_face_visibility()
	_update_visual(0.0)


## Resolve nodes + unique shader materials so scrubbing one card doesn't rotate others.
func _bind_nodes() -> void:
	if _card_back == null:
		_card_back = get_node_or_null("cardBack") as Sprite2D
	if _card_front == null:
		_card_front = get_node_or_null("cardBack2") as Sprite2D
	if _shadow_back == null:
		_shadow_back = get_node_or_null("cardBack/shadow") as Sprite2D
	if _shadow_front == null:
		_shadow_front = get_node_or_null("cardBack2/shadow") as Sprite2D
	if _anim == null:
		_anim = get_node_or_null("Anim") as AnimationPlayer
	if not _materials_unique:
		if _card_back and _card_back.material:
			_card_back.material = _card_back.material.duplicate()
		if _card_front and _card_front.material:
			_card_front.material = _card_front.material.duplicate()
		_materials_unique = true
	if _front_mat_saved == null and _card_front and _card_front.material:
		_front_mat_saved = _card_front.material
	_ensure_flip_finished_connected()


func _ensure_flip_finished_connected() -> void:
	if _anim == null or _flip_finished_connected:
		return
	if not _anim.animation_finished.is_connected(_on_flip_animation_finished):
		_anim.animation_finished.connect(_on_flip_animation_finished)
	_flip_finished_connected = true


## Hand card (owner sees face). Called by table._layout_hand.
func setup(p_id: String, p_is_duck: bool, p_face_up: bool, p_interactable: bool, p_drag: bool = true, p_owner_id: String = "") -> void:
	card_id = p_id
	owner_id = p_owner_id
	is_duck = p_is_duck
	face_known = true
	face_up = p_face_up
	interactable = p_interactable
	drag_enabled = p_drag
	reveal_mode = false
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bind_nodes()
	_apply_card_art()
	if not _scrubbing and not _dragging and not _settling_face_up and not _place_flipping:
		# Re-layout every snapshot must not drop the hover the mouse is still on.
		var keep_hover := _hovering and interactable
		scale = Vector2.ONE
		_reset_visuals_quiet()
		if keep_hover:
			_set_hover(true)
	else:
		_sync_face_visibility()


## Face-down stack token. Face unknown until set_revealed_face after rules commit.
func setup_stack_token(p_interactable: bool = false, p_owner_id: String = "") -> void:
	card_id = ""
	owner_id = p_owner_id
	is_duck = false
	face_known = false
	face_up = false
	interactable = p_interactable
	drag_enabled = false
	reveal_mode = true
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = SIZE * 0.5
	_bind_nodes()
	_apply_card_art()
	_sync_face_visibility()
	_reset_visuals_quiet()


func set_drag_layer(layer: Node) -> void:
	_drag_layer = layer


## Rules accepted the flip: apply Duck/Safe and play Card_Flip from scrub end → finish.
func set_revealed_face(p_is_duck: bool) -> void:
	_bind_nodes()
	is_duck = p_is_duck
	face_known = true
	face_up = true
	_scrubbing = false
	_set_hover(false)
	_apply_card_art()
	_ensure_sprite_materials()
	_kill_abort_tween()
	_settling_face_up = true
	var start_t := maxf(_anim_time, SCRUB_END_SEC)
	var anim_len := _flip_anim_length()
	if start_t >= anim_len - 0.001:
		_anim_time = anim_len
		_seek_flip(anim_len, true)
		_finish_face_up_settle()
		return
	_play_flip_from(start_t)


## Instant face-up at Card_Flip end (parked/remote sync — no play, no idle snap).
func show_face_up_rest(p_is_duck: bool) -> void:
	_bind_nodes()
	is_duck = p_is_duck
	face_known = true
	face_up = true
	card_flipped = true
	_apply_card_art()
	_seek_flip(_flip_anim_length(), true)
	_sync_flip_layering(_flip_anim_length())
	_settling_face_up = false


## Seconds set_revealed_face will take to finish the clip from the current pose.
func flip_remaining_sec() -> float:
	var speed := 1.0
	if _anim and _anim.speed_scale > 0.0:
		speed = _anim.speed_scale
	return maxf(_flip_anim_length() - maxf(_anim_time, SCRUB_END_SEC), 0.0) / speed


## Decaying rotational wobble (Duck reveal).
func shake(duration: float, amp_deg: float) -> void:
	_shake_dur = maxf(duration, 0.01)
	_shake_t = _shake_dur
	_shake_amp = amp_deg


func _flip_anim_length() -> float:
	if _anim == null:
		return 1.0
	var anim := _anim.get_animation(FLIP_ANIM)
	if anim == null:
		return 1.0
	return maxf(anim.length, SCRUB_END_SEC)


## Seek Card_Flip and pause — used for mouse/remote scrub of the first segment.
func _seek_flip(time_sec: float, pause_after: bool = true) -> void:
	_bind_nodes()
	if _anim == null:
		return
	_anim_time = clampf(time_sec, 0.0, _flip_anim_length())
	if _anim.current_animation != FLIP_ANIM:
		_anim.play(FLIP_ANIM)
	_anim.seek(_anim_time, true)
	if pause_after:
		_anim.pause()
	_sync_flip_layering(_anim_time)


## Card_Flip does not key z_index; without this, cardBack2 stays at -1 and the second half is hidden.
func _sync_flip_layering(time_sec: float) -> void:
	_ensure_sprite_materials()
	var past_edge := time_sec >= FLIP_EDGE_SEC
	if _card_back:
		_card_back.visible = true
		_card_back.z_index = -1 if past_edge else 0
	if _card_front:
		_card_front.visible = true
		_card_front.z_index = 1 if past_edge else -1


func _play_flip_from(time_sec: float) -> void:
	_bind_nodes()
	if _anim == null:
		_finish_face_up_settle()
		return
	_ensure_flip_finished_connected()
	_anim_time = clampf(time_sec, 0.0, _flip_anim_length())
	if _anim_time >= _flip_anim_length() - 0.001:
		_seek_flip(_anim_time, true)
		_finish_face_up_settle()
		return
	# Always (re)start the clip then seek — scrub pause must not stick.
	_anim.stop()
	_anim.play(FLIP_ANIM)
	_anim.seek(_anim_time, true)
	_anim.play()
	_sync_flip_layering(_anim_time)


func _on_flip_animation_finished(anim_name: StringName) -> void:
	if String(anim_name) != FLIP_ANIM:
		return
	# Place flip is tween-driven (not AnimationPlayer reverse) — ignore finished here.
	if _place_flipping:
		return
	if not _settling_face_up:
		return
	_anim_time = _flip_anim_length()
	_finish_face_up_settle()


## Local play: face-up → face-down by scrubbing Card_Flip 1→0 (Control position untouched).
## Uses a tween seek (not reverse play) so the flip can't be skipped/no-op'd by AnimationPlayer.
func play_flip_to_face_down() -> void:
	_bind_nodes()
	_place_flipping = true
	_settling_face_up = false
	_scrubbing = false
	_set_hover(false)
	_kill_place_flip_tween()
	_apply_card_art()
	_ensure_sprite_materials()
	var anim_len := _flip_anim_length()
	# Start at face-up end of the clip, then scrub down to face-down.
	_seek_flip(anim_len, true)
	_sync_flip_layering(anim_len)
	_place_flip_tween = create_tween()
	_place_flip_tween.tween_method(_tween_place_flip_seek, anim_len, 0.0, anim_len / 6.5)
	_place_flip_tween.tween_callback(_finish_place_flip)


func _tween_place_flip_seek(time_sec: float) -> void:
	_seek_flip(time_sec, true)
	_sync_flip_layering(time_sec)


func _kill_place_flip_tween() -> void:
	if _place_flip_tween and is_instance_valid(_place_flip_tween):
		_place_flip_tween.kill()
	_place_flip_tween = null


func _finish_place_flip() -> void:
	_kill_place_flip_tween()
	_place_flipping = false
	face_up = false
	card_flipped = false
	_anim_time = 0.0
	if _anim:
		_anim.speed_scale = 1.0
	_seek_flip(0.0, true)
	_sync_flip_layering(0.0)
	place_flip_finished.emit(self)


func _finish_face_up_settle() -> void:
	_lock_face_up_rest()
	if is_duck:
		juice(pop_scale * 1.8, pop_rot_deg * 3.0)
	else:
		juice(pop_scale * 1.2, pop_rot_deg * 1.3)
	reveal_settled.emit(self)


func _kill_abort_tween() -> void:
	if _abort_tween and is_instance_valid(_abort_tween):
		_abort_tween.kill()
	_abort_tween = null


func _ensure_sprite_materials() -> void:
	if _card_front and _card_front.material == null and _front_mat_saved != null:
		_card_front.material = _front_mat_saved
	if _card_back:
		_card_back.visible = true
	if _card_front:
		_card_front.visible = true


## Snap shader rotation + z without Card_Flip — used for hand idle and parked rest.
func _apply_idle_pose(face_is_up: bool) -> void:
	_bind_nodes()
	_ensure_sprite_materials()
	if _anim:
		_anim.stop()
	_anim_time = _flip_anim_length() if face_is_up else 0.0
	if _card_back:
		_card_back.visible = true
		_card_back.z_index = -1 if face_is_up else 0
		var back_mat := _card_back.material as ShaderMaterial
		if back_mat:
			back_mat.set_shader_parameter("y_rot", 90.0 if face_is_up else 0.0)
			back_mat.set_shader_parameter("cull_back", true)
	if _card_front:
		_card_front.visible = true
		_card_front.z_index = 1 if face_is_up else -1
		var front_mat := _card_front.material as ShaderMaterial
		if front_mat:
			front_mat.set_shader_parameter("y_rot", 0.0 if face_is_up else -90.0)
			front_mat.set_shader_parameter("cull_back", true)
	card_flipped = face_is_up


## After clip finishes: reveal tokens keep anim end pose — no idle snap.
func _lock_face_up_rest() -> void:
	_settling_face_up = false
	_kill_abort_tween()
	face_up = true
	card_flipped = true
	_scrub_t = 1.0
	_anim_time = _flip_anim_length()
	z_index = 0
	_apply_card_art()
	if reveal_mode:
		_seek_flip(_anim_time, true)
		_sync_flip_layering(_anim_time)
	else:
		_apply_idle_pose(true)
	face_up = true
	card_flipped = true


## Hard idle reset. Skips if a gesture/settle is active so table re-renders don't cancel them.
func force_idle() -> void:
	if _dragging or _scrubbing or _settling_face_up or _place_flipping:
		return
	_set_hover(false)
	_kill_abort_tween()
	z_index = 0
	if _anim:
		_anim.stop()
	_anim_time = 0.0
	_scrub_t = 0.0
	_sync_face_visibility()


func play_select() -> void:
	_set_hover(true)
	juice()


func play_deselect() -> void:
	_set_hover(false)


## Mirror another player's hover: same lift/scale/pop, but no lean toward the local mouse.
func set_remote_hover(on: bool) -> void:
	_remote_hover = on
	if on and not _hovering:
		play_select()
	elif not on:
		_set_hover(false)


func play_quiver() -> void:
	juice(pop_scale * 0.8, pop_rot_deg * 2.0)


## Balatro-style pop: quick overshoot-and-settle on scale and rotation.
func juice(scale_amt: float = -1.0, rot_deg: float = -1.0) -> void:
	_pop_scale_amt = pop_scale if scale_amt < 0.0 else scale_amt
	_pop_rot_amt = pop_rot_deg if rot_deg < 0.0 else rot_deg
	_pop_t = 0.0


func _set_hover(on: bool) -> void:
	if _hovering == on:
		return
	_hovering = on
	if not reveal_mode and not _dragging:
		z_index = HOVER_Z if on else 0


## Scrub progress 0..1 maps onto Card_Flip time 0..SCRUB_END_SEC (paused).
func scrub_flip(t: float) -> void:
	_bind_nodes()
	_scrub_t = clampf(t, 0.0, 1.0)
	if not face_up and not _settling_face_up:
		_apply_card_art()
	_seek_flip(_scrub_t * SCRUB_END_SEC, true)


## Mouse dx → scrub window 0..1 (no second-half stretch; anim plays that part).
func scrub_t_from_mouse_dx(dx: float) -> float:
	return clampf(dx / PIXELS_PER_SCRUB, 0.0, 1.0)


## Auto-commit when the scrub window is fully dragged (clip time == SCRUB_END_SEC).
func _commit_reveal_if_scrub_complete() -> bool:
	if not _scrubbing or _scrub_t < 1.0:
		return false
	_scrubbing = false
	reveal_released.emit(self, _scrub_t)
	return true


## Release before commit: rewind Card_Flip toward 0.
func abort_flip() -> void:
	_scrubbing = false
	_settling_face_up = false
	_kill_abort_tween()
	_bind_nodes()
	var from := _anim_time
	if from <= 0.001:
		_scrub_t = 0.0
		_anim_time = 0.0
		_reset_visuals_quiet()
		return
	var dur := ABORT_SEEK_SEC * clampf(from / SCRUB_END_SEC, 0.15, 1.0)
	_abort_tween = create_tween()
	_abort_tween.tween_method(_tween_abort_seek, from, 0.0, dur)
	_abort_tween.tween_callback(func():
		_scrub_t = 0.0
		_anim_time = 0.0
		_reset_visuals_quiet()
	)


func _tween_abort_seek(time_sec: float) -> void:
	_seek_flip(time_sec, true)
	_scrub_t = clampf(time_sec / SCRUB_END_SEC, 0.0, 1.0)


func finish_flip_to_end() -> void:
	_scrubbing = false
	set_revealed_face(is_duck)


func remember_rest_position() -> void:
	pass


func return_to_hand(at_index: int = -1) -> void:
	_dragging = false
	top_level = false
	z_as_relative = true
	z_index = 0
	scale = Vector2.ONE
	visible = true
	if at_index >= 0:
		_hand_index = at_index
	_restore_hand_parent()
	force_idle()
	juice()


func hide_after_place() -> void:
	_dragging = false
	_set_hover(false)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_dragging() -> bool:
	return _dragging


func get_hand_index() -> int:
	return _hand_index


func set_hand_index(idx: int) -> void:
	_hand_index = idx


## Owner's back on cardBack, owner's face on cardBack2 (required for flip second half).
func _apply_card_art() -> void:
	_bind_nodes()
	var back_tex := CardArt.back_texture(owner_id)
	var face_tex := CardArt.face_texture(owner_id, is_duck) if face_known else CardArt.blank_face_texture(owner_id)
	if _card_back:
		_card_back.texture = back_tex
		_card_back.modulate = Color.WHITE
	if _card_front:
		_card_front.texture = face_tex
		_card_front.modulate = Color.WHITE
	if _shadow_back:
		_shadow_back.texture = back_tex
	if _shadow_front:
		_shadow_front.texture = face_tex


func _sync_face_visibility() -> void:
	_bind_nodes()
	if _card_back == null or _card_front == null:
		return
	_ensure_sprite_materials()
	_apply_idle_pose(face_up or card_flipped)
	_apply_card_art()


func _reset_visuals_quiet() -> void:
	card_flipped = false
	_anim_time = 0.0
	_scrub_t = 0.0
	_ensure_sprite_materials()
	_apply_card_art()
	force_idle()
	_sync_face_visibility()


func _on_mouse_entered() -> void:
	if not interactable or _dragging or _scrubbing:
		return
	play_select()


func _on_mouse_exited() -> void:
	if _dragging or _scrubbing:
		return
	_set_hover(false)


func _gui_input(event: InputEvent) -> void:
	if reveal_mode:
		_handle_reveal_input(event)
		return
	if not interactable:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pressed.emit(self)
			if drag_enabled:
				_begin_drag()
			accept_event()
		else:
			if _dragging:
				_end_drag()
			accept_event()


func _begin_drag() -> void:
	force_idle()
	_hand_parent = get_parent()
	_hand_index = get_index()
	var gp := global_position
	if _drag_layer == null:
		push_warning("CardView: drag layer missing — card will stay in hand")
	elif _hand_parent:
		_hand_parent.remove_child(self)
		_drag_layer.add_child(self)
		global_position = gp
	_dragging = true
	_set_hover(false)
	top_level = true
	z_as_relative = false
	z_index = 4096
	global_position = gp
	# Spring from where the card was — it trails the mouse instead of snapping to it.
	_drag_pos = gp
	_drag_vel = Vector2.ZERO
	juice()
	drag_started.emit(self)


func _end_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	# Keep top_level until table decides place vs return — otherwise the card can
	# vanish under mats for a frame (or forever if place FX is interrupted).
	dropped.emit(self, get_global_mouse_position())


func _restore_hand_parent() -> void:
	if _hand_parent == null or not is_instance_valid(_hand_parent):
		return
	if get_parent() == _hand_parent:
		return
	if get_parent():
		get_parent().remove_child(self)
	var idx := clampi(_hand_index, 0, _hand_parent.get_child_count())
	_hand_parent.add_child(self)
	_hand_parent.move_child(self, idx)
	position = Vector2.ZERO
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP


## Hold-drag: dx scrubs 0..SCRUB_END_SEC; at full window emit reveal_released.
func _handle_reveal_input(event: InputEvent) -> void:
	if not interactable:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_scrubbing = true
			_set_hover(false)
			_press_x = event.global_position.x
			_scrub_t = 0.0
			scrub_flip(0.0)
			accept_event()
		elif _scrubbing:
			_scrubbing = false
			reveal_released.emit(self, _scrub_t)
			accept_event()
	elif event is InputEventMouseMotion and _scrubbing:
		var dx: float = event.global_position.x - _press_x
		scrub_flip(scrub_t_from_mouse_dx(dx))
		reveal_scrub.emit(self, _scrub_t)
		_commit_reveal_if_scrub_complete()
		accept_event()


func _process(delta: float) -> void:
	if _dragging:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_end_drag()
		else:
			_step_drag(delta)
	elif _scrubbing:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_scrubbing = false
			reveal_released.emit(self, _scrub_t)
		else:
			var mdx: float = get_global_mouse_position().x - _press_x
			scrub_flip(scrub_t_from_mouse_dx(mdx))
			reveal_scrub.emit(self, _scrub_t)
			_commit_reveal_if_scrub_complete()
	elif _settling_face_up and _anim:
		if _anim.is_playing() or absf(_anim.get_playing_speed()) > 0.0:
			_anim_time = _anim.current_animation_position
		_sync_flip_layering(_anim_time)
		# If still marked settling but player is stuck paused mid-clip, kick it.
		if absf(_anim.get_playing_speed()) < 0.0001 and _anim_time < _flip_anim_length() - 0.02:
			_anim.play(FLIP_ANIM)
			_anim.seek(_anim_time, true)
			_anim.play()
	_update_visual(delta)


## Springy follow: the card trails the mouse and swings toward its direction of travel.
func _step_drag(delta: float) -> void:
	var target := get_global_mouse_position() - SIZE * 0.5
	var r := CardJuice.spring_v2(_drag_pos, _drag_vel, target, drag_spring_k, drag_spring_damping, delta)
	_drag_pos = r[0]
	_drag_vel = r[1]
	global_position = _drag_pos


func _flip_active() -> bool:
	return (
		_scrubbing
		or _settling_face_up
		or _place_flipping
		or (_abort_tween != null and is_instance_valid(_abort_tween) and _abort_tween.is_running())
	)


## Which sprite currently faces the viewer. Tilt only ever goes on this one — tilting the
## hidden face sprite could swing a sliver of it into view on a face-down card.
func visible_sprite_is_front() -> bool:
	return _anim_time >= FLIP_EDGE_SEC


## The only writer of sprite position/rotation/scale, shadow offset/alpha, and tilt.
func _update_visual(delta: float) -> void:
	if _card_back == null or _card_front == null:
		return
	_time += delta
	var flipping := _flip_active()
	var hovered := _hovering and not _dragging and not flipping

	var r := CardJuice.spring(_lift, _lift_v, -hover_lift if hovered else 0.0, spring_k, spring_damping, delta)
	_lift = r.x
	_lift_v = r.y
	r = CardJuice.spring(_hscale, _hscale_v, hover_scale if hovered else 1.0, spring_k, spring_damping, delta)
	_hscale = r.x
	_hscale_v = r.y

	var tilt_target := Vector2.ZERO
	if hovered and not _remote_hover:
		var n := (get_local_mouse_position() - SIZE * 0.5) / (SIZE * 0.5)
		n = n.clamp(Vector2(-1, -1), Vector2(1, 1))
		tilt_target = Vector2(n.y, -n.x) * tilt_max_deg
	var rt := CardJuice.spring_v2(_tilt, _tilt_v, tilt_target, spring_k, spring_damping, delta)
	_tilt = rt[0]
	_tilt_v = rt[1]

	var sway_target := 0.0
	if _dragging:
		sway_target = clampf(_drag_vel.x * sway_per_speed, -sway_max_deg, sway_max_deg)
	r = CardJuice.spring(_sway, _sway_v, sway_target, spring_k, spring_damping, delta)
	_sway = r.x
	_sway_v = r.y

	_idle_w = move_toward(_idle_w, 0.0 if (_dragging or flipping) else 1.0, delta * 3.0)
	var bob := idle_bob_px * sin(_time * idle_speed + _idle_phase) * _idle_w
	var rock := idle_rock_deg * sin(_time * idle_speed * 0.7 + _idle_phase * 1.3) * _idle_w

	_pop_t += delta
	var pop_s := CardJuice.pop(_pop_scale_amt, CardJuice.POP_SCALE_FREQ, _pop_t)
	var pop_r := CardJuice.pop(_pop_rot_amt, CardJuice.POP_ROT_FREQ, _pop_t)

	var flip_s := sin(clampf(_anim_time / _flip_anim_length(), 0.0, 1.0) * PI)
	if flip_s < 0.0001:
		flip_s = 0.0

	var shake_deg := 0.0
	var shake_px := 0.0
	if _shake_t > 0.0:
		_shake_t = maxf(_shake_t - delta, 0.0)
		var k := _shake_t / _shake_dur
		shake_deg = _shake_amp * k * sin(_time * 41.0)
		shake_px = 3.0 * k * sin(_time * 57.0)

	var present_px := present_height * present_lift_px
	var pos := REST_POS + Vector2(shake_px, _lift + bob - flip_s * flip_lift_px - present_px)
	var rot := deg_to_rad(_sway + rock + pop_r + shake_deg)
	var s := _hscale * (1.0 + pop_s) * (1.0 + flip_s * flip_scale)
	for spr in [_card_back, _card_front]:
		spr.position = pos
		spr.rotation = rot
		spr.scale = Vector2(s, s)

	var front_visible := visible_sprite_is_front()
	_set_tilt(_card_front, _tilt if front_visible else Vector2.ZERO)
	_set_tilt(_card_back, Vector2.ZERO if front_visible else _tilt)

	# Shadow drops further and fades as the card rises; drifts away from screen centre.
	var height := maxf(-(_lift - flip_s * flip_lift_px) + present_px, 0.0)
	var vp := get_viewport_rect().size
	var dx := 0.0
	if vp.x > 0.0:
		dx = (global_position.x + SIZE.x * 0.5 - vp.x * 0.5) / (vp.x * 0.5)
	var shadow_off := SHADOW_OFFSET + Vector2(dx * 6.0, height * 0.5)
	if _dragging:
		shadow_off += Vector2(dx * 6.0, 10.0)
	var a := shadow_alpha * clampf(1.0 - height / 60.0, 0.5, 1.0)
	for sh in [_shadow_back, _shadow_front]:
		if sh:
			sh.visible = true
			sh.position = shadow_off / maxf(s, 0.01)
			sh.modulate = Color(0, 0, 0, a)


func _set_tilt(spr: Sprite2D, t: Vector2) -> void:
	var mat := spr.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("tilt_x", t.x)
		mat.set_shader_parameter("tilt_y", t.y)
