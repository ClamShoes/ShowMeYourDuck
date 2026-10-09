extends SceneTree

## Windowed visual check of opponent hands + mirrored hand fx + remote cursors, driven by fake
## relay events on a real GameState. Saves user://capture_opp_hands_<n>p[_flight|_after].png and
## prints hand counts / token visibility. Run: godot --path . -s res://tests/capture_opp_hands.gd -- --n=4
const GameStateScript = preload("res://scripts/rules/game_state.gd")
const SeatSpace = preload("res://scripts/ui/seat_space.gd")

var _n := 4


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="):
			_n = int(a.get_slice("=", 1))
	call_deferred("_run")


func _run() -> void:
	for _i in 3:
		await process_frame
	var net = get_root().get_node("Net")
	var gs = GameStateScript.new()
	var infos: Array = []
	for i in _n:
		infos.append({"id": "p%d" % i, "name": "P%d" % i, "cosmetics": {}})
	gs.start_match(infos, "p0")
	for i in _n:
		var pid := "p%d" % i
		gs.place_card(pid, String(gs.players[pid].hand[0]))
	net.player_id = "p0"
	net.last_snapshot = gs.private_snapshot("p0")
	var table = load("res://scenes/table.tscn").instantiate()
	get_root().add_child(table)
	for _i in 5:
		await process_frame
	var x0 := (SeatSpace.HAND_SIZE.x - (3 * 96 + 2 * 4.0)) * 0.5
	var slot_mid := func(s: int) -> Vector2: return Vector2(x0 + 48 + s * 100, 75)
	# p1 hovers slot 1 with the pointer at the card's top-right.
	net.hand_fx.emit("p1", {"t": "hover", "slot": 1})
	net.cursor_moved.emit("p1", "hand:p1", slot_mid.call(1) + Vector2(40, -50))
	# p2 picks up slot 0 and drags it toward its mat, gap moves to 2.
	net.hand_fx.emit("p2", {"t": "drag", "slot": 0})
	net.hand_fx.emit("p2", {"t": "gap", "slot": 2})
	net.cursor_moved.emit("p2", "mat:p2", Vector2(105, 120))
	if _n > 3:
		net.hand_fx.emit("p3", {"t": "hover", "slot": 0})
		net.cursor_moved.emit("p3", "hand:p3", slot_mid.call(0) + Vector2(-40, -50))
	await create_timer(0.8).timeout
	_save("user://capture_opp_hands_%dp.png" % _n)
	# p2 drops on its mat (place before the snapshot, like the real relay); p1 drags and returns.
	net.hand_fx.emit("p2", {"t": "place", "slot": -1})
	net.hand_fx.emit("p1", {"t": "drag", "slot": 2})
	net.cursor_moved.emit("p1", "mat:p1", Vector2(100, 60))
	await create_timer(0.15).timeout
	_save("user://capture_opp_hands_%dp_flight.png" % _n)
	# Simulate p2's accepted place arriving in the snapshot.
	gs.current_player_id = "p2"
	gs.place_card("p2", String(gs.players["p2"].hand[0]))
	net.last_snapshot = gs.private_snapshot("p0")
	net.match_updated.emit(net.last_snapshot)
	net.hand_fx.emit("p1", {"t": "drop", "slot": 0})
	await process_frame
	await process_frame
	var tok = table._mats["p2"].stack_token(1)
	print("p2 token hidden mid-flight=", tok != null and not tok.visible)
	await create_timer(1.0).timeout
	var table_hands: Dictionary = table._opp_hands
	for pid in table_hands:
		print(pid, " hand cards shown=", table_hands[pid]._cards().size(), " snapshot=", gs.players[pid].hand.size())
	print("p2 stack tokens visible=", table._mats["p2"].stack_token(1).visible if table._mats["p2"].stack_token(1) else "none")
	_save("user://capture_opp_hands_%dp_after.png" % _n)
	quit(0)


func _save(out: String) -> void:
	get_root().get_texture().get_image().save_png(out)
	print("saved ", ProjectSettings.globalize_path(out))
