class_name PlayerCosmetics
extends RefCounted
## Local profile: display name + card back/front choice, saved in user://cosmetics.cfg
## (IndexedDB on the web build). Command-line user args (`-- --name=<n> --card-back=<id>
## --card-front=<id>`) override for this run and are never written back.

const CardCatalog = preload("res://scripts/ui/card_catalog.gd")
const DuckStamps = preload("res://scripts/ui/duck_stamps.gd")
const PATH := "user://cosmetics.cfg"
const DEFAULT_NAME := "Mallard"
const MAX_NAME_LEN := 24

## Overridable so tests don't touch the real profile.
static var path := PATH


static func load_local() -> Dictionary:
	var raw := {}
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		raw.card_back_id = cfg.get_value("cards", "back", "")
		raw.card_front_id = cfg.get_value("cards", "front", "")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--card-back="):
			raw.card_back_id = arg.get_slice("=", 1)
		elif arg.begins_with("--card-front="):
			raw.card_front_id = arg.get_slice("=", 1)
	var out := CardCatalog.sanitize(raw)
	out.duck_progress = load_progress()
	return out


## Stamps earned on the current duck drawing (and the destroy styles they unlocked).
static func load_progress() -> Dictionary:
	return DuckStamps.sanitize_progress(_load_cfg().get_value("duck", "progress", {}))


static func save_progress(progress: Dictionary) -> void:
	var cfg := _load_cfg()
	cfg.set_value("duck", "progress", DuckStamps.sanitize_progress(progress))
	cfg.save(path)


static func save_local(cosmetics: Dictionary) -> void:
	var c := CardCatalog.sanitize(cosmetics)
	var cfg := _load_cfg()
	cfg.set_value("cards", "back", c.card_back_id)
	cfg.set_value("cards", "front", c.card_front_id)
	cfg.save(path)


static func load_name() -> String:
	var arg_name := _arg_name()
	if arg_name != "":
		return arg_name
	return clean_name(String(_load_cfg().get_value("profile", "name", DEFAULT_NAME)))


static func save_name(display_name: String) -> void:
	# A --name= run (dev multi-client) must not overwrite the saved profile.
	if _arg_name() != "":
		return
	var cfg := _load_cfg()
	cfg.set_value("profile", "name", clean_name(display_name))
	cfg.save(path)


static func clean_name(display_name: String) -> String:
	var n := display_name.strip_edges().left(MAX_NAME_LEN)
	return n if n != "" else DEFAULT_NAME


static func _arg_name() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--name="):
			return clean_name(arg.get_slice("=", 1))
	return ""


static func _load_cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(path)
	return cfg
