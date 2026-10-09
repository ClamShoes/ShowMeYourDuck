extends SceneTree

## Generates clear Safe/Duck face textures (96x128) into assets/, plus 72x88 emblems
## (assets/cards/) that CardArt composites onto each player's chosen front frame.
## Run: godot --headless --path . --script tests/gen_card_faces.gd

const EMBLEM_W := 72
const EMBLEM_H := 88


func _init() -> void:
	_write_safe()
	_write_duck()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/cards"))
	_write_emblem_safe()
	_write_duck_default()
	print("Wrote cardface_safe.png, cardface_duck.png, cards/emblem_safe.png, cards/duck_default.png")
	quit(0)


func _write_emblem_safe() -> void:
	var img := Image.create(EMBLEM_W, EMBLEM_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_rect(img, 0, 0, EMBLEM_W, EMBLEM_H, Color("e8f5e9"))
	_border_rect(img, 0, 0, EMBLEM_W, EMBLEM_H, Color("1d4a28"))
	_border_rect(img, 1, 1, EMBLEM_W - 2, EMBLEM_H - 2, Color("1d4a28"))
	_fill_ellipse(img, 36, 36, 24, 24, Color("c8e6c9"))
	for i in 14:
		for t in 3:
			img.set_pixel(20 + i, 34 + i + t, Color("1d4a28"))
	for i in 24:
		for t in 3:
			img.set_pixel(33 + i, 48 - int(i * 1.15) + t, Color("2e7d32"))
	_stamp_text_block(img, "SAFE", Color("1d4a28"), 68)
	img.save_png("res://assets/cards/emblem_safe.png")


## Default duck art — replaced per player by their drawing later.
func _write_duck_default() -> void:
	var img := Image.create(EMBLEM_W, EMBLEM_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_rect(img, 0, 0, EMBLEM_W, EMBLEM_H, Color("fff8e1"))
	_border_rect(img, 0, 0, EMBLEM_W, EMBLEM_H, Color("1a1a1a"))
	_border_rect(img, 1, 1, EMBLEM_W - 2, EMBLEM_H - 2, Color("1a1a1a"))
	# Water
	_fill_rect(img, 4, 56, EMBLEM_W - 8, 6, Color("90caf9"))
	# Body, wing, head, bill, eye
	_fill_ellipse(img, 32, 46, 22, 13, Color("ffc107"))
	_fill_ellipse(img, 27, 44, 11, 6, Color("ffa000"))
	_fill_ellipse(img, 46, 25, 11, 10, Color("ffca28"))
	_fill_ellipse(img, 59, 28, 8, 4, Color("ff7043"))
	_fill_ellipse(img, 49, 22, 2, 2, Color("1a1a1a"))
	_stamp_text_block(img, "DUCK", Color("1a1a1a"), 68)
	img.save_png("res://assets/cards/duck_default.png")


func _write_safe() -> void:
	var img := Image.create(96, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color("e8f5e9"))
	_border(img, Color("1d4a28"))
	_fill_rect(img, 12, 20, 72, 88, Color("c8e6c9"))
	_border_rect(img, 12, 20, 72, 88, Color("1d4a28"))
	# Checkmark-ish
	for i in 18:
		img.set_pixel(28 + i, 70 + int(i * 0.4), Color("1d4a28"))
		img.set_pixel(28 + i, 71 + int(i * 0.4), Color("1d4a28"))
	for i in 28:
		img.set_pixel(46 + i, 78 - int(i * 0.55), Color("2e7d32"))
		img.set_pixel(46 + i, 79 - int(i * 0.55), Color("2e7d32"))
	_stamp_text_block(img, "SAFE", Color("1d4a28"), 34)
	img.save_png("res://assets/cardface_safe.png")


func _write_duck() -> void:
	var img := Image.create(96, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color("fff8e1"))
	_border(img, Color("1a1a1a"))
	_fill_rect(img, 12, 20, 72, 88, Color("ffe082"))
	_border_rect(img, 12, 20, 72, 88, Color("1a1a1a"))
	# Duck body
	_fill_ellipse(img, 48, 72, 22, 16, Color("ffc107"))
	_fill_ellipse(img, 48, 52, 14, 12, Color("ffca28"))
	# Bill
	_fill_ellipse(img, 64, 54, 10, 5, Color("ff7043"))
	# Eye
	_fill_ellipse(img, 52, 48, 3, 3, Color("1a1a1a"))
	_stamp_text_block(img, "DUCK", Color("1a1a1a"), 34)
	img.save_png("res://assets/cardface_duck.png")


func _border(img: Image, c: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for x in w:
		img.set_pixel(x, 0, c)
		img.set_pixel(x, 1, c)
		img.set_pixel(x, h - 1, c)
		img.set_pixel(x, h - 2, c)
	for y in h:
		img.set_pixel(0, y, c)
		img.set_pixel(1, y, c)
		img.set_pixel(w - 1, y, c)
		img.set_pixel(w - 2, y, c)


func _fill_rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < img.get_width() and yy < img.get_height():
				img.set_pixel(xx, yy, c)


func _border_rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for xx in range(x, x + w):
		img.set_pixel(xx, y, c)
		img.set_pixel(xx, y + h - 1, c)
	for yy in range(y, y + h):
		img.set_pixel(x, yy, c)
		img.set_pixel(x + w - 1, yy, c)


func _fill_ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	for yy in range(cy - ry, cy + ry + 1):
		for xx in range(cx - rx, cx + rx + 1):
			var dx := float(xx - cx) / float(rx)
			var dy := float(yy - cy) / float(ry)
			if dx * dx + dy * dy <= 1.0:
				if xx >= 0 and yy >= 0 and xx < img.get_width() and yy < img.get_height():
					img.set_pixel(xx, yy, c)


func _stamp_text_block(img: Image, text: String, c: Color, top: int) -> void:
	# 5x7 block letters for SAFE / DUCK
	var glyphs := {
		"S": ["01110", "10001", "10000", "01110", "00001", "10001", "01110"],
		"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
		"F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
		"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
		"D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
		"U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
		"C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
		"K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
	}
	var scale := 2
	var letter_w := 5 * scale + 2
	var total_w := text.length() * letter_w
	var start_x := int((img.get_width() - total_w) / 2.0)
	var x := start_x
	for ch in text:
		var rows: Array = glyphs.get(ch, [])
		for row_i in rows.size():
			var row: String = rows[row_i]
			for col_i in row.length():
				if row[col_i] == "1":
					for sy in scale:
						for sx in scale:
							img.set_pixel(x + col_i * scale + sx, top + row_i * scale + sy, c)
		x += letter_w
