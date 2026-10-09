extends SceneTree

## Generates the duck stamp art (pixel-art PNGs with a dark sticker outline) into assets/stamps/.
## Sized for the 144x176 duck drawing. Paint over or replace the PNGs freely.
## Run: godot --headless --path . --script tests/gen_stamps.gd

const DuckStamps = preload("res://scripts/ui/duck_stamps.gd")

const INK := Color("1a1a1a")
const STEEL := Color("cfd8dc")
const STEEL_HI := Color("ffffff")
const GOLD := Color("f2b632")
const GOLD_DK := Color("b07d12")
const WOOD := Color("8d5a2b")
const WOOD_DK := Color("5d3a1a")


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DuckStamps.ART_DIR))
	var made := {
		"katana": _katana(),
		"tnt": _tnt(),
		"torch": _torch(),
		"top_hat": _top_hat(),
		"monocle": _monocle(),
		"cane": _cane(),
		"moustache": _moustache(),
		"eyes_googly": _eyes_googly(),
		"eyes_angry": _eyes_angry(),
		"eyes_sleepy": _eyes_sleepy(),
		"eyes_star": _eyes_star(),
	}
	for id in DuckStamps.STAMPS.keys():
		var img: Image = made[id]
		_outline(img)
		img.save_png(DuckStamps.art_path(id))
	print("Wrote %d stamps to %s" % [made.size(), DuckStamps.ART_DIR])
	quit(0)


func _canvas(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


func _katana() -> Image:
	var img := _canvas(68, 16)
	# Hilt with diamond wrap
	_rect(img, 2, 5, 16, 7, INK)
	for i in 4:
		var cx := 4 + i * 4
		_px(img, cx, 8, Color("e0e0e0"))
		_px(img, cx + 1, 7, Color("e0e0e0"))
		_px(img, cx + 1, 9, Color("e0e0e0"))
		_px(img, cx + 2, 8, Color("e0e0e0"))
	_rect(img, 0, 6, 2, 5, GOLD_DK)
	# Tsuba (guard)
	_ellipse(img, 19, 8, 2, 6, GOLD)
	_rect(img, 18, 7, 2, 3, GOLD_DK)
	# Blade, slight upward curve toward the tip
	for x in range(22, 66):
		var t := float(x - 22) / 44.0
		var lift := int(round(t * t * 3.0))
		var thick := 4 if x < 60 else maxi(1, 4 - (x - 59))
		for y in thick:
			_px(img, x, 6 - lift + y, STEEL)
		_px(img, x, 6 - lift + thick - 1, STEEL_HI)
	return img


func _tnt() -> Image:
	var img := _canvas(44, 48)
	for i in 3:
		var x := 4 + i * 12
		_rect(img, x, 14, 11, 32, Color("d32f2f"))
		_rect(img, x, 14, 2, 32, Color("ef5350"))
		_rect(img, x + 9, 14, 2, 32, Color("b71c1c"))
	_rect(img, 4, 26, 35, 8, Color("f5e6c8"))
	_text(img, "TNT", 12, 27, INK)
	# Fuse with spark
	var fuse := [Vector2(21, 14), Vector2(22, 10), Vector2(26, 7), Vector2(30, 6)]
	for i in fuse.size() - 1:
		_line(img, fuse[i], fuse[i + 1], 1, Color("6d4c41"))
	_star(img, Vector2(33, 5), 5.0, 2.2, Color("ffeb3b"))
	_px(img, 33, 5, Color("ff9800"))
	return img


func _torch() -> Image:
	var img := _canvas(26, 60)
	_rect(img, 10, 26, 6, 32, WOOD)
	_rect(img, 10, 26, 2, 32, Color("a8733f"))
	_rect(img, 8, 24, 10, 4, Color("78909c"))
	_rect(img, 8, 24, 10, 1, Color("b0bec5"))
	_ellipse(img, 13, 16, 9, 10, Color("e53935"))
	_ellipse(img, 13, 10, 5, 8, Color("e53935"))
	_ellipse(img, 13, 17, 6, 7, Color("fb8c00"))
	_ellipse(img, 13, 12, 3, 6, Color("fb8c00"))
	_ellipse(img, 13, 19, 3, 4, Color("ffeb3b"))
	return img


func _top_hat() -> Image:
	var img := _canvas(50, 42)
	_rect(img, 11, 2, 28, 32, INK)
	_rect(img, 14, 4, 2, 26, Color("424242"))
	_rect(img, 11, 25, 28, 5, Color("c62828"))
	_ellipse(img, 25, 36, 24, 4, INK)
	_rect(img, 4, 35, 8, 1, Color("424242"))
	return img


func _monocle() -> Image:
	var img := _canvas(38, 50)
	_ellipse(img, 16, 16, 13, 13, GOLD)
	_ellipse(img, 16, 16, 10, 10, Color(0.75, 0.9, 1.0, 0.45))
	_px(img, 11, 11, Color(1, 1, 1, 0.9))
	_px(img, 12, 10, Color(1, 1, 1, 0.9))
	_px(img, 10, 12, Color(1, 1, 1, 0.9))
	var pts := [Vector2(27, 24), Vector2(31, 32), Vector2(32, 40), Vector2(30, 47)]
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		for s in 6:
			var p := a.lerp(b, s / 6.0)
			_px(img, int(p.x), int(p.y), GOLD_DK if s % 2 == 0 else GOLD)
	return img


func _cane() -> Image:
	var img := _canvas(28, 66)
	_line(img, Vector2(6, 62), Vector2(9, 16), 2, INK)
	_line(img, Vector2(6, 62), Vector2(9, 16), 1, Color("3e2723"))
	# Hooked handle
	for a in range(0, 181, 6):
		var ang := deg_to_rad(180.0 + a)
		var p := Vector2(15, 16) + Vector2(cos(ang), sin(ang)) * 6.0
		_disc(img, p, 1.6, INK)
	_line(img, Vector2(21, 16), Vector2(21, 21), 1.6, INK)
	_rect(img, 4, 60, 5, 4, GOLD)
	_rect(img, 7, 14, 4, 3, GOLD)
	return img


func _moustache() -> Image:
	var img := _canvas(68, 26)
	# Each half: a tapered stroke sweeping out and down from the middle, then up into a curl.
	for side in [-1, 1]:
		var c := Vector2(34 + side * 24.0, 8.0)
		for i in 41:
			var t := i / 40.0
			var p := Vector2(34 + side * (2.0 + t * 22.0), lerpf(10.0, 13.0, t) + sin(t * PI) * 3.0)
			_disc(img, p, lerpf(3.5, 1.6, t), INK)
		# Twirl: out, up over the top, and back in, tightening as it goes.
		for i in 41:
			var t := i / 40.0
			var th := t * PI * 1.6
			var r := lerpf(5.0, 2.2, t)
			_disc(img, c + Vector2(side * sin(th) * r, cos(th) * r), lerpf(1.6, 0.8, t), INK)
	_ellipse(img, 34, 11, 4, 3, INK)
	return img


func _eye_whites(img: Image, a: Vector2, b: Vector2, r: int) -> void:
	for c in [a, b]:
		_ellipse(img, int(c.x), int(c.y), r, r, Color.WHITE)


func _eyes_googly() -> Image:
	var img := _canvas(58, 28)
	_eye_whites(img, Vector2(14, 14), Vector2(44, 14), 11)
	_ellipse(img, 10, 18, 5, 5, INK)
	_ellipse(img, 48, 9, 5, 5, INK)
	_px(img, 9, 16, Color.WHITE)
	_px(img, 47, 7, Color.WHITE)
	return img


func _eyes_angry() -> Image:
	var img := _canvas(58, 30)
	_eye_whites(img, Vector2(14, 18), Vector2(44, 18), 9)
	_ellipse(img, 17, 20, 4, 4, INK)
	_ellipse(img, 41, 20, 4, 4, INK)
	# Brows slant down toward the middle and cut the top of each eye
	_line(img, Vector2(3, 6), Vector2(25, 13), 2, INK)
	_line(img, Vector2(55, 6), Vector2(33, 13), 2, INK)
	for x in 58:
		for y in 30:
			var left_cut := x < 29 and y < 6 + (x - 3) * 7.0 / 22.0
			var right_cut := x >= 29 and y < 6 + (55 - x) * 7.0 / 22.0
			if (left_cut or right_cut) and img.get_pixel(x, y) == Color.WHITE:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return img


func _eyes_sleepy() -> Image:
	var img := _canvas(58, 26)
	_eye_whites(img, Vector2(14, 13), Vector2(44, 13), 10)
	_ellipse(img, 14, 17, 4, 4, INK)
	_ellipse(img, 44, 17, 4, 4, INK)
	for c in [14, 44]:
		for y in range(2, 14):
			for x in range(c - 11, c + 12):
				if img.get_pixel(x, y).a > 0.0:
					img.set_pixel(x, y, Color("f9a825"))
		_rect(img, c - 10, 13, 21, 1, INK)
		for i in 3:
			_px(img, c - 6 + i * 6, 14, INK)
			_px(img, c - 6 + i * 6, 15, INK)
	return img


func _eyes_star() -> Image:
	var img := _canvas(58, 28)
	_star(img, Vector2(14, 14), 12.0, 5.0, Color("ffeb3b"))
	_star(img, Vector2(44, 14), 12.0, 5.0, Color("ffeb3b"))
	_star(img, Vector2(14, 14), 6.0, 2.5, Color("fff59d"))
	_star(img, Vector2(44, 14), 6.0, 2.5, Color("fff59d"))
	return img


## 1px dark sticker outline around every opaque pixel.
func _outline(img: Image) -> void:
	var src: Image = img.duplicate()
	for y in img.get_height():
		for x in img.get_width():
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height() and src.get_pixelv(q).a > 0.3:
					img.set_pixel(x, y, INK)
					break


func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)


func _ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	for yy in range(cy - ry, cy + ry + 1):
		for xx in range(cx - rx, cx + rx + 1):
			var dx := float(xx - cx) / float(rx)
			var dy := float(yy - cy) / float(ry)
			if dx * dx + dy * dy <= 1.0:
				_px(img, xx, yy, c)


func _disc(img: Image, p: Vector2, r: float, c: Color) -> void:
	for yy in range(floori(p.y - r), ceili(p.y + r) + 1):
		for xx in range(floori(p.x - r), ceili(p.x + r) + 1):
			if Vector2(xx, yy).distance_to(p) <= r:
				_px(img, xx, yy, c)


func _line(img: Image, a: Vector2, b: Vector2, r: float, c: Color) -> void:
	var steps := maxi(1, ceili(a.distance_to(b) * 2.0))
	for i in steps + 1:
		_disc(img, a.lerp(b, float(i) / steps), r, c)


func _star(img: Image, centre: Vector2, outer: float, inner: float, c: Color) -> void:
	var poly := PackedVector2Array()
	for i in 10:
		var ang := -PI / 2.0 + i * PI / 5.0
		poly.append(centre + Vector2(cos(ang), sin(ang)) * (outer if i % 2 == 0 else inner))
	for yy in range(floori(centre.y - outer), ceili(centre.y + outer) + 1):
		for xx in range(floori(centre.x - outer), ceili(centre.x + outer) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(xx, yy) + Vector2(0.5, 0.5), poly):
				_px(img, xx, yy, c)


func _text(img: Image, text: String, x: int, y: int, c: Color) -> void:
	var glyphs := {
		"T": ["111", "010", "010", "010", "010"],
		"N": ["101", "111", "111", "111", "101"],
	}
	for ch in text:
		var rows: Array = glyphs[ch]
		for ry in rows.size():
			for rx in 3:
				if rows[ry][rx] == "1":
					_px(img, x + rx * 2, y + ry, c)
					_px(img, x + rx * 2 + 1, y + ry, c)
		x += 8
