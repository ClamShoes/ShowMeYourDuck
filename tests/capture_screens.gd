extends SceneTree

## Windowed layout check for phone/tablet aspect ratios. Saves user://screens/<screen>_WxH.png for the
## lobby, duck editor, card picker, a 4-player table after everyone placed a card, the stamp picker,
## and the tutorial's first move and its Pass step.
## Run once per size, e.g.:
##   godot --path . --resolution 1600x720 --script tests/capture_screens.gd
## Sizes worth checking: 1280x720 (16:9), 1600x720 (20:9), 1560x720 (19.5:9), 1280x800 (16:10), 1280x960 (4:3).
const GameStateScript = preload("res://scripts/rules/game_state.gd")

var _tag := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# Autoload identifiers (Net) only resolve once the tree is up, so scenes load after a frame.
	await process_frame
	var win := DisplayServer.window_get_size()
	_tag = "%dx%d" % [win.x, win.y]
	DirAccess.make_dir_recursive_absolute("user://screens")
	var net = root.get_node("Net")

	var lobby = load("res://scenes/lobby.tscn").instantiate()
	root.add_child(lobby)
	await _save("lobby")
	lobby._open_editor()
	await _save("editor")
	lobby._editor.visible = false
	lobby._open_picker("back")
	await _save("picker")
	lobby.queue_free()

	var gs = GameStateScript.new()
	var ids := ["a", "b", "c", "d"]
	var infos := []
	for id in ids:
		infos.append({"id": id, "name": "Player %s" % id.to_upper()})
	gs.start_match(infos, "a")
	for id in ids:
		var hand: Array = gs.private_snapshot(id).you.hand
		gs.apply_intent(id, {"type": "place_card", "card_id": String(hand[0].id)})
	var snap: Dictionary = gs.private_snapshot("a")
	snap["you_are_host"] = true
	net.player_id = "a"
	net.last_snapshot = snap
	var table = load("res://scenes/table.tscn").instantiate()
	root.add_child(table)
	await _save("table")
	table._stamp_picker.open(["top_hat", "monocle", "cane"], null)
	await _save("stamp")
	table.queue_free()

	net.start_tutorial("You", {}, null)
	table = load("res://scenes/table.tscn").instantiate()
	root.add_child(table)
	net.tutorial.press_button()
	await _save("tutorial")
	var hand: Array = net.last_snapshot.you.hand
	for card in hand:
		if card.is_duck:
			net.submit_intent({"type": "place_card", "card_id": String(card.id)})
	for _i in 600:
		if net.tutorial.target() == "pass":
			break
		await process_frame
	await _save("tutorial_pass")
	print("saved screenshots to ", ProjectSettings.globalize_path("user://screens"))
	quit(0)


func _save(what: String) -> void:
	for _i in 40:
		await process_frame
	var path := "user://screens/%s_%s.png" % [what, _tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
