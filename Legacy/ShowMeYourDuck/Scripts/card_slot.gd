extends Control
#
#@onready var cardToHold = preload("res://Scenes/cardHeld.tscn")
#@onready var CardHolder = get_parent().get_parent().get_node("UI/CardHolder")
@onready var PlayedCards = get_parent().get_parent().get_parent().get_node("PlayedCards")
#
@export var max_offset_shadow_x: int = 20
@export var max_offset_shadow_y: int = 20

@onready var card_hover = false
@onready var card_held = false
##Getter/setter needed??
@onready var pinned_card = null
 
@onready var GameBoard = get_tree().root.get_child(0)


#Shadow vars
@onready var shadow = null
@onready var center: Vector2 = get_viewport_rect().size / 2.0
@onready var bottom: Vector2 = get_viewport_rect().size

@onready var distance_x: float = 0.0
@onready var distance_y: float = 0.0

var stuipd_count = 1


##TODO: add a var for the card in the card slot
## ?? Pin the location of the card here??
## card anims for this to be played from here
## alter _on_gui_input to apply to the card
##  remove logic from card
##  remove cardHeld / remove sprite for card held change logic to actual card
#
## Called when the node enters the scene tree for the first time.
#func _ready() -> void:
	#print()


	#pass # Replace with function body.
## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	handle_shadow(delta)
	if pinned_card:
		if not pinned_card_held():
			pinned_card.global_position = self.global_position
		if pinned_card_held():
			pinned_card.global_position = get_global_mouse_position()
				
		## Rearange cards
			if get_global_mouse_position().y > 462:  #TODO: This needs to be absolute or an area for diff screen sizes??
				for slot in get_parent().get_children():
					if pinned_card.global_position.x > slot.global_position.x:
						#print(self.get_index(), slot.get_index())
						if self.get_index() < slot.get_index():
							slot.pinned_card.get_node('Anim').play("Quiver")
							get_parent().move_child(self, slot.get_index())
							break
					elif pinned_card.global_position.x < slot.global_position.x:
						#print(self.get_index(), slot.get_index())
						if self.get_index() > slot.get_index():
							slot.pinned_card.get_node('Anim').play("Quiver")
							get_parent().move_child(self, slot.get_index())
							break

func pin_card(card):
	pinned_card = card
	#self.z_index = 0
	#pinned_card.z_index = -10
	#pinned_card.z_as_relative = true
	shadow = pinned_card.get_node('cardBack').get_node('shadow')

func unpin_card():
	var card = pinned_card #(shitty)attempt to sort out order of operation during playing a card
	pinned_card = null
	return card
	
func pinned_card_held():
	return GameBoard.card_held == pinned_card

func _on_mouse_entered() -> void:
	if not GameBoard.card_held:
		pinned_card.get_node('Anim').play("Select")
		card_hover = true

func _on_mouse_exited() -> void:
	if not pinned_card_held() and card_hover:
		card_hover = false
		pinned_card.get_node('Anim').play("Deselect")


func _on_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton) and (event.button_index == 1):
		if event.button_mask == 1:
			if card_hover: 
				GameBoard.grab_card(pinned_card)
		elif event.button_mask == 0:
			if PlayedCards.mouseInPlayable:
				print("attempt queue free")
				GameBoard.drop_card()
				PlayedCards.play_card(unpin_card())
				self.queue_free()
				
				
			else:
				pinned_card.get_node('Anim').play("Deselect")
				pinned_card.global_position = self.global_position
				GameBoard.drop_card()
			card_hover = false
	
func handle_shadow(delta) -> void:
	#var center: Vector2 = get_viewport_rect().size / 2.0
	#var bottom: Vector2 = get_viewport_rect().size

	distance_x = shadow.global_position.x - center.x
	distance_y = shadow.global_position.y - bottom.y
	shadow.position.x = lerp(0.0, -sign(distance_x) * max_offset_shadow_x, abs(distance_x/(center.x)))
	shadow.position.y = lerp(0.0, -sign(distance_y) * max_offset_shadow_y, abs(distance_y/(center.y)))
	#change shadow local pos
	#anim shadow from dark to light and from small to bigger on card lift
	#alter max shadow offset from 0 to x
	
	
func rotate_on_move():
	
	pass
