extends Container
#
#@onready var cardToHold = preload("res://Scenes/cardHeld.tscn")
#@onready var CardHolder = get_parent().get_parent().get_node("UI/CardHolder")
#@onready var PlayedCards = get_parent().get_parent().get_node("UI/PlayedCards")
#var startPosition
#var cardHover = false
var inHand = true
var burnt = false

@export var card_flipped = false   # could this be based on the anim rather than bool

#
## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
	# Ensure the material is unique for this card
	#self.get_node("cardBack").material = self.get_node("cardBack").material.duplicate()
	#self.get_node("cardBack2").material = self.get_node("cardBack2").material.duplicate()
#
#
## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass
#
#
#func _on_mouse_entered() -> void:
	#if inHand:				#TODO: Change to a state
		#print("Mouse entered")
		#$Anim.play("Select")
		#cardHover = true
#
#func _on_mouse_exited() -> void:
	#if inHand:				#TODO: Change to a state
		#$Anim.play("Deselect")
		#cardHover = false

#func _on_mouse_entered() -> void:
	#print("also yep")
	#self.get_node('Anim').play("Select")
		##card_hover = true
#
#func _on_mouse_exited() -> void:
	#self.get_node('Anim').play("Deselect")
				
func _on_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton) and (event.button_index == 1):
		if event.button_mask == 1:
			print("yep")
			#print(CardHolder)
			#if cardHover: 
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
			#cardHover = false
			#if CardHolder.get_child(0):
				#CardHolder.get_child(0).hide()
			#
