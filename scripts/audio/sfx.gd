extends Node
## Sound effects + the saved master volume. Autoloaded as "Sfx". Other scripts call the static
## helpers through a preload (`const Sounds = preload("res://scripts/audio/sfx.gd")`,
## `Sounds.play("card_place")`) so scripts tested without the autoload stay silent instead of erroring.
## Files: assets/sounds/<name>.ogg or .wav (placeholders from tests/gen_sounds.gd; record over them).

const DIR := "res://assets/sounds/"
const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_VOLUME := 0.8
const POOL_SIZE := 8
## Every sound the game plays. tests/run_tests.gd checks each has a file.
const NAMES := [
	"card_hover", "card_pickup", "card_return", "card_place",
	"card_flip", "reveal_safe", "reveal_duck", "cards_collect",
	"discard_present", "discard_explode", "discard_burn", "discard_rip", "discard_samurai",
	"your_turn", "bid", "pass", "challenge_start", "point_scored", "player_out",
	"round_start", "game_win", "game_over",
	"stamp_offer", "stamp_place",
	"ui_click", "player_join",
]
## Short, frequent sounds get a little random pitch so repeats don't sound robotic.
const VARY_PITCH := ["card_hover", "card_pickup", "card_return", "card_place", "card_flip", "bid", "pass", "ui_click"]

## Overridable so tests don't touch the real settings.
static var path := SETTINGS_PATH

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply(load_settings())
	if DisplayServer.get_name() == "headless":
		return
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	get_tree().node_added.connect(_on_node_added)


static func play(sound: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var node = tree.root.get_node_or_null("Sfx") if tree else null
	if node != null:
		node._play(sound)


## {volume: 0..1, muted: bool}
static func load_settings() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(path)
	return {
		volume = clampf(float(cfg.get_value("audio", "volume", DEFAULT_VOLUME)), 0.0, 1.0),
		muted = bool(cfg.get_value("audio", "muted", false)),
	}


static func set_volume(v: float) -> void:
	var s := load_settings()
	s.volume = clampf(v, 0.0, 1.0)
	_save(s)


static func set_muted(on: bool) -> void:
	var s := load_settings()
	s.muted = on
	_save(s)


static func _save(s: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value("audio", "volume", s.volume)
	cfg.set_value("audio", "muted", s.muted)
	cfg.save(path)
	_apply(s)


static func _apply(s: Dictionary) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(s.volume))
	AudioServer.set_bus_mute(0, s.muted)


func _play(sound: String) -> void:
	if _players.is_empty():
		return
	var stream: AudioStream = _stream(sound)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = randf_range(0.94, 1.06) if sound in VARY_PITCH else 1.0
	p.play()


func _stream(sound: String) -> AudioStream:
	if not _cache.has(sound):
		var s: AudioStream = null
		for ext in [".ogg", ".wav"]:
			if ResourceLoader.exists(DIR + sound + ext):
				s = load(DIR + sound + ext)
				break
		if s == null:
			push_warning("Sfx: no file for sound '%s' in %s" % [sound, DIR])
		_cache[sound] = s
	return _cache[sound]


func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		n.pressed.connect(_play.bind("ui_click"))
