extends Node

const GameTypes = preload("res://scripts/rules/types.gd")

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--server" in args:
		var port := 9080
		var i := args.find("--port")
		if i != -1 and i + 1 < args.size():
			port = int(args[i + 1])
		# Live server runs with `--min-players 3`; local servers default to solo-friendly 1.
		var min_players := GameTypes.MIN_PLAYERS
		var m := args.find("--min-players")
		if m != -1 and m + 1 < args.size():
			min_players = clampi(int(args[m + 1]), GameTypes.MIN_PLAYERS, GameTypes.MAX_PLAYERS)
		Net.start_server(port, min_players)
		var label := Label.new()
		label.text = "Show me your duck — dedicated server on %s" % port
		label.position = Vector2(24, 24)
		add_child(label)
		return
	get_tree().change_scene_to_file.call_deferred("res://scenes/lobby.tscn")
