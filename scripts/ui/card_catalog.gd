class_name CardCatalog
extends RefCounted
## Selectable card backs and fronts (frames). Pure data — safe to use on the headless server.
## Entry keys: path, region (Rect2i, optional), overlay_path + overlay_region (optional, centered on top),
## tint (Color multiply, optional), label.

const BACK_SHEET := "res://assets/cardBacks.png"
const FRAME_SHEET := "res://assets/cardbacks4092021.png"

const DEFAULT_BACK := "classic"
const DEFAULT_FRONT := "bordered"

const BACKS := {
	"classic": {"label": "Classic", "path": "res://assets/cardback.png"},
	"ember": {"label": "Ember", "path": BACK_SHEET, "region": Rect2i(14, 12, 96, 128)},
	"amber": {"label": "Amber", "path": BACK_SHEET, "region": Rect2i(120, 12, 96, 128)},
	"silver": {"label": "Silver", "path": BACK_SHEET, "region": Rect2i(226, 12, 96, 128)},
	"verdant": {"label": "Verdant", "path": BACK_SHEET, "region": Rect2i(332, 12, 96, 128)},
	"frost": {"label": "Frost", "path": BACK_SHEET, "region": Rect2i(14, 146, 96, 128)},
	"jade": {"label": "Jade", "path": BACK_SHEET, "region": Rect2i(120, 146, 96, 128)},
	"harvest": {"label": "Harvest", "path": BACK_SHEET, "region": Rect2i(226, 146, 96, 128)},
	"rose": {"label": "Rose", "path": BACK_SHEET, "region": Rect2i(332, 146, 96, 128)},
	"crimson": {"label": "Crimson", "path": BACK_SHEET, "region": Rect2i(14, 280, 96, 128)},
	"sapphire": {"label": "Sapphire", "path": BACK_SHEET, "region": Rect2i(120, 280, 96, 128)},
	"sunburst": {"label": "Sunburst", "path": "res://assets/cardback2.png"},
	"blade": {"label": "Blade", "path": BACK_SHEET, "region": Rect2i(332, 280, 96, 128)},
	"gold_rune": {"label": "Gold rune", "path": BACK_SHEET, "region": Rect2i(14, 413, 96, 128)},
	"ice_rune": {"label": "Ice rune", "path": BACK_SHEET, "region": Rect2i(119, 413, 96, 128)},
	"ash_rune": {"label": "Ash rune", "path": BACK_SHEET, "region": Rect2i(224, 413, 96, 128)},
	"opal_rune": {"label": "Opal rune", "path": BACK_SHEET, "region": Rect2i(325, 413, 96, 128)},
	"toxic_rune": {"label": "Toxic rune", "path": BACK_SHEET, "region": Rect2i(119, 552, 96, 128)},
	"dusk_rune": {"label": "Dusk rune", "path": BACK_SHEET, "region": Rect2i(224, 552, 96, 128)},
	"sun_crest": {"label": "Sun crest", "path": BACK_SHEET, "region": Rect2i(330, 552, 96, 128)},
}

const FRONTS := {
	"bordered": {"label": "Bordered", "path": FRAME_SHEET, "region": Rect2i(12, 5, 100, 128)},
	"corners": {"label": "Corners", "path": FRAME_SHEET, "region": Rect2i(12, 142, 100, 128)},
	"paper": {"label": "Paper", "path": FRAME_SHEET, "region": Rect2i(12, 276, 100, 128)},
	"gilded": {
		"label": "Gilded",
		"path": FRAME_SHEET,
		"region": Rect2i(12, 276, 100, 128),
		"overlay_path": FRAME_SHEET,
		"overlay_region": Rect2i(126, 276, 88, 128),
	},
	"blush": {
		"label": "Blush",
		"path": FRAME_SHEET,
		"region": Rect2i(12, 5, 100, 128),
		"tint": Color(1.0, 0.84, 0.86),
	},
	"sky": {
		"label": "Sky",
		"path": FRAME_SHEET,
		"region": Rect2i(12, 142, 100, 128),
		"tint": Color(0.8, 0.9, 1.0),
	},
	"classic": {"label": "Classic", "path": "res://assets/cardback2.png"},
}


static func is_valid_back(id: String) -> bool:
	return BACKS.has(id)


static func is_valid_front(id: String) -> bool:
	return FRONTS.has(id)


static func back_entry(id: String) -> Dictionary:
	return BACKS.get(id, BACKS[DEFAULT_BACK])


static func front_entry(id: String) -> Dictionary:
	return FRONTS.get(id, FRONTS[DEFAULT_FRONT])


## Untrusted input (network / config / cmdline) → known ids only.
static func sanitize(cosmetics: Variant) -> Dictionary:
	var src: Dictionary = cosmetics if cosmetics is Dictionary else {}
	var back := String(src.get("card_back_id", ""))
	var front := String(src.get("card_front_id", ""))
	return {
		"card_back_id": back if is_valid_back(back) else DEFAULT_BACK,
		"card_front_id": front if is_valid_front(front) else DEFAULT_FRONT,
	}
