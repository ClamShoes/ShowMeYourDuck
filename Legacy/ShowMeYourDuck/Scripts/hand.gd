extends HBoxContainer

var card_slot = preload("res://Scenes/card_slot.tscn")

@onready var played_cards = %PlayedCards


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_mouse_entered() -> void:
	pass # Replace with function body.


func _on_mouse_exited() -> void:
	pass # Replace with function body.


func add_to_hand(card):
	var new_slot = card_slot.instantiate()
	add_child(new_slot)
	new_slot.pin_card(card)
	#
	#call_deferred("_deferred_pin_card", new_slot, card)
#
#func _deferred_pin_card(new_slot, card):
	#call_deferred("_deferred_pin_card2", new_slot, card)
#
#func _deferred_pin_card2(new_slot, card):
	#new_slot.pin_card(card)


func _on_button_2_pressed() -> void:
	for card in %PlayedCards.card_array:
		print(card.global_position.x)
