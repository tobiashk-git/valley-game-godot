class_name MapRecipe
extends RefCounted
# Map design recipe (map design tool, phase 1 - 2026-09-07). The generator
# stays the base layer; a recipe stamped over it at Overworld load adds the
# hand-designed parts. Nothing outside the recipe is touched, so the
# existing verifies keep their world.
#
# File: res://maps/overworld.json (see DEFAULT_PATH; a verify swaps
# `active_path`). Format, version 1:
#   {
#     "version": 1,
#     "tiles": {"x,y": "path" | <source id>},   painted over the generated ground
#     "props": [{"scene": "MightyOak", "x": 90, "y": 108}],  prop scenes by name
#     "monsters": [{"enemy_id": "frost_wolf", "x": 88, "y": 108}],
#     "removed": ["x,y"],  a generated prop / wild monster on that tile is dropped
#     "notes": [{"x": 100, "y": 100, "text": "..."}]  design notes (tool only)
#   }
# Every tile a recipe prop or monster stands on is treated as removed too,
# and the scatters are told about all of them so nothing generated lands
# there. Unknown scene / enemy names are skipped with a warning.

const VERSION := 1
const DEFAULT_PATH := "res://maps/overworld.json"
static var active_path: String = DEFAULT_PATH
# The designer's unsaved recipe: when set, load_active() returns it instead
# of reading the file, so a regenerated preview shows the live edits.
static var override: Dictionary = {}

# Tile names the recipe may use instead of raw source ids (the ground and
# solid types; fence / gate / altar carry rotation flags and stay generated).
static func tile_names() -> Dictionary:
	return {
		"grass": World.SRC_GRASS,
		"frostpeak": World.SRC_FROSTPEAK,
		"badlands": World.SRC_BADLANDS,
		"verdantwood": World.SRC_VERDANTWOOD,
		"gloomfen": World.SRC_GLOOMFEN,
		"path": World.SRC_PATH,
		"river": World.SRC_RIVER,
		"ford": World.SRC_FORD,
		"mountain": World.SRC_MOUNTAIN,
		"gloomfen_water": World.SRC_GLOOMFEN_WATER,
		"forest_wall": World.SRC_FOREST_WALL,
	}

static func key(pos: Vector2i) -> String:
	return "%d,%d" % [pos.x, pos.y]

# "x,y" -> Vector2i; Vector2i(-1, -1) for anything malformed.
static func pos_of(text: String) -> Vector2i:
	var parts: PackedStringArray = text.split(",")
	if parts.size() != 2 or not parts[0].strip_edges().is_valid_int() or not parts[1].strip_edges().is_valid_int():
		return Vector2i(-1, -1)
	return Vector2i(int(parts[0]), int(parts[1]))

static func _entry_pos(entry: Dictionary) -> Vector2i:
	if not entry.has("x") or not entry.has("y"):
		return Vector2i(-1, -1)
	return Vector2i(int(entry.x), int(entry.y))

static func in_world(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < World.OVERWORLD_WIDTH and pos.y < World.OVERWORLD_HEIGHT

# The active recipe, or {} when the file is missing or not a version-1 recipe.
static func load_active() -> Dictionary:
	if not override.is_empty():
		return override.duplicate(true)
	return load_from(active_path)

static func load_from(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	return parse(text, path)

static func parse(text: String, label: String = "recipe") -> Dictionary:
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("MapRecipe: %s is not a JSON object - ignored" % label)
		return {}
	if int(data.get("version", 0)) != VERSION:
		push_warning("MapRecipe: %s has version %s, expected %d - ignored" % [label, str(data.get("version", "?")), VERSION])
		return {}
	return data

# A tile value: a source id, or one of tile_names(). -1 when unknown.
static func tile_source(value: Variant) -> int:
	if typeof(value) == TYPE_STRING:
		return int(tile_names().get(value, -1))
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return int(value)
	return -1

static func atlas_for(source: int) -> Vector2i:
	return Vector2i(0, 5) if source == World.SRC_GRASS else Vector2i(0, 0)

# {Vector2i: source id} of the painted tiles (bad keys / values skipped).
static func tiles(recipe: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in recipe.get("tiles", {}).keys():
		var pos: Vector2i = pos_of(String(k))
		var source: int = tile_source(recipe.tiles[k])
		if in_world(pos) and source >= 0:
			out[pos] = source
		else:
			push_warning("MapRecipe: bad tile %s -> %s" % [str(k), str(recipe.tiles[k])])
	return out

static func props(recipe: Dictionary) -> Array:
	var out: Array = []
	for entry in recipe.get("props", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var pos: Vector2i = _entry_pos(entry)
		if in_world(pos) and entry.has("scene"):
			out.append({"scene": String(entry.scene), "pos": pos})
	return out

static func monsters(recipe: Dictionary) -> Array:
	var out: Array = []
	for entry in recipe.get("monsters", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var pos: Vector2i = _entry_pos(entry)
		if in_world(pos) and entry.has("enemy_id"):
			out.append({"enemy_id": String(entry.enemy_id), "pos": pos})
	return out

static func notes(recipe: Dictionary) -> Array:
	var out: Array = []
	for entry in recipe.get("notes", []):
		if typeof(entry) == TYPE_DICTIONARY and entry.has("text"):
			out.append({"pos": _entry_pos(entry), "text": String(entry.text)})
	return out

# Every tile the generator must leave alone: the "removed" list plus every
# recipe prop and monster tile.
static func claimed(recipe: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in recipe.get("removed", []):
		var pos: Vector2i = pos_of(String(k))
		if in_world(pos):
			out[pos] = true
	for entry in props(recipe):
		out[entry.pos] = true
	for entry in monsters(recipe):
		out[entry.pos] = true
	return out

# Paints the recipe's tiles; returns how many.
static func apply_tiles(tilemap: TileMapLayer, recipe: Dictionary) -> int:
	var painted: Dictionary = tiles(recipe)
	for pos in painted.keys():
		tilemap.set_cell(pos, painted[pos], atlas_for(painted[pos]))
	return painted.size()

# --- writing (the designer, phase 2; also handy for tests) ---

static func to_text(recipe: Dictionary) -> String:
	return JSON.stringify(recipe, "  ")

static func save_to(path: String, recipe: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(to_text(recipe))
	f.close()
	return true
