#extends Control
#
#@onready var cardToHold = preload("res://Scenes/cardHeld.tscn")
#@onready var CardHolder = get_parent().get_parent().get_node("UI/CardHolder")
#@onready var PlayedCards = get_parent().get_parent().get_node("UI/PlayedCards")
#
#
#var card_hover = false
##Getter/setter needed??
#var card
 #
##TODO: add a var for the card in the card slot
## ?? Pin the location of the card here??
## card anims for this to be played from here
## alter _on_gui_input to apply to the card
##  remove logic from card
##  remove cardHeld / remove sprite for card held change logic to actual card
#
## Called when the node enters the scene tree for the first time.
#func _ready() -> void:
	#pass # Replace with function body.
## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass
#
#
#
#
#
#
#
#func _on_mouse_entered() -> void:
	##if inHand:				#TODO: Change to a state
	#print("Mouse entered")
	#card.get_node('Anim').play("Select")
	#card_hover = true
#
#func _on_mouse_exited() -> void:
	##if inHand:				#TODO: Change to a state
	#card.get_node('Anim').play("Deselect")
	#card_hover = false
#
#func _on_gui_input(event: InputEvent) -> void:
	#if (event is InputEventMouseButton) and (event.button_index == 1):
		#if event.button_mask == 1:
			#print(CardHolder)
			#if card_hover: 
				##var cardHeld = cardToHold.instantiate()
				##CardHolder.add_child(cardHeld)
				#CardHolder.get_child(0).show()
				#self.get_child(0).hide()
				##cardSelected = true
		#elif event.button_mask == 0:
			#if PlayedCards.mouseInPlayable:
				#self.reparent(PlayedCards, false)
				#self.global_position.x += PlayedCards.get_child_count()*10
				##print(PlayedCards.numberOfPlayedCards)
				#self.get_child(0).show()
				#inHand = false
				##%PlayedCards.play_card(self)
				##self.queue_free()
			#else:
				#self.get_child(0).show()
			#card_hover = false
			#if CardHolder.get_child(0):
				#CardHolder.get_child(0).hide()
			#
