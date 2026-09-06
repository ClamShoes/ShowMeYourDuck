extends Node

var MAX_CARDS: int = 4 

@onready var card_slot = preload("res://Scenes/card_slot.tscn")
@onready var Hand = get_parent().get_node("UI/CenterContainer/Hand")
@onready var cards = [$Skull,%Card2,%Card3,%Card4]
@onready var played_cards = get_parent().get_node("UI/PlayedCards")

# Called when the node enters the scene tree for the first time.
#func _ready() -> void:
	#for i in MAX_CARDS:
		#var new_card = card.instantiate()
		#add_child(new_card)


func deal_cards():
	for child in Hand.get_children():
		child.queue_free()
	played_cards.card_array.clear()
		
	for card in cards:
		if not card.burnt:
			#card.card_flipped = false
			card.inHand = true
			Hand.add_to_hand(card)
			card.get_node('Anim').play("Deselect")
			#card.get_node('Anim').play("RESET")
			
			

	#var new_slot = card_slot.instantiate()
	#add_child(new_slot)
	
	
	
			#Hand.add_to_hand(card)
		#var position = Hand.add_to_hand(card)
		#print(position)
		#card.global_position = position


func _on_button_pressed() -> void:
	print("Dealing Cards")
	deal_cards()
