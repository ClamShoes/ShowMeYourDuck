class_name DuckStamps
extends RefCounted
## Stamps a Duck's owner can earn and place on their duck. Some secretly unlock a discard style.
## Server-safe: no scene or autoload dependencies.

## stamp id -> discard style it unlocks ("" = cosmetic only)
const STAMPS := {
	"katana": "samurai",
	"tnt": "explode",
	"torch": "burn",
	"top_hat": "",
	"monocle": "",
	"cane": "",
	"moustache": "",
	"eyes_googly": "",
	"eyes_angry": "",
	"eyes_sleepy": "",
	"eyes_star": "",
}
const DEFAULT_STYLE := "rip"
const OFFER_SIZE := 3
const ART_DIR := "res://assets/stamps/"


static func art_path(stamp_id: String) -> String:
	return ART_DIR + stamp_id + ".png"


static func empty_progress() -> Dictionary:
	return {"earned": [], "powers": [], "fresh": ""}


## {earned, powers, fresh} with only known ids, no duplicates.
static func sanitize_progress(v: Variant) -> Dictionary:
	var out := empty_progress()
	if not v is Dictionary:
		return out
	for s in v.get("earned", []):
		var id := String(s)
		if STAMPS.has(id) and id not in out.earned:
			out.earned.append(id)
	var styles := STAMPS.values()
	for s in v.get("powers", []):
		var st := String(s)
		if st != "" and st in styles and st not in out.powers:
			out.powers.append(st)
	var fresh := String(v.get("fresh", ""))
	if fresh in out.powers:
		out.fresh = fresh
	return out


## Up to OFFER_SIZE random stamps not yet earned (empty when all are earned).
static func offers(rng: RandomNumberGenerator, earned: Array) -> Array:
	var pool: Array = []
	for id in STAMPS.keys():
		if id not in earned:
			pool.append(id)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, OFFER_SIZE)


## A freshly unlocked power plays once first; after that, random among rip + powers.
static func pick_style(progress: Dictionary, rng: RandomNumberGenerator) -> String:
	var fresh := String(progress.get("fresh", ""))
	if fresh != "":
		progress.fresh = ""
		return fresh
	var pool: Array = [DEFAULT_STYLE]
	pool.append_array(progress.get("powers", []))
	return String(pool[rng.randi_range(0, pool.size() - 1)])


## Record a placed stamp (mutates progress). Returns the newly unlocked style, or "".
static func apply_stamp(progress: Dictionary, stamp_id: String) -> String:
	if stamp_id not in progress.earned:
		progress.earned.append(stamp_id)
	var style := String(STAMPS.get(stamp_id, ""))
	if style == "" or style in progress.powers:
		return ""
	progress.powers.append(style)
	progress.fresh = style
	return style


## Stamp drawn onto a copy of base: centred at `centre` (base pixels), rotated `rot` radians,
## scaled `scale`, mirrored left-to-right if `flip_h`. Nearest-neighbour inverse mapping, alpha-blended.
static func bake(base: Image, stamp: Image, centre: Vector2, rot: float, scale: float, flip_h: bool = false) -> Image:
	var out: Image = base.duplicate()
	if out.get_format() != Image.FORMAT_RGBA8:
		out.convert(Image.FORMAT_RGBA8)
	var src: Image = stamp
	if src.get_format() != Image.FORMAT_RGBA8:
		src = stamp.duplicate()
		src.convert(Image.FORMAT_RGBA8)
	var ssize := Vector2(src.get_size())
	var half := ssize * 0.5
	var radius := half.length() * scale
	var x0 := maxi(0, floori(centre.x - radius))
	var x1 := mini(out.get_width() - 1, ceili(centre.x + radius))
	var y0 := maxi(0, floori(centre.y - radius))
	var y1 := mini(out.get_height() - 1, ceili(centre.y + radius))
	var inv := Transform2D(rot, Vector2(-scale if flip_h else scale, scale), 0.0, centre).affine_inverse()
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var p: Vector2 = inv * (Vector2(x, y) + Vector2(0.5, 0.5)) + half
			var sx := floori(p.x)
			var sy := floori(p.y)
			if sx < 0 or sy < 0 or sx >= src.get_width() or sy >= src.get_height():
				continue
			var c := src.get_pixel(sx, sy)
			if c.a <= 0.0:
				continue
			out.set_pixel(x, y, out.get_pixel(x, y).blend(c))
	return out
