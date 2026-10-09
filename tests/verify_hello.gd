extends SceneTree
## Needs a server already running on the default port (run_server.bat):
##   Godot --headless --path . -s res://tests/verify_hello.gd

var _done := false


func _initialize() -> void:
	var net = root.get_node("Net")
	net.lobby_updated.connect(func(code, _players, _host, _min):
		print("PASS  verify_hello (room %s)" % code)
		_finish(0))
	net.connection_failed.connect(func(msg):
		print("FAIL  verify_hello: %s" % msg)
		_finish(1))
	net.connect_and_create.call_deferred("Hello", {})
	create_timer(10.0).timeout.connect(func():
		print("FAIL  verify_hello: timed out")
		_finish(1))


func _finish(code: int) -> void:
	if _done:
		return
	_done = true
	quit(code)
