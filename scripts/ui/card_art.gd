class_name CardArt
extends RefCounted
## Per-player card textures. Backs come straight from the catalog; faces are the owner's
## front frame with the Safe emblem or that player's duck art composited in the middle.
## Faces must be single textures — the perspective shader on cardBack2 won't carry child nodes.

const CardCatalog = preload("res://scripts/ui/card_catalog.gd")

const CARD_SIZE := Vector2i(96, 128)
const EMBLEM_SIZE := Vector2i(72, 88)
const EMBLEM_SAFE_PATH := "res://assets/cards/emblem_safe.png"
const DUCK_DEFAULT_PATH := "res://assets/cards/duck_default.png"
const MINI_DUCK_SIZE := Vector2i(36, 44)

## player_id -> { card_back_id, card_front_id, duck_rev }
static var _players: Dictionary = {}
## player_id -> { rev, image } — player-drawn duck (future); absent = default duck.
static var _duck_images: Dictionary = {}
static var _textures: Dictionary = {}
static var _images: Dictionary = {}


static func set_players(players: Array) -> void:
	_players.clear()
	for p in players:
		if not (p is Dictionary) or not p.has("id"):
			continue
		var c := CardCatalog.sanitize(p)
		c["duck_rev"] = int(p.get("duck_rev", 0))
		_players[String(p.id)] = c


## Called when a player's duck drawing arrives (cached per rev).
static func set_duck_image(player_id: String, rev: int, image: Image) -> void:
	_duck_images[player_id] = {"rev": rev, "image": image}
	# Revs restart per room, so a new drawing can reuse an old (owner, rev) cache key.
	for key in _textures.keys():
		var k := String(key)
		if k.contains("|duck|%s|" % player_id) or k.begins_with("mini|%s|" % player_id):
			_textures.erase(key)


## Reserved owner id for the lobby's own-card preview (never a real player id).
const LOCAL_ID := "__local"
static var _local_rev := 0


## Lobby preview of your own cards. Leaves other players' entries alone; a null duck
## image falls back to the default duck.
static func set_local_preview(cosmetics: Dictionary, duck_image: Image) -> void:
	var c := CardCatalog.sanitize(cosmetics)
	if duck_image != null:
		_local_rev += 1
		_duck_images[LOCAL_ID] = {"rev": _local_rev, "image": duck_image}
	else:
		_duck_images.erase(LOCAL_ID)
	c["duck_rev"] = _local_rev if duck_image != null else 0
	_players[LOCAL_ID] = c


static func cosmetics_of(owner_id: String) -> Dictionary:
	return _players.get(owner_id, CardCatalog.sanitize({}))


static func back_texture(owner_id: String) -> Texture2D:
	return back_texture_by_id(String(cosmetics_of(owner_id).card_back_id))


static func back_texture_by_id(back_id: String) -> Texture2D:
	var key := "back|%s" % back_id
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(_entry_image(CardCatalog.back_entry(back_id)))
	return _textures[key]


## Front frame only — unrevealed stack tokens use this so Duck/Safe never sits on the sprite early.
static func blank_face_texture(owner_id: String) -> Texture2D:
	var id := String(cosmetics_of(owner_id).card_front_id)
	var key := "blank|%s" % id
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(_front_image(id))
	return _textures[key]


## Safe face for a front id (picker thumbnails).
static func safe_face_by_front(front_id: String) -> Texture2D:
	return _face(front_id, "face|%s|safe" % front_id, null, false)


## Latest drawing received for a player (any rev), or null for the default duck.
static func duck_image_of(owner_id: String) -> Image:
	var custom: Dictionary = _duck_images.get(owner_id, {})
	return custom.get("image") as Image


static func face_texture(owner_id: String, is_duck: bool) -> Texture2D:
	var c := cosmetics_of(owner_id)
	var front_id := String(c.card_front_id)
	var key := "face|%s|safe" % front_id
	var emblem: Image = null
	if is_duck:
		var custom: Dictionary = _duck_images.get(owner_id, {})
		if custom.get("image") is Image and int(custom.get("rev", -1)) == int(c.duck_rev):
			key = "face|%s|duck|%s|%s" % [front_id, owner_id, c.duck_rev]
			emblem = custom.image
		else:
			key = "face|%s|duck|default" % front_id
	return _face(front_id, key, emblem, is_duck)


## Confetti-sized copy of the owner's duck (drawing for the current rev, else the default duck).
static func mini_duck_texture(owner_id: String) -> Texture2D:
	var c := cosmetics_of(owner_id)
	var custom: Dictionary = _duck_images.get(owner_id, {})
	var src: Image = null
	var key := "mini|default"
	if custom.get("image") is Image and int(custom.get("rev", -1)) == int(c.duck_rev):
		src = custom.image
		key = "mini|%s|%s" % [owner_id, c.duck_rev]
	if _textures.has(key):
		return _textures[key]
	if src == null:
		src = _load_image(DUCK_DEFAULT_PATH)
	var img := src
	while img.get_width() >= MINI_DUCK_SIZE.x * 2 and img.get_height() >= MINI_DUCK_SIZE.y * 2 \
			and img.get_width() % 2 == 0 and img.get_height() % 2 == 0:
		img = _downscale_2x(img)
	if img.get_size() != MINI_DUCK_SIZE:
		img = img.duplicate() as Image
		var k := minf(float(MINI_DUCK_SIZE.x) / img.get_width(), float(MINI_DUCK_SIZE.y) / img.get_height())
		img.resize(maxi(1, roundi(img.get_width() * k)), maxi(1, roundi(img.get_height() * k)), Image.INTERPOLATE_BILINEAR)
	_textures[key] = ImageTexture.create_from_image(img)
	return _textures[key]


static func _face(front_id: String, key: String, emblem: Image, is_duck: bool) -> Texture2D:
	if _textures.has(key):
		return _textures[key]
	var img: Image
	if emblem != null:
		img = duck_face_image(front_id, emblem)
	else:
		img = _front_image(front_id)
		_blend_centered(img, _load_image(DUCK_DEFAULT_PATH if is_duck else EMBLEM_SAFE_PATH), EMBLEM_SIZE)
	_textures[key] = ImageTexture.create_from_image(img)
	return _textures[key]


## Front frame with a player drawing in the emblem slot (drawings are 2x the slot).
static func duck_face_image(front_id: String, drawing: Image) -> Image:
	var img := _front_image(front_id)
	var d := drawing
	if d.get_size() == EMBLEM_SIZE * 2:
		d = _downscale_2x(d)
	_blend_centered(img, d, EMBLEM_SIZE)
	return img


## The front's emblem area (what a drawing covers), for the editor underlay.
static func emblem_area_image(front_id: String) -> Image:
	return _front_image(front_id).get_region(Rect2i((CARD_SIZE - EMBLEM_SIZE) / 2, EMBLEM_SIZE))


## 2x2 box average, alpha-weighted so transparent (black) pixels don't darken edges.
static func _downscale_2x(src: Image) -> Image:
	var s := src
	if s.get_format() != Image.FORMAT_RGBA8:
		s = src.duplicate() as Image
		s.convert(Image.FORMAT_RGBA8)
	var w := s.get_width() / 2
	var h := s.get_height() / 2
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var rgb := Vector3.ZERO
			var a := 0.0
			for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var c := s.get_pixel(x * 2 + o.x, y * 2 + o.y)
				rgb += Vector3(c.r, c.g, c.b) * c.a
				a += c.a
			if a > 0.0:
				rgb /= a
			out.set_pixel(x, y, Color(rgb.x, rgb.y, rgb.z, a * 0.25))
	return out


static func clear_cache() -> void:
	_textures.clear()
	_images.clear()


static func _front_image(front_id: String) -> Image:
	return _entry_image(CardCatalog.front_entry(front_id))


## Fresh RGBA8 copy at CARD_SIZE for a catalog entry (region crop, overlay, tint).
static func _entry_image(entry: Dictionary) -> Image:
	var img := _region_image(String(entry.path), entry.get("region", Rect2i()))
	if img.get_size() != CARD_SIZE:
		img.resize(CARD_SIZE.x, CARD_SIZE.y, Image.INTERPOLATE_NEAREST)
	if entry.has("overlay_path"):
		var over := _region_image(String(entry.overlay_path), entry.get("overlay_region", Rect2i()))
		_blend_centered(img, over, CARD_SIZE)
	var tint: Color = entry.get("tint", Color.WHITE)
	if tint != Color.WHITE:
		for y in img.get_height():
			for x in img.get_width():
				img.set_pixel(x, y, img.get_pixel(x, y) * tint)
	return img


static func _region_image(path: String, region: Rect2i) -> Image:
	var src := _load_image(path)
	if region.size == Vector2i.ZERO:
		return src.duplicate() as Image
	return src.get_region(region)


static func _blend_centered(dst: Image, src: Image, max_size: Vector2i) -> void:
	var s := src
	if s.get_width() > max_size.x or s.get_height() > max_size.y:
		s = src.duplicate() as Image
		s.resize(mini(s.get_width(), max_size.x), mini(s.get_height(), max_size.y), Image.INTERPOLATE_NEAREST)
	if s.get_format() != dst.get_format():
		s = s.duplicate() as Image
		s.convert(dst.get_format())
	var at := (dst.get_size() - s.get_size()) / 2
	dst.blend_rect(s, Rect2i(Vector2i.ZERO, s.get_size()), at)


static func _load_image(path: String) -> Image:
	if _images.has(path):
		return _images[path]
	var img: Image = null
	var tex := load(path) as Texture2D
	if tex:
		img = tex.get_image()
	# Headless/dummy renderer keeps no texture data — read the source file instead.
	if img == null or img.is_empty():
		img = Image.load_from_file(path)
	if img == null or img.is_empty():
		push_warning("CardArt: could not load %s" % path)
		img = Image.create(CARD_SIZE.x, CARD_SIZE.y, false, Image.FORMAT_RGBA8)
		img.fill(Color.MAGENTA)
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	_images[path] = img
	return img
