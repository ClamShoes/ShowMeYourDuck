extends Control

var card = preload("res://Scenes/cardHeld.tscn")

var numberOfPlayedCards = 0
#numberOfPlayedCards.get_child_count()

var mouseInPlayable = false



func _on_mouse_entered() -> void:
	mouseInPlayable = true


func _on_mouse_exited() -> void:
	mouseInPlayable = false


func play_card() ->void:
	var played_card = get_child(get_child_count() - 1)
	played_card.reparent($DisplayedCards, false)
	
	#reparent to DisplayedCards, dont adopt global pos, 
	#play anim(flip) and move x + 100 + DisplayedCards.get_child_count() * 10
	
	
	
	#self.move_child(0).add_child(card)
	#numberOfPlayedCards = self.get_child_count()
	#self.get_child(0).get_child(0).show()
	#numberOfPlayedCards += 1
	print($DisplayedCards.get_child_count())
