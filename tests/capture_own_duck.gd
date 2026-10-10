extends SceneTree

## Windowed visual check of the own-Duck return: p0 flips its own Duck, the card rests on the mat,
## then flies back to p0's hand before p0 chooses a discard. Saves user://capture_own_duck_<stage>.png
## for pause / flight / landed. Run: godot --path . -s res://tests/capture_own_duck.gd
const GameStateScript = preload("res://scripts/rules/game_state.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for _i in 3:
		await process_frame
	var net = get_root().get_node("Net")
	var gs = GameStateScript.new()
	gs.start_match([
		{"id": "p0", "name": "P0", "cosmetics": {}},
		{"id": "p1", "name": "P1", "cosmetics": {}},
		{"id": "p2", "name": "P2", "cosmetics": {}},
	], "p0")
	gs.place_card("p0", "p0_duck")
	for pid in ["p1", "p2"]:
		gs.place_card(pid, String(gs.players[pid].hand[0]))
	gs.open_bid("p0", 1)
	gs.pass_bid("p1")
	gs.pass_bid("p2")
	net.player_id = "p0"
	net.last_snapshot = gs.private_snapshot("p0")
	var table = load("res://scenes/table.tscn").instantiate()
	get_root().add_child(table)
	await create_timer(0.5).timeout
	gs.flip_stack("p0", "p0")
	net.last_snapshot = gs.private_snapshot("p0")
	net.match_updated.emit(net.last_snapshot)
	var shown := func() -> String:
		return ", ".join(table._hand_box.get_children().map(func(c): return "%s a=%.1f" % [c.get("card_id"), c.modulate.a]))
	while table._reveals_in_flight() > 0:
		await process_frame
	await create_timer(0.3).timeout
	print("pause: returning=", table._returning, " pending=", table._flight_pending.keys(), " hand=", shown.call())
	_save("user://capture_own_duck_pause.png")
	while not table._returning.values().has(table.Return.FLYING):
		await process_frame
	await create_timer(0.2).timeout
	_save("user://capture_own_duck_flight.png")
	print("flight: discard taps blocked=", not table._flight_pending.is_empty(), " hand=", shown.call())
	await create_timer(1.5).timeout
	print("landed: returning=", table._returning, " pending=", table._flight_pending.keys(), " hand shown=", shown.call())
	_save("user://capture_own_duck_landed.png")
	quit(0)


func _save(out: String) -> void:
	var size: Vector2 = get_root().get_visible_rect().size
	out = out.replace(".png", "_%dx%d.png" % [size.x, size.y])
	get_root().get_texture().get_image().save_png(out)
	print("saved ", ProjectSettings.globalize_path(out))
