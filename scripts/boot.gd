extends Node

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--server" in args:
		var port := 9080
		var i := args.find("--port")
		if i != -1 and i + 1 < args.size():
			port = int(args[i + 1])
		Net.start_server(port)
		var label := Label.new()
		label.text = "Show me your duck — dedicated server on %s" % port
		label.position = Vector2(24, 24)
		add_child(label)
		return
	get_tree().change_scene_to_file.call_deferred("res://scenes/lobby.tscn")
