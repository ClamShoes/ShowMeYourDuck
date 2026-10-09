class_name DiscardFx
extends Node2D

## One-shot "card destroyed forever" effect. Draws a static card texture centred on its origin,
## breaks it apart in one of STYLES, emits `finished`, then frees itself.

signal finished(fx)

const STYLES := ["explode", "burn", "rip", "samurai"]
const BurnShader = preload("res://assets/burn.gdshader")
const CARD := Vector2(96, 128)
const DURATION := {"explode": 1.1, "burn": 1.35, "rip": 1.3, "samurai": 1.5}

const EXPLODE_SWELL_SEC := 0.12
const RIP_TUG_SEC := 0.25
const SAMURAI_SLASH_AT := 0.15
const SAMURAI_SLASH_SEC := 0.1
const SAMURAI_CUT_AT := 0.55
## Optional present: fly to a target (screen centre), grow toward the camera, hold, then destroy.
const PRESENT_SEC := 0.45
const PRESENT_HOLD_SEC := 0.2
const PRESENT_TILT := 0.18
const SHADOW_ALPHA := 0.35
const SHADOW_NEAR := Vector2(6, 8)
const SHADOW_FAR := Vector2(18, 22)

var style := ""
## 0 at the source, 1 when presented; pushes the shadow away as the card rises.
var lift := 0.0:
	set(v):
		lift = v
		if _shadow:
			_shadow.position = SHADOW_NEAR.lerp(SHADOW_FAR, v)
## Burn front 0..1 (also drives the shader).
var progress := 0.0:
	set(v):
		progress = v
		if _whole and _whole.material:
			(_whole.material as ShaderMaterial).set_shader_parameter("progress", v)

var _tex: Texture2D
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _done := false
var _whole: Sprite2D
var _shadow: Sprite2D
var _presenting := false
## [{node, vel, spin, gravity, fade_from, fade_to}]
var _pieces: Array = []
var _broken := false


## Destroys in place, or (with a finite `to_global`) presents at `to_global` / `to_scale` first.
static func play(parent: Node, texture: Texture2D, from_global: Vector2, from_scale: float, p_style: String,
		rng_seed: int = 0, to_global: Vector2 = Vector2.INF, to_scale: float = -1.0) -> Node2D:
	var fx = load("res://scripts/ui/discard_fx.gd").new()
	fx._tex = texture
	fx.style = p_style if p_style in STYLES else String(STYLES[0])
	fx._rng.seed = rng_seed if rng_seed != 0 else hash(p_style)
	parent.add_child(fx)
	fx.global_position = from_global
	fx.scale = Vector2.ONE * from_scale
	fx._make_card()
	if to_global.is_finite():
		fx._present_to(to_global, to_scale if to_scale > 0.0 else from_scale)
	else:
		fx._begin_style()
	return fx


func piece_count() -> int:
	return _pieces.size()


func is_presenting() -> bool:
	return _presenting


func _make_card() -> void:
	_shadow = Sprite2D.new()
	_shadow.texture = _tex
	_shadow.modulate = Color(0, 0, 0, SHADOW_ALPHA)
	add_child(_shadow)
	_whole = Sprite2D.new()
	_whole.texture = _tex
	add_child(_whole)
	if _tex:
		_whole.scale = CARD / Vector2(_tex.get_size())
		_shadow.scale = _whole.scale
	lift = 0.0


func _present_to(to_global: Vector2, to_scale: float) -> void:
	_presenting = true
	rotation = PRESENT_TILT * (1.0 if _rng.randf() < 0.5 else -1.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", to_global, PRESENT_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE * to_scale, PRESENT_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation", 0.0, PRESENT_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "lift", 1.0, PRESENT_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(PRESENT_HOLD_SEC)
	tw.chain().tween_callback(_end_present)


func _end_present() -> void:
	_presenting = false
	_begin_style()


func _begin_style() -> void:
	_shadow.visible = false
	match style:
		"burn":
			var mat := ShaderMaterial.new()
			mat.shader = BurnShader
			mat.set_shader_parameter("seed", _rng.randf() * 100.0)
			_whole.material = mat
			progress = 0.0
			var tw := create_tween()
			tw.tween_property(self, "progress", 1.0, DURATION.burn - 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_burst(_embers())


func _process(delta: float) -> void:
	if _done or _presenting:
		return
	_t += delta
	match style:
		"explode":
			_step_explode()
		"rip":
			_step_rip()
		"samurai":
			_step_samurai()
	for p in _pieces:
		var n: Node2D = p.node
		n.position += p.vel * delta
		p.vel += Vector2(0, p.gravity) * delta
		n.rotation += p.spin * delta
		n.modulate.a = 1.0 - clampf(inverse_lerp(p.fade_from, p.fade_to, _t), 0.0, 1.0)
	if _t >= DURATION[style]:
		_done = true
		finished.emit(self)
		queue_free()


# --- styles ---------------------------------------------------------------------------------

func _step_explode() -> void:
	if _broken:
		return
	var k := clampf(_t / EXPLODE_SWELL_SEC, 0.0, 1.0)
	_whole.scale = CARD / Vector2(_tex.get_size()) * (1.0 + 0.12 * k) if _tex else Vector2.ONE
	if _t < EXPLODE_SWELL_SEC:
		return
	_broken = true
	_whole.visible = false
	for tri in _shards(4, 5):
		var c := _centroid(tri)
		var out := (c - CARD * 0.5).normalized()
		if out == Vector2.ZERO:
			out = Vector2.UP
		var vel := out.rotated(_rng.randf_range(-0.4, 0.4)) * _rng.randf_range(220.0, 480.0) + Vector2(0, -80)
		_add_piece(tri, vel, _rng.randf_range(-8.0, 8.0), 700.0, 0.5, DURATION.explode)
	_flash(0.15)


func _step_rip() -> void:
	if _broken:
		return
	var k := clampf(_t / RIP_TUG_SEC, 0.0, 1.0)
	_whole.position = Vector2(sin(_t * 70.0) * 3.0 * k, 0)
	_whole.rotation = sin(_t * 55.0) * 0.03 * k
	if _t < RIP_TUG_SEC:
		return
	_broken = true
	_whole.visible = false
	var halves := _rip_halves()
	_add_piece(halves[0], Vector2(-110, -60), -1.2, 520.0, 0.7, DURATION.rip)
	_add_piece(halves[1], Vector2(110, -60), 1.2, 520.0, 0.7, DURATION.rip)
	_burst(_paper_bits())


func _step_samurai() -> void:
	if _broken:
		return
	if _t >= SAMURAI_SLASH_AT and not has_meta("slashed"):
		set_meta("slashed", true)
		_slash()
	if _t < SAMURAI_CUT_AT:
		return
	_broken = true
	_whole.visible = false
	var centre := CARD * 0.5
	var d1 := Vector2.RIGHT.rotated(deg_to_rad(-35.0 + _rng.randf_range(-10.0, 10.0)))
	var d2 := Vector2.RIGHT.rotated(deg_to_rad(40.0 + _rng.randf_range(-10.0, 10.0)))
	var a1 := centre + Vector2(0, _rng.randf_range(-14.0, 14.0))
	var a2 := centre + Vector2(_rng.randf_range(-12.0, 12.0), 0)
	var rect := PackedVector2Array([Vector2.ZERO, Vector2(CARD.x, 0), CARD, Vector2(0, CARD.y)])
	var n1 := Vector2(-d1.y, d1.x)
	var n2 := Vector2(-d2.y, d2.x)
	for half in _cut(rect, a1, d1):
		for piece in _cut(half, a2, d2):
			var c := _centroid(piece)
			var side1 := signf((c - a1).cross(d1))
			var side2 := signf((c - a2).cross(d2))
			# Halves slip along the main cut; the second cut just eases its pieces apart.
			var vel := d1 * side1 * 80.0 - n1 * side1 * 25.0 - n2 * side2 * 35.0 + Vector2(0, -20)
			_add_piece(piece, vel, side1 * _rng.randf_range(0.2, 0.6), 480.0, 1.0, DURATION.samurai)


# --- geometry -------------------------------------------------------------------------------

## Jittered grid split into triangles (card px).
func _shards(cols: int, rows: int) -> Array:
	var pts: Array = []
	for y in rows + 1:
		var row: Array = []
		for x in cols + 1:
			var p := Vector2(CARD.x * x / cols, CARD.y * y / rows)
			if x > 0 and x < cols:
				p.x += _rng.randf_range(-0.3, 0.3) * CARD.x / cols
			if y > 0 and y < rows:
				p.y += _rng.randf_range(-0.3, 0.3) * CARD.y / rows
			row.append(p)
		pts.append(row)
	var tris: Array = []
	for y in rows:
		for x in cols:
			var a: Vector2 = pts[y][x]
			var b: Vector2 = pts[y][x + 1]
			var c: Vector2 = pts[y + 1][x + 1]
			var d: Vector2 = pts[y + 1][x]
			if _rng.randf() < 0.5:
				tris.append(PackedVector2Array([a, b, c]))
				tris.append(PackedVector2Array([a, c, d]))
			else:
				tris.append(PackedVector2Array([a, b, d]))
				tris.append(PackedVector2Array([b, c, d]))
	return tris


## Left/right polygons either side of a jagged top-to-bottom tear.
func _rip_halves() -> Array:
	var tear: Array = []
	var steps := 8
	for i in steps + 1:
		var y := CARD.y * i / steps
		var x := CARD.x * 0.5 + _rng.randf_range(-9.0, 9.0)
		tear.append(Vector2(x, y))
	var left := PackedVector2Array([Vector2.ZERO])
	for p in tear:
		left.append(p)
	left.append(Vector2(0, CARD.y))
	var right := PackedVector2Array([Vector2(CARD.x, 0), Vector2(CARD.x, CARD.y)])
	for i in range(tear.size() - 1, -1, -1):
		right.append(tear[i])
	return [left, right]


## Split a convex polygon by the line through `a` along `dir`.
func _cut(poly: PackedVector2Array, a: Vector2, dir: Vector2) -> Array:
	var big := 2000.0
	var n := Vector2(-dir.y, dir.x)
	var out: Array = []
	for s in [1.0, -1.0]:
		var half := PackedVector2Array([
			a - dir * big, a + dir * big, a + dir * big + n * big * s, a - dir * big + n * big * s,
		])
		for piece in Geometry2D.intersect_polygons(poly, half):
			if piece.size() >= 3:
				out.append(piece)
	return out


func _centroid(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in poly:
		c += p
	return c / maxf(poly.size(), 1)


# --- nodes ----------------------------------------------------------------------------------

## A textured fragment that spins around its own centroid. `poly` is in card px.
func _add_piece(poly: PackedVector2Array, vel: Vector2, spin: float, gravity: float, fade_from: float, fade_to: float) -> void:
	var c := _centroid(poly)
	var piece := Polygon2D.new()
	piece.texture = _tex
	piece.polygon = poly
	var uv_scale := Vector2(_tex.get_size()) / CARD if _tex else Vector2.ONE
	var uv := PackedVector2Array()
	for p in poly:
		uv.append(p * uv_scale)
	piece.uv = uv
	piece.offset = -c
	piece.position = c - CARD * 0.5
	add_child(piece)
	_pieces.append({node = piece, vel = vel, spin = spin, gravity = gravity, fade_from = fade_from, fade_to = fade_to})


func _flash(sec: float) -> void:
	var f := Polygon2D.new()
	f.polygon = PackedVector2Array([-CARD * 0.5, Vector2(CARD.x, -CARD.y) * 0.5, CARD * 0.5, Vector2(-CARD.x, CARD.y) * 0.5])
	f.color = Color(1, 1, 1, 0.85)
	add_child(f)
	var tw := create_tween()
	tw.tween_property(f, "modulate:a", 0.0, sec)
	tw.tween_callback(f.queue_free)


func _slash() -> void:
	var from := Vector2(-CARD.x * 0.9, CARD.y * 0.75)
	var to := Vector2(CARD.x * 0.9, -CARD.y * 0.75)
	for spec in [[14.0, Color(0.75, 0.9, 1.0, 0.45)], [6.0, Color(1, 1, 1, 1)]]:
		var line := Line2D.new()
		line.width = spec[0]
		line.default_color = spec[1]
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.points = PackedVector2Array([from, from])
		line.z_index = 2
		add_child(line)
		var tw := create_tween()
		tw.tween_method(func(k: float): line.set_point_position(1, from.lerp(to, k)), 0.0, 1.0, SAMURAI_SLASH_SEC)
		tw.tween_interval(0.08)
		tw.tween_property(line, "width", 1.0, 0.25)
		tw.parallel().tween_property(line, "modulate:a", 0.0, 0.25)
		tw.tween_callback(line.queue_free)
	_flash(0.12)


func _particles(amount: int, lifetime: float, color: Color) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.color = color
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	return p


func _embers() -> CPUParticles2D:
	var p := _particles(28, 0.8, Color(1.0, 0.55, 0.15))
	p.one_shot = false
	p.explosiveness = 0.0
	p.lifetime_randomness = 0.4
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = CARD * 0.45
	p.direction = Vector2.UP
	p.spread = 25.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 90.0
	p.gravity = Vector2(0, -60)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	return p


func _paper_bits() -> CPUParticles2D:
	var p := _particles(18, 0.7, Color(0.97, 0.94, 0.86))
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(3, CARD.y * 0.45)
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 160.0
	p.gravity = Vector2(0, 400)
	p.angular_velocity_min = -300.0
	p.angular_velocity_max = 300.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	return p


func _burst(p: CPUParticles2D) -> void:
	add_child(p)
	p.emitting = true
