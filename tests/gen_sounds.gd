extends SceneTree

## Generates rough synthesized placeholder sounds into assets/sounds/ (one per Sounds.NAMES entry).
## Never overwrites an existing file, so recordings saved over a placeholder are safe; delete a
## file to regenerate it. Then import: godot --headless --path . --import
## Run: godot --headless --path . --script tests/gen_sounds.gd

const Sounds = preload("res://scripts/audio/sfx.gd")
const RATE := 22050

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 7
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Sounds.DIR))
	var made := 0
	for sound in Sounds.NAMES:
		var file := ProjectSettings.globalize_path(Sounds.DIR + sound + ".wav")
		if FileAccess.file_exists(file) or FileAccess.file_exists(file.get_basename() + ".ogg"):
			continue
		var buf: PackedFloat32Array = call("_" + sound)
		_wav(buf).save_to_wav(file)
		made += 1
	print("Wrote %d placeholder sounds to %s" % [made, Sounds.DIR])
	quit(0)


func _card_hover() -> PackedFloat32Array:
	return _noise(0.035, 0.2, 0.7)

func _card_pickup() -> PackedFloat32Array:
	return _mix([_noise(0.06, 0.3, 0.5), _tone(600, 900, 0.07, 0.15)])

func _card_return() -> PackedFloat32Array:
	return _mix([_noise(0.09, 0.25, 0.3), _tone(500, 300, 0.08, 0.12)])

func _card_place() -> PackedFloat32Array:
	return _mix([_noise(0.08, 0.5, 0.15), _tone(140, 60, 0.12, 0.5)])

func _card_flip() -> PackedFloat32Array:
	return _swell(_noise(0.18, 0.35, 0.6, false))

func _reveal_safe() -> PackedFloat32Array:
	return _notes([660, 880], 0.14, 0.3)

func _reveal_duck() -> PackedFloat32Array:
	var quack := _tone(320, 200, 0.18, 0.4, "square")
	return _mix([quack, _offset(quack, 0.22), _offset(_tone(110, 70, 0.6, 0.4, "saw"), 0.05)])

func _cards_collect() -> PackedFloat32Array:
	return _swell(_noise(0.35, 0.3, 0.4, false))

func _discard_present() -> PackedFloat32Array:
	return _mix([_swell(_tone(200, 800, 0.45, 0.25)), _swell(_noise(0.45, 0.12, 0.5, false))])

func _discard_explode() -> PackedFloat32Array:
	return _mix([_noise(1.0, 0.8, 0.08), _tone(90, 30, 0.6, 0.6)])

func _discard_burn() -> PackedFloat32Array:
	var parts := [_noise(0.3, 0.6, 0.12)]
	for i in 30:
		parts.append(_offset(_noise(0.01, 0.4 * _rng.randf(), 0.9), 0.2 + _rng.randf() * 1.0))
	return _mix(parts)

func _discard_rip() -> PackedFloat32Array:
	var buf := _noise(0.8, 0.5, 0.45, false)
	for i in buf.size():
		buf[i] *= 0.4 + 0.6 * absf(sin(i * 0.004 + _rng.randf() * 0.3)) * (1.0 - float(i) / buf.size())
	return buf

func _discard_samurai() -> PackedFloat32Array:
	var shing := _mix([_tone(2600, 2200, 0.35, 0.2), _tone(3900, 3300, 0.35, 0.1)])
	return _mix([_offset(shing, 0.12), _offset(_swell(_noise(0.4, 0.25, 0.4, false)), 0.6)])

func _your_turn() -> PackedFloat32Array:
	return _notes([880, 1320], 0.12, 0.25)

func _bid() -> PackedFloat32Array:
	return _mix([_noise(0.02, 0.4, 0.9), _tone(1200, 1100, 0.06, 0.2)])

func _pass() -> PackedFloat32Array:
	return _mix([_noise(0.05, 0.4, 0.1), _tone(220, 180, 0.08, 0.3)])

func _challenge_start() -> PackedFloat32Array:
	var parts := []
	var t := 0.0
	var gap := 0.12
	while t < 0.9:
		parts.append(_offset(_noise(0.06, 0.2 + t * 0.5, 0.15), t))
		t += gap
		gap = maxf(gap * 0.85, 0.035)
	return _mix(parts)

func _point_scored() -> PackedFloat32Array:
	return _notes([523, 659, 784, 1047], 0.1, 0.3)

func _player_out() -> PackedFloat32Array:
	return _notes([392, 370, 349, 294], 0.3, 0.3, "saw")

func _round_start() -> PackedFloat32Array:
	var parts := []
	for i in 6:
		parts.append(_offset(_noise(0.05, 0.3, 0.5), i * 0.07))
	return _mix(parts)

func _game_win() -> PackedFloat32Array:
	return _mix([_notes([523, 659, 784], 0.12, 0.3), _offset(_mix([_tone(1047, 1047, 0.9, 0.2), _tone(784, 784, 0.9, 0.15)]), 0.36)])

func _game_over() -> PackedFloat32Array:
	return _notes([659, 523, 440, 330], 0.2, 0.3)

func _stamp_offer() -> PackedFloat32Array:
	var parts := []
	for i in 8:
		var f := 1800.0 + _rng.randf() * 1800.0
		parts.append(_offset(_tone(f, f, 0.12, 0.12), i * 0.06))
	return _mix(parts)

func _stamp_place() -> PackedFloat32Array:
	return _mix([_tone(150, 80, 0.15, 0.6), _noise(0.06, 0.4, 0.2)])

func _ui_click() -> PackedFloat32Array:
	return _tone(1000, 900, 0.03, 0.2)

func _player_join() -> PackedFloat32Array:
	return _tone(400, 900, 0.09, 0.35)


## Pitch sweep with a quick attack and exponential decay.
func _tone(f0: float, f1: float, dur: float, vol: float, wave := "sine") -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var k := float(i) / n
		phase += lerpf(f0, f1, k) / RATE
		var x := fmod(phase, 1.0)
		var s := sin(TAU * x)
		if wave == "square":
			s = signf(s) * 0.6
		elif wave == "saw":
			s = (x * 2.0 - 1.0) * 0.6
		out[i] = s * vol * _env(i, n)
	return out


## White noise through a one-pole low-pass (`bright` 0..1), decaying unless `decay` is false.
func _noise(dur: float, vol: float, bright: float, decay := true) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		y = lerpf(y, _rng.randf_range(-1.0, 1.0), clampf(bright, 0.02, 1.0))
		out[i] = y * vol * (_env(i, n) if decay else 1.0)
	return out


func _env(i: int, n: int) -> float:
	var attack := minf(1.0, i / (RATE * 0.004))
	return attack * exp(-4.0 * float(i) / n)


## Fade in then out (whooshes).
func _swell(buf: PackedFloat32Array) -> PackedFloat32Array:
	for i in buf.size():
		buf[i] *= sin(PI * float(i) / buf.size())
	return buf


func _notes(freqs: Array, each: float, vol: float, wave := "sine") -> PackedFloat32Array:
	var parts := []
	for i in freqs.size():
		parts.append(_offset(_tone(freqs[i], freqs[i], each * 1.6, vol, wave), i * each))
	return _mix(parts)


func _offset(buf: PackedFloat32Array, sec: float) -> PackedFloat32Array:
	var pad := PackedFloat32Array()
	pad.resize(int(sec * RATE))
	pad.append_array(buf)
	return pad


func _mix(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		if p.size() > out.size():
			out.resize(p.size())
		for i in p.size():
			out[i] += p[i]
	return out


func _wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
