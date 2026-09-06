extends SceneTree

func _init() -> void:
	var paths := [
		"res://scripts/rules/types.gd",
		"res://scripts/rules/game_state.gd",
		"res://scripts/net/protocol.gd",
		"res://scripts/net/server.gd",
		"res://scripts/net/net.gd",
		"res://scripts/ui/card_view.gd",
		"res://scripts/ui/player_mat.gd",
		"res://scripts/ui/lobby.gd",
		"res://scripts/ui/table.gd",
		"res://scripts/boot.gd",
	]
	var failed := 0
	for p in paths:
		var script: Script = load(p)
		if script == null:
			print("FAIL  load ", p)
			failed += 1
		else:
			print("PASS  load ", p)
	quit(1 if failed else 0)
