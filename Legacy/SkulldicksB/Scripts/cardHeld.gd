extends Container

var max_offset_shadow: int = 20 
#var shadow = get_child(1)  
#TODO: 	Something like this on_create()?? --- @onready
#		State management in each node location eg. hand, played, shown etc.
#		Handle card hand off in the state - add to_state(card): card.reparent(self)
#		Can then tween to location in same function
#		Cards in Card node and stay there, no reparenting


func _process(delta):
	self.global_position = get_global_mouse_position()
	handle_shadow(delta)
	
func handle_shadow(delta) -> void:
	var shadow = self.get_child(0).get_child(0)
	var center: Vector2 = get_viewport_rect().size / 2.0
	var bottom: Vector2 = get_viewport_rect().size
	
	var distance_x: float = self.global_position.x - center.x
	var distance_y: float = self.global_position.y - bottom.y
	
	shadow.position.x = lerp(0.0, -sign(distance_x) * max_offset_shadow, abs(distance_x/(center.x)))
	shadow.position.y = lerp(0.0, -sign(distance_y) * max_offset_shadow, abs(distance_y/(center.y)))

func rotate_on_move():
	
	pass
	
	
	
	
#	Copied CODE

#@export var angle_x_max: float = 15.0
#@export var angle_y_max: float = 15.0
#@export var max_offset_shadow: float = 50.0
#
#@export_category("Oscillator")
#@export var spring: float = 150.0
#@export var damp: float = 10.0
#@export var velocity_multiplier: float = 2.0
#
#var displacement: float = 0.0 
#var oscillator_velocity: float = 0.0
#
#var tween_rot: Tween
#var tween_hover: Tween
#var tween_destroy: Tween
#var tween_handle: Tween
#
#var last_mouse_pos: Vector2
#var mouse_velocity: Vector2
#var following_mouse: bool = false
#var last_pos: Vector2
#var velocity: Vector2
#
#@onready var card_texture: TextureRect = $CardTexture
#@onready var shadow = $Shadow
#@onready var collision_shape = $DestroyArea/CollisionShape2D
#
#






#func rotate_velocity(delta: float) -> void:
	#if not following_mouse: return
	#var center_pos: Vector2 = global_position - (size/2.0)
	#print("Pos: ", center_pos)
	#print("Pos: ", last_pos)
	## Compute the velocity
	#velocity = (position - last_pos) / delta
	#last_pos = position
	#
	#print("Velocity: ", velocity)
	#oscillator_velocity += velocity.normalized().x * velocity_multiplier
	#
	## Oscillator stuff
	#var force = -spring * displacement - damp * oscillator_velocity
	#oscillator_velocity += force * delta
	#displacement += oscillator_velocity * delta
	#
	#rotation = displacement
#
#func handle_shadow(delta: float) -> void:
	## Y position is enver changed.
	## Only x changes depending on how far we are from the center of the screen
	#var center: Vector2 = get_viewport_rect().size / 2.0
	#var distance: float = global_position.x - center.x
	#
	#shadow.position.x = lerp(0.0, -sign(distance) * max_offset_shadow, abs(distance/(center.x)))
#
#func follow_mouse(delta: float) -> void:
	#if not following_mouse: return
	#var mouse_pos: Vector2 = get_global_mouse_position()
	#global_position = mouse_pos - (size/2.0)
#
#func handle_mouse_click(event: InputEvent) -> void:
	#if not event is InputEventMouseButton: return
	#if event.button_index != MOUSE_BUTTON_LEFT: return
	#
	#if event.is_pressed():
		#following_mouse = true
	#else:
		## drop card
		#following_mouse = false
		#collision_shape.set_deferred("disabled", false)
		#if tween_handle and tween_handle.is_running():
			#tween_handle.kill()
		#tween_handle = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		#tween_handle.tween_property(self, "rotation", 0.0, 0.3)
