extends RefCounted
## Fitting the 1280x720 design onto any screen (desktop, web, phones, tablets).

## Design size. canvas_items + expand stretch never makes the viewport smaller than this.
const BASE := Vector2(1280, 720)


## The part of the viewport clear of notches and rounded corners, in viewport coordinates.
static func safe_rect(vp: Viewport) -> Rect2:
	var full := vp.get_visible_rect()
	if not OS.has_feature("mobile"):
		return full
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0.0 or win.y <= 0.0:
		return full
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var k := full.size / win
	return Rect2(full.position + safe.position * k, safe.size * k).intersection(full)


## A BASE-sized Control that stays centred in `parent` (menus and pop-ups lay out inside it).
static func centred_stage(parent: Control) -> Control:
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.anchor_left = 0.5
	stage.anchor_right = 0.5
	stage.anchor_top = 0.5
	stage.anchor_bottom = 0.5
	stage.offset_left = -BASE.x * 0.5
	stage.offset_right = BASE.x * 0.5
	stage.offset_top = -BASE.y * 0.5
	stage.offset_bottom = BASE.y * 0.5
	parent.add_child(stage)
	return stage
