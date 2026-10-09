class_name DuckDrawing
extends RefCounted
## A player's hand-drawn duck: SIZE RGBA PNG, drawn on the emblem area of the Duck face and
## downscaled 2x onto the card. Shared by client (editor, local save) and server (validation).

const CardArt = preload("res://scripts/ui/card_art.gd")

const SIZE := Vector2i(144, 176)
## Must fit in one WebSocket message alongside the RPC header.
const MAX_BYTES := 48 * 1024
const PATH := "user://duck.png"
const PNG_SIGNATURE := [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

## Overridable so tests don't touch the real drawing.
static var path := PATH


## Image if bytes are a PNG of exactly SIZE within MAX_BYTES, else null.
static func decode(bytes: PackedByteArray) -> Image:
	if bytes.is_empty() or bytes.size() > MAX_BYTES or bytes.size() < 24:
		return null
	for i in PNG_SIGNATURE.size():
		if bytes[i] != PNG_SIGNATURE[i]:
			return null
	# Read IHDR dimensions before decoding: a small PNG can claim a huge canvas.
	if bytes.slice(12, 16).get_string_from_ascii() != "IHDR":
		return null
	if _be_u32(bytes, 16) != SIZE.x or _be_u32(bytes, 20) != SIZE.y:
		return null
	var img := Image.new()
	if img.load_png_from_buffer(bytes) != OK or img.get_size() != SIZE:
		return null
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


static func encode(img: Image) -> PackedByteArray:
	return img.save_png_to_buffer()


## Saved drawing, or null if none / unreadable.
static func load_local() -> Image:
	if not FileAccess.file_exists(path):
		return null
	return decode(FileAccess.get_file_as_bytes(path))


static func save_local(img: Image) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_buffer(encode(img))
		f.close()


static func blank_image() -> Image:
	return Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)


## The stock duck, upscaled to the drawing size so players can start from it.
static func default_image() -> Image:
	var src: Image = CardArt._load_image(CardArt.DUCK_DEFAULT_PATH).duplicate()
	src.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_NEAREST)
	return src


static func _be_u32(b: PackedByteArray, at: int) -> int:
	return (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3]
