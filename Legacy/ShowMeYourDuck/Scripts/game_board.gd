extends Node

var card_held = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func grab_card(card):
	card_held = card
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
func drop_card():
	card_held = null
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
