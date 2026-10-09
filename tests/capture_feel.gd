extends SceneTree

## Windowed visual check (shaders don't draw headless). Saves user://capture_feel.png:
## two mats with fanned stacks + a revealed card, then hand cards: idle, hover-tilted toward the
## top-right corner, mid-flip lift, edge-on, and drag sway.
## Run: godot --path . --script tests/capture_feel.gd
const CardScene = preload("res://scenes/card.tscn")
const PlayerMatScript = preload("res://scripts/ui/player_mat.gd")
const CardArt = preload("res://scripts/ui/card_art.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	CardArt.set_players([
		{"id": "a", "card_back_id": "crimson", "card_front_id": "bordered"},
		{"id": "b", "card_back_id": "sapphire", "card_front_id": "gilded"},
	])
	var root := Control.new()
	root.size = Vector2(1280, 720)
	get_root().add_child(root)
	var bg := ColorRect.new()
	bg.color = Color("0f2e2c")
	bg.size = root.size
	root.add_child(bg)

	var mat_a = PlayerMatScript.new()
	root.add_child(mat_a)
	mat_a.position = Vector2(40, 40)
	mat_a.setup("a", Color("e76f51"))
	mat_a.refresh(_info("Alice", 4))

	var mat_b = PlayerMatScript.new()
	root.add_child(mat_b)
	mat_b.position = Vector2(300, 40)
	mat_b.setup("b", Color("2a9d8f"))
	mat_b.refresh(_info("Bob", 2))
	mat_b.sync_parked_reveals([{"card_id": "b_duck", "owner_id": "b", "target_player_id": "b", "is_duck": true}])

	var cards: Array = []
	for i in 5:
		var c: CardView = CardScene.instantiate()
		root.add_child(c)
		c.position = Vector2(60 + i * 160, 380)
		c.set_process(false)
		c.idle_bob_px = 0.0
		c.idle_rock_deg = 0.0
		c.setup("a_safe_%d" % i, i == 1, true, true, false, "a")
		cards.append(c)

	# 1: hover pose frozen with the mouse at the card's top-right corner.
	var hov: CardView = cards[1]
	hov._hovering = true
	hov._lift = -hov.hover_lift
	hov._hscale = hov.hover_scale
	hov._tilt = Vector2(-1.0, -1.0) * hov.tilt_max_deg
	hov.spring_k = 0.0
	# 2 / 3: face-down token mid-scrub and edge-on (lift peaks at edge-on).
	for k in [2, 3]:
		var t: CardView = cards[k]
		t.setup_stack_token(false, "b")
		t.scrub_flip(0.5 if k == 2 else 1.0)
	# 4: dragging right fast — sway into the motion.
	var drag: CardView = cards[4]
	drag._dragging = true
	drag._drag_vel = Vector2(900, 0)
	for c in cards:
		for _i in 30:
			c._update_visual(1.0 / 60.0)

	for _i in 6:
		await process_frame
	var img := get_root().get_texture().get_image()
	var out := "user://capture_feel.png"
	img.save_png(out)
	print("saved ", ProjectSettings.globalize_path(out))
	quit(0)


func _info(name: String, stack: int) -> Dictionary:
	return {"name": name, "points": 0, "hand_count": 4 - stack, "stack_count": stack, "passed": false, "eliminated": false}
