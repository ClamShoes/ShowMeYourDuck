extends RefCounted
## Shared "seat space": every client draws the table rotated with itself at the bottom, so raw
## screen points can't be shared. A point is sent as (anchor, local) instead, where the anchor is
## something every screen has (a player's hand, a player's mat, or the screen centre) and is
## rebuilt with the receiver's own transform for that anchor.
## Anchors are Dictionaries {name, xf: Transform2D (local -> global), rect: Rect2 (local)}.

const PlayerMatScript = preload("res://scripts/ui/player_mat.gd")

## The viewer's own hand box. Opponent hands use the same local layout so slot i lines up.
const HAND_POS := Vector2(280, 560)
const HAND_SIZE := Vector2(720, 150)
## Middle of the seat ring from PlayerMat.seat_layout (mat centres).
const TABLE_CENTRE := Vector2(640, 294)
const OPP_HAND_SCALE := 0.6
## Mat centre -> opponent hand centre, away from the table centre.
const OPP_HAND_OUTSET := 150.0
## Top-row seats lean their hand outward by up to this much at the screen's side edges.
const TOP_FAN_DEG := 35.0
const CENTRE := "centre"
## Discard pick row area around the viewport centre.
const CENTRE_RECT := Rect2(-640, -110, 1280, 220)
## map_point is exact this far (screen px) inside an anchor rect; cards sit deeper than this.
const EXACT_BAND := 8.0


## How far a seat is turned on this screen: the viewer is 0, everyone else faces the table centre
## (`seat_dir` points at it), with top-row seats fanned outward. Hand, mat and cursor all use it.
static func seat_rotation(mat_pos: Vector2, seat_dir: Vector2, is_viewer: bool) -> float:
	if is_viewer:
		return 0.0
	var out := -seat_dir
	if out == Vector2.UP:
		var cx := mat_pos.x + PlayerMatScript.MAT_SIZE.x * 0.5
		out = out.rotated(deg_to_rad(TOP_FAN_DEG) * (cx - TABLE_CENTRE.x) / TABLE_CENTRE.x)
	return out.angle() - PI * 0.5


## Mat-local -> global: matches a PlayerMat at `mat_pos` with a centre pivot and `rotation = rot`.
static func mat_xform(mat_pos: Vector2, rot: float) -> Transform2D:
	var half := PlayerMatScript.MAT_SIZE * 0.5
	return Transform2D(rot, mat_pos + half) * Transform2D(0.0, -half)


## Hand-local -> global for a seat.
static func hand_xform(mat_pos: Vector2, seat_dir: Vector2, is_viewer: bool) -> Transform2D:
	if is_viewer:
		return Transform2D(0.0, HAND_POS)
	var rot := seat_rotation(mat_pos, seat_dir, false)
	var s := Vector2(OPP_HAND_SCALE, OPP_HAND_SCALE)
	var basis := Transform2D(rot, s, 0.0, Vector2.ZERO)
	var centre := mat_pos + PlayerMatScript.MAT_SIZE * 0.5 + Vector2.DOWN.rotated(rot) * OPP_HAND_OUTSET
	return Transform2D(rot, s, 0.0, centre - basis.basis_xform(HAND_SIZE * 0.5))


## Moves a card off a rotated/scaled seat keeping its on-screen pose. `Node.reparent(_, true)`
## keeps only a Control's position, so a card leaving an opponent hand or mat would pop upright
## and full size.
static func reparent_keep_pose(c: Control, new_parent: Node) -> void:
	var xf := c.get_global_transform()
	c.reparent(new_parent, false)
	var parent_xf: Transform2D = new_parent.get_global_transform() if new_parent is CanvasItem else Transform2D.IDENTITY
	var local := parent_xf.affine_inverse() * xf
	c.rotation = local.get_rotation()
	c.scale = local.get_scale()
	c.position = local * c.pivot_offset - c.pivot_offset


## Seats as `viewer` lays them out: [{pid, pos, dir}], ids in snapshot order rotated so the viewer
## is first. Any client can rebuild another player's screen with it.
static func seat_list(ids: Array, viewer: String) -> Array:
	var order := ids.duplicate()
	if viewer in order:
		while String(order[0]) != viewer:
			order.append(order.pop_front())
	var layout: Array = PlayerMatScript.seat_layout(order.size())
	var out: Array = []
	for i in order.size():
		out.append({pid = String(order[i]), pos = layout[i].pos, dir = layout[i].dir})
	return out


## Maps a point from one screen's anchors to another's. In open table space it blends every
## anchor's mapping by inverse squared distance, so the point slides between seats instead of
## snapping to whichever is nearest. Inside an anchor rect it eases to that anchor's exact mapping
## over EXACT_BAND px (same priority as `encode`), so overlapping rects hand over without a snap.
static func map_point(p: Vector2, from_anchors: Array, to_anchors: Array, use_centre: bool) -> Vector2:
	var to_xf: Dictionary = {}
	for a in to_anchors:
		to_xf[a.name] = a.xf
	var sum := Vector2.ZERO
	var wsum := 0.0
	## [q, depth inside the rect in screen px], highest priority first
	var inside: Array = []
	for a in from_anchors:
		if (a.name == CENTRE and not use_centre) or not to_xf.has(a.name):
			continue
		var xf: Transform2D = a.xf
		var rect: Rect2 = a.rect
		var local: Vector2 = xf.affine_inverse() * p
		var q: Vector2 = to_xf[a.name] * local
		if rect.has_point(local):
			var edge := minf(minf(local.x - rect.position.x, rect.end.x - local.x), minf(local.y - rect.position.y, rect.end.y - local.y))
			inside.append([q, edge * xf.get_scale().x])
		var w := 1.0 / (p.distance_squared_to(xf * local.clamp(rect.position, rect.end)) + 1.0)
		sum += q * w
		wsum += w
	var out := sum / wsum if wsum > 0.0 else p
	for i in range(inside.size() - 1, -1, -1):
		out = out.lerp(inside[i][0], clampf(inside[i][1] / EXACT_BAND, 0.0, 1.0))
	return out


## `seats`: [{pid, pos (mat top-left), dir (seat_layout dir)}]. Order = encode priority:
## hands, then the centre, then mats.
static func anchors(seats: Array, viewer: String, vp: Vector2) -> Array:
	var out: Array = []
	for s in seats:
		out.append({
			name = "hand:%s" % s.pid,
			xf = hand_xform(s.pos, s.dir, String(s.pid) == viewer),
			rect = Rect2(Vector2.ZERO, HAND_SIZE),
		})
	out.append({name = CENTRE, xf = Transform2D(0.0, vp * 0.5), rect = CENTRE_RECT})
	for s in seats:
		out.append({
			name = "mat:%s" % s.pid,
			xf = mat_xform(s.pos, seat_rotation(s.pos, s.dir, String(s.pid) == viewer)),
			rect = Rect2(Vector2.ZERO, PlayerMatScript.MAT_SIZE),
		})
	return out


## [anchor_name, local] for a global point: the first anchor containing it, else the nearest.
## The centre anchor only counts while the discard pick row is up (it overlaps the viewer's mat).
static func encode(p: Vector2, anchor_list: Array, use_centre: bool) -> Array:
	var best: Array = []
	var best_d := INF
	for a in anchor_list:
		if a.name == CENTRE and not use_centre:
			continue
		var xf: Transform2D = a.xf
		var rect: Rect2 = a.rect
		var local: Vector2 = xf.affine_inverse() * p
		if rect.has_point(local):
			return [a.name, local]
		var d := p.distance_squared_to(xf * local.clamp(rect.position, rect.end))
		if d < best_d:
			best_d = d
			best = [a.name, local]
	return best


## Global point on this screen, or null when this screen has no such anchor.
static func decode(anchor_name: String, local: Vector2, anchor_list: Array) -> Variant:
	for a in anchor_list:
		if a.name == anchor_name:
			var xf: Transform2D = a.xf
			return xf * local
	return null
