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


func add_to_hand() -> void:
	print(%CardSlot1, %CardSlot2, %CardSlot3, %CardSlot4)
	#reparent(card, false)

	#var new_slot = card_slot.instantiate()
	#add_child(new_slot)
	#return new_slot.global_position


func _on_button_2_pressed() -> void:
	%PlayedCards.play_card()
