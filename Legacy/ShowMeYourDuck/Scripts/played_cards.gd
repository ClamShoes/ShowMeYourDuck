extends Control

var card_array = []
var self_center = self.global_position + (self.size / 4)

var number_of_played_cards = 0

var dothing = false
var dootherthing = false
var mouseInPlayable = false

var mex_start = 0
var mexlength = 200
var anim_locked = false #needs to be card specific and card_shown

func _ready() -> void:
	pass
	#for i in range(card_array.size()):
		#var card = card_array[i]
		#card.global_position.x = self.self_center.x + (i * 10)
		#card.global_position.y = self.self_center.y
	

func _process(delta: float) -> void:
	#self_center = self.global_position + (self.size / 4)
	for i in range(card_array.size()):
		var card = card_array[i]
		#print(card.global_position.x)
		#if not card.card_flipped and not dothing:
			#card.global_position.x = self.self_center.x + (i * 10)
			#card.global_position.y = self.self_center.y
	if dothing or dootherthing:
		flip_card()
	#if card_array.size() > 0:
		#var card = card_array[card_array.size() - 1]
		#if dothing and not card.card_flipped:
			#var card_anim = card.get_node('Anim')
			#if card_anim.current_animation != "Card_Flip":
				#card_anim.play("Card_Flip")						#This needs to reverse back to start and then stop playing
			#var anim_length = card_anim.get_animation("Card_Flip").length
			## Calculate percentage of mouse position along mexlength
			#var mouse_x = clamp(get_global_mouse_position().x, mex_start, mex_start + mexlength)
			#var progress = (mouse_x - mex_start) / mexlength
			#if progress < .5:
			## Map progress to animation time
				#var anim_time = progress * anim_length
				#card_anim.seek(anim_time, true)
				#card.position.x = global_position.x + (progress*10)
			#else:
				##card_anim.play("Card_Flip")
				#card.card_flipped = true
				#dothing = false
				#card_array.pop_back()
				

	# Map mouse x to animation progress (0 to animation length)
	
	

	# Seek the animation to the mapped time
	
#var card = preload("res://Scenes/cardHeld.tscn")

#var number_of_played_cards = 0
#numberOfPlayedCards.get_child_count()



func _on_mouse_entered() -> void:
	mouseInPlayable = true


func _on_mouse_exited() -> void:
	mouseInPlayable = false

func play_card(card) ->void:
	card_array.append(card)
	number_of_played_cards = card_array.size()
	card.global_position.x = 250 + (number_of_played_cards * 10)
	card.global_position.y = 250
	card.get_node('Anim').play("Deselect")
	#card.global_position.x = self.global_position.x + (number_of_played_cards * 10)
	#card.global_position.y = self.global_position.y
	

func _on_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton) and (event.button_index == 1):
		if event.button_mask == 1:
			if card_array.size() > 0:
				mex_start = get_global_mouse_position().x
				dothing = true
		if event.button_mask == 0:
			if dothing:
				dootherthing = true	
				dothing = false
			


func flip_card():
	if card_array.size() > 0:
		var card = card_array[card_array.size() - 1]
		if not card.card_flipped:
			var card_anim = card.get_node('Anim')
			if card_anim.current_animation != "Card_Flip":
				card_anim.play("Card_Flip")						#This needs to reverse back to start and then stop playing
			var anim_length = card_anim.get_animation("Card_Flip").length
			# Calculate percentage of mouse position along mexlength
			var mouse_x = clamp(get_global_mouse_position().x, mex_start, mex_start + mexlength)
			var progress = (mouse_x - mex_start) / mexlength
			if progress < .5 and not dootherthing:
			# Map progress to animation time
				var anim_time = progress * anim_length
				card_anim.seek(anim_time, true)
				
				#card.global_position.x = 250 + (number_of_played_cards * 10) + (progress*350) #change to progress of "Card_Flip"/change anim to include + x?<<do that
			elif progress < .5 and dootherthing:
				card_anim.play_backwards("Card_Flip")
				dootherthing = false
				dothing = false
			elif progress > .5 and dootherthing:
				dothing = false
				dootherthing = false
				card_array.pop_back()
				#card_anim.play("Card_Flip")
				#card.card_flipped = true
				






#func play_card() ->void:
	#var played_card = get_child(get_child_count() - 1)
	#played_card.reparent($DisplayedCards, false)
	#
	##reparent to DisplayedCards, dont adopt global pos, 
	##play anim(flip) and move x + 100 + DisplayedCards.get_child_count() * 10
	#
	#
	#
	##self.move_child(0).add_child(card)
	##numberOfPlayedCards = self.get_child_count()
	##self.get_child(0).get_child(0).show()
	##number_of_played_cards += 1
	#print($DisplayedCards.get_child_count())
