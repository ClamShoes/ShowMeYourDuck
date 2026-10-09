extends Control

## Centre row of the challenger's cards (server-shuffled slots) while the Duck's owner picks one
## to destroy. Challenger sees their faces; everyone else sees backs. Only the chooser can click.
signal hovered(slot: int)
signal picked(slot: int)

const CardScene = preload("res://scenes/card.tscn")

const ROW_SCALE := 1.3
const GAP := 24.0
const ENTER_SEC := 0.3
const ENTER_STAGGER := 0.06

## Rebuild key (challenger|chooser|slots) so the table only rebuilds when the pick changes.
var key := ""
var _cards: Array = []
var _hover_slot := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func build(snap: Dictionary, viewer: String) -> void:
	var challenger := String(snap.challenger_id)
	var is_chooser := String(snap.discard_chooser_id) == viewer
	var faces: Array = snap.get("discard_slot_faces", [])
	var n := int(snap.discard_slots)
	var vp := get_viewport_rect().size
	var step := CardView.SIZE.x * ROW_SCALE + GAP
	var x0 := vp.x * 0.5 - step * (n - 1) * 0.5
	for i in n:
		var card = CardScene.instantiate()
		add_child(card)
		var face: Dictionary = faces[i] if i < faces.size() else {}
		card.setup(String(face.get("id", "")), bool(face.get("is_duck", false)), not face.is_empty(), is_chooser, false, challenger)
		card.position = Vector2(x0 + step * i, vp.y * 0.5) - CardView.SIZE * 0.5
		card.scale = Vector2.ONE * 0.2
		var tw := card.create_tween()
		tw.tween_interval(ENTER_STAGGER * i)
		tw.tween_property(card, "scale", Vector2.ONE * ROW_SCALE, ENTER_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if is_chooser:
			card.mouse_entered.connect(func(): hovered.emit(i))
			card.mouse_exited.connect(func(): hovered.emit(-1))
			card.pressed.connect(func(_c): _on_pressed(i))
		else:
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cards.append(card)


func slot_count() -> int:
	return _cards.size()


func card_at(slot: int):
	return _cards[slot] if slot >= 0 and slot < _cards.size() else null


## Mirror the chooser's hover on this screen.
func set_remote_hover(slot: int) -> void:
	_hover_slot = slot
	for i in _cards.size():
		if _cards[i] != null:
			_cards[i].set_remote_hover(i == slot)


## Chooser's pointer (global, this screen): the hovered card leans toward it.
func set_remote_point(p: Vector2) -> void:
	var card = card_at(_hover_slot)
	if card != null:
		card.set_remote_point(p)


## Detach a slot's card (for the destroy FX) so freeing the row doesn't take it with it.
func take(slot: int):
	var card = card_at(slot)
	if card == null:
		return null
	_cards[slot] = null
	card.interactable = false
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


func _on_pressed(slot: int) -> void:
	for c in _cards:
		if c != null:
			c.interactable = false
	picked.emit(slot)
