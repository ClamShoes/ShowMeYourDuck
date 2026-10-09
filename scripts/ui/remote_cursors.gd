extends Control
## Other players' pointers: an arrow filled with their seat colour. Points arrive at ~20 Hz, so each
## arrow eases toward its latest point.

const ARROW := [
	Vector2(0, 0), Vector2(0, 18), Vector2(4.5, 14), Vector2(7.5, 21),
	Vector2(10.5, 19.5), Vector2(7.5, 12.5), Vector2(13, 12.5),
]
const OUTLINE := Color(0.08, 0.08, 0.08, 0.9)
const FOLLOW_RATE := 18.0

## pid -> {pos, target, color, angle}
var _cursors: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## `angle` is the owner's seat rotation, so the arrow points the way it does on their screen.
func set_cursor(pid: String, at: Vector2, color: Color, angle: float = 0.0) -> void:
	if not _cursors.has(pid):
		_cursors[pid] = {pos = at, target = at, color = color, angle = angle}
	else:
		_cursors[pid].target = at
		_cursors[pid].color = color
		_cursors[pid].angle = angle


func keep_only(ids: Array) -> void:
	for pid in _cursors.keys():
		if not ids.has(pid):
			_cursors.erase(pid)
	queue_redraw()


func _process(delta: float) -> void:
	if _cursors.is_empty():
		return
	var k := 1.0 - exp(-FOLLOW_RATE * delta)
	for c in _cursors.values():
		c.pos = c.pos.lerp(c.target, k)
	queue_redraw()


func _draw() -> void:
	var pts := PackedVector2Array(ARROW)
	pts.append(ARROW[0])
	for c in _cursors.values():
		draw_set_transform(c.pos, c.angle)
		draw_colored_polygon(pts.slice(0, ARROW.size()), c.color)
		draw_polyline(pts, OUTLINE, 1.5, true)
	draw_set_transform(Vector2.ZERO)
