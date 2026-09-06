extends Node

var MAX_CARDS: int = 4 
@onready var Hand = get_parent().get_node("UI/CenterContainer/Hand")
@onready var cards = [$Skull,%Card2,%Card3,%Card4]

# Called when the node enters the scene tree for the first time.
#func _ready() -> void:
	#for i in MAX_CARDS:
		#var new_card = card.instantiate()
		#add_child(new_card)


func deal_cards():
	for card in cards:
		if not card.burnt:
			card.inHand = true
			card.reparent(%Hand, false)
			#Hand.add_to_hand(card)
		#var position = Hand.add_to_hand()
		#print(position)
		#card.global_position = position


func _on_button_pressed() -> void:
	print("Dealing Cards")
	deal_cards()
