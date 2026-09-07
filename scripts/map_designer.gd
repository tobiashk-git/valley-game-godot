extends Control
# Map design tool (phase 2, 2026-09-07) - PC only, never in the web export
# (see export_presets.cfg). Run from MapDesigner.bat or
#   godot --path <project> res://scenes/MapDesigner.tscn
#
# The canvas is the real Overworld scene (its player parked, its per-tile
# logic off), so what you see is exactly what the game builds from the
# generator plus the recipe (maps/overworld.json, see map_recipe.gd). Tools
# edit the recipe and show the result live; Regenerate rebuilds the world
# from the unsaved recipe (MapRecipe.override), which is also how Undo /
# Redo / Erase restore generated content. Save writes the JSON.
#
# Mouse: left = use the tool (the Pan tool, open by default, drags the
# map; Space + left drag pans in any tool), right / middle drag = pan,
# wheel = zoom. Keys: WASD / arrows pan, H pan tool, 1-8 tools, [ ] brush,
# G grid, M marks, N notes, Ctrl+Z / Ctrl+Y undo / redo, Ctrl+S save,
# R regenerate, Esc drops a carried place back where it was.

const OVERWORLD_SCENE := preload("res://scenes/Overworld.tscn")
const WILD_MONSTER_SCENE := preload("res://scenes/props/WildMonster.tscn")
const TOOLS := ["pan", "tile", "prop", "monster", "remove", "erase", "pick", "note", "move"]
const EDIT_TOOLS := ["tile", "prop", "monster", "remove", "erase", "pick", "note", "move"] # keys 1-8
const TOOL_LABELS := {"pan": "H  Pan (drag the map)", "tile": "1  Paint tile", "prop": "2  Place prop", "monster": "3  Place monster", "remove": "4  Remove generated", "erase": "5  Erase recipe", "pick": "6  Pick", "note": "7  Note", "move": "8  Move place"}
const TOOL_HELP := {
	"pan": "Drag the map with the left mouse button. In any tool, hold Space to drag, or use the right / middle button.",
	"tile": "Paints the chosen ground over the generated map (brush [ ]).",
	"prop": "Puts the chosen prop on the tile; anything generated there is dropped.",
	"monster": "Puts a wild monster of the chosen species on the tile.",
	"remove": "Drops whatever the GENERATOR put on the tile (its tree, rock, obstacle or monster). Not for things you placed - use Erase.",
	"erase": "Takes YOUR recipe entries off the tile (placed props and monsters, painted tiles, notes); the generated content returns. Uses the brush size.",
	"pick": "Reads the tile into the palette.",
	"note": "Pins a design note to the tile (shown only here).",
	"move": "Click a dungeon door, an interior entrance or an NPC camp to pick it up, then click open ground to drop it (Esc cancels). Camps and doors move separately.",
}
const MARK_PLACE := Color(1.0, 0.5, 1.0, 0.95)
const SOLID_SOURCES := [World.SRC_RIVER, World.SRC_MOUNTAIN, World.SRC_GLOOMFEN_WATER, World.SRC_FOREST_WALL, World.SRC_FENCE, World.SRC_GATE, World.SRC_ALTAR]
const TILE_COLOURS := {"grass": Color(0.42, 0.66, 0.3), "frostpeak": Color(0.85, 0.9, 0.95), "badlands": Color(0.8, 0.62, 0.35), "verdantwood": Color(0.25, 0.5, 0.25), "gloomfen": Color(0.4, 0.5, 0.35), "path": Color(0.72, 0.6, 0.42), "river": Color(0.3, 0.5, 0.85), "ford": Color(0.55, 0.7, 0.85), "mountain": Color(0.5, 0.48, 0.5), "gloomfen_water": Color(0.25, 0.4, 0.45), "forest_wall": Color(0.15, 0.35, 0.15)}
const MARK_TILE := Color(0.3, 0.9, 1.0, 0.9)
const MARK_PROP := Color(0.4, 1.0, 0.4, 0.95)
const MARK_MONSTER := Color(1.0, 0.35, 0.35, 0.95)
const MARK_REMOVED := Color(0.75, 0.75, 0.75, 0.9)
const MARK_NOTE := Color(1.0, 0.85, 0.3, 1.0)
const ZOOMS := [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0]
const PAN_SPEED := 900.0
const PANEL_W := 250.0
const BAR_H := 40.0
const UNDO_LIMIT := 100

var recipe: Dictionary = {}
var overworld: Node2D
var stage: Node2D
var camera: Camera2D
var overlay: Node2D
var tool := "pan"
var palette_choice := {"tile": "path", "prop": "MightyOak", "monster": "frost_wolf"}
var brush := 1
var zoom_index := 3
var show_grid := true
var show_marks := true
var show_notes := true
var hover_tile := Vector2i(-1, -1)
var _painting := false
var _panning := false
var _undo: Array = []
var _redo: Array = []
var _dirty := false
var prop_scenes: Dictionary = {}
var _tool_buttons: Dictionary = {}
var _palette_buttons: Dictionary = {}
var _note_dialog: AcceptDialog
var _note_edit: LineEdit
var _note_tile := Vector2i(-1, -1)
var carrying := "" # the place picked up by the Move tool

# UI
var ui: CanvasLayer
var status_label: Label
var readout_label: Label
var zoom_label: Label
var help_label: Label
var palette_box: VBoxContainer
# The palette only serves Paint tile / Place prop / Place monster - it is
# hidden for every other tool (user: an idle list "was confusing").
const PALETTE_TOOLS := ["tile", "prop", "monster"]
var palette_title: Label
var palette_scroll: ScrollContainer
var brush_label: Label
var notes_box: VBoxContainer
var grid_btn: CheckButton
var marks_btn: CheckButton
var notes_btn: CheckButton
var undo_btn: Button
var redo_btn: Button

func _ready() -> void:
	theme = load("res://resources/ui_theme.tres")
	var window: Window = get_window()
	# The game scales its 800-unit canvas to the screen; a design tool wants
	# real pixels and a big window (the verify keeps its own window size).
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	if get_tree().get_script() == null:
		window.size = Vector2i(1400, 900)
		window.title = "Oliver in the Valley of Adventure - map designer"
	stage = Node2D.new()
	stage.name = "Stage"
	add_child(stage)
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.position = Vector2(World.WORLD_CENTER_X * 32 + 16, World.WORLD_CENTER_Y * 32 + 16)
	camera.zoom = Vector2.ONE * ZOOMS[zoom_index]
	stage.add_child(camera)
	camera.make_current()
	overlay = Node2D.new()
	overlay.name = "Overlay"
	overlay.z_index = 100
	overlay.draw.connect(_draw_overlay)
	stage.add_child(overlay)
	_build_ui()
	recipe = _fresh(MapRecipe.load_from(MapRecipe.active_path))
	regenerate()
	_set_tool("pan")
	set_status("Loaded %s" % MapRecipe.active_path)

func _fresh(r: Dictionary) -> Dictionary:
	var out: Dictionary = r.duplicate(true) if not r.is_empty() else {}
	out["version"] = MapRecipe.VERSION
	for k in ["tiles"]:
		if not out.has(k) or typeof(out[k]) != TYPE_DICTIONARY:
			out[k] = {}
	for k in ["props", "monsters", "removed", "notes"]:
		if not out.has(k) or typeof(out[k]) != TYPE_ARRAY:
			out[k] = []
	if not out.has("places") or typeof(out["places"]) != TYPE_DICTIONARY:
		out["places"] = {}
	return out

# --- the world under the tools ---

# Builds the overworld from the live recipe (through MapRecipe.override).
func regenerate() -> void:
	var cam_pos: Vector2 = camera.position
	if overworld != null:
		overworld.queue_free()
	MapRecipe.override = recipe
	overworld = OVERWORLD_SCENE.instantiate()
	stage.add_child(overworld)
	stage.move_child(overworld, 0)
	MapRecipe.override = {}
	# Park the player: renamed so GameState.is_gameplay() is false (the HUD
	# and touch overlays stay hidden), stopped, invisible, camera off; the
	# overworld's own per-tile logic (encounters, reveals) off too.
	var player: Node2D = overworld.get_node("YSort/Player")
	player.name = "ParkedPlayer"
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.visible = false
	var pcam: Camera2D = player.get_node("Camera2D")
	pcam.enabled = false
	overworld.set_process(false)
	overworld.set_physics_process(false)
	camera.make_current()
	camera.position = cam_pos
	prop_scenes = {
		"Tree": overworld.TREE_SCENE, "Rock": overworld.ROCK_SCENE,
		"MightyOak": overworld.MIGHTY_OAK_SCENE, "IceBoulder": overworld.ICE_BOULDER_SCENE, "IceCrystalShard": overworld.ICE_CRYSTAL_SHARD_SCENE,
		"IcePool": overworld.ICE_POOL_SCENE, "FallenLog": overworld.FALLEN_LOG_SCENE, "TangledBush": overworld.TANGLED_BUSH_SCENE,
		"SwampTree": overworld.SWAMP_TREE_SCENE, "SwampFerns": overworld.SWAMP_FERNS_SCENE, "SwampMushrooms": overworld.SWAMP_MUSHROOMS_SCENE,
		"BadlandsPalms": overworld.BADLANDS_PALMS_SCENE, "BadlandsFireGeyser": overworld.BADLANDS_FIRE_GEYSER_SCENE, "BadlandsTumbleweed": overworld.BADLANDS_TUMBLEWEED_SCENE,
	}
	if _palette_buttons.is_empty():
		_build_palette()
	_refresh_notes_list()

func tile_center(pos: Vector2i) -> Vector2:
	return Vector2(pos.x * 32 + 16, pos.y * 32 + 16)

# Generated / recipe things standing on a tile (never the parked player,
# NPCs, entrances, the guardian).
func nodes_at(pos: Vector2i) -> Array:
	var out: Array = []
	var centre: Vector2 = tile_center(pos)
	for child in overworld.get_node("YSort").get_children():
		if not (child is Node2D) or child.is_queued_for_deletion() or child.position.distance_to(centre) >= 1.0:
			continue
		var scene: String = child.scene_file_path.get_file().get_basename()
		if child.name == "ParkedPlayer" or scene in ["NPC", "Boss"] or scene.ends_with("Entrance"):
			continue
		out.append(child)
	return out

func _free_at(pos: Vector2i) -> void:
	for n in nodes_at(pos):
		n.queue_free()

func tile_name_at(pos: Vector2i) -> String:
	var source: int = overworld.tilemap.get_cell_source_id(pos)
	for name in MapRecipe.tile_names().keys():
		if MapRecipe.tile_names()[name] == source:
			return name
	return "source %d" % source

func recipe_at(pos: Vector2i) -> Array:
	var out: Array = []
	var k: String = MapRecipe.key(pos)
	if recipe.tiles.has(k):
		out.append("tile %s" % str(recipe.tiles[k]))
	for e in recipe.props:
		if int(e.x) == pos.x and int(e.y) == pos.y:
			out.append("prop %s" % e.scene)
	for e in recipe.monsters:
		if int(e.x) == pos.x and int(e.y) == pos.y:
			out.append("monster %s" % e.enemy_id)
	if recipe.removed.has(k):
		out.append("removed")
	for e in recipe.notes:
		if int(e.x) == pos.x and int(e.y) == pos.y:
			out.append("note: %s" % e.text)
	var pid: String = World.place_at(pos)
	if pid != "":
		out.append("place %s%s" % [pid, " (moved)" if recipe.places.has(pid) else ""])
	return out

# --- tools (all edit the recipe; the world follows) ---

func _snapshot() -> void:
	_undo.append(recipe.duplicate(true))
	if _undo.size() > UNDO_LIMIT:
		_undo.pop_front()
	_redo.clear()
	_dirty = true
	_update_undo_buttons()

func _brush_tiles(pos: Vector2i) -> Array:
	var out: Array = []
	var half: int = (brush - 1) / 2
	for dy in range(-half, half + 1):
		for dx in range(-half, half + 1):
			var t := pos + Vector2i(dx, dy)
			if MapRecipe.in_world(t):
				out.append(t)
	return out

func _strip_entries(list: Array, pos: Vector2i) -> Array:
	return list.filter(func(e): return not (int(e.x) == pos.x and int(e.y) == pos.y))

# Applies the current tool at a tile. Returns true when the recipe changed.
func apply_at(pos: Vector2i) -> bool:
	if not MapRecipe.in_world(pos):
		return false
	match tool:
		"pan":
			return false
		"tile":
			var name: String = palette_choice.tile
			var source: int = MapRecipe.tile_source(name)
			var changed := false
			for t in _brush_tiles(pos):
				var k: String = MapRecipe.key(t)
				if recipe.tiles.get(k, "") != name:
					if not changed:
						_snapshot()
					changed = true
					recipe.tiles[k] = name
					overworld.tilemap.set_cell(t, source, MapRecipe.atlas_for(source))
			return changed
		"prop":
			var scene_name: String = palette_choice.prop
			_snapshot()
			recipe.props = _strip_entries(recipe.props, pos)
			recipe.monsters = _strip_entries(recipe.monsters, pos)
			recipe.props.append({"scene": scene_name, "x": pos.x, "y": pos.y})
			_free_at(pos)
			overworld._spawn_prop(prop_scenes[scene_name], pos)
			return true
		"monster":
			var enemy_id: String = palette_choice.monster
			_snapshot()
			recipe.props = _strip_entries(recipe.props, pos)
			recipe.monsters = _strip_entries(recipe.monsters, pos)
			recipe.monsters.append({"enemy_id": enemy_id, "x": pos.x, "y": pos.y})
			_free_at(pos)
			overworld._spawn_recipe({"version": 1, "monsters": [{"enemy_id": enemy_id, "x": pos.x, "y": pos.y}]}, {})
			return true
		"remove":
			var k: String = MapRecipe.key(pos)
			if recipe.removed.has(k) or nodes_at(pos).is_empty():
				return false
			_snapshot()
			recipe.removed.append(k)
			_free_at(pos)
			return true
		"erase":
			var changed := false
			for t in _brush_tiles(pos):
				if not recipe_at(t).is_empty():
					if not changed:
						_snapshot()
					changed = true
					var k: String = MapRecipe.key(t)
					recipe.tiles.erase(k)
					recipe.removed.erase(k)
					recipe.props = _strip_entries(recipe.props, t)
					recipe.monsters = _strip_entries(recipe.monsters, t)
					recipe.notes = _strip_entries(recipe.notes, t)
					var pid: String = World.place_at(t)
					if pid != "" and recipe.places.has(pid):
						recipe.places.erase(pid) # back to its default spot
			if changed:
				regenerate()
			return changed
		"move":
			if carrying == "":
				var pid: String = World.place_at(pos)
				if pid == "":
					set_status("Nothing to move here - click a door or a camp")
					return false
				carrying = pid
				set_status("Carrying %s - click open ground to drop it, Esc to cancel" % World.PLACE_LABELS[pid])
				return false
			if overworld.tilemap.get_cell_source_id(pos) in SOLID_SOURCES:
				set_status("Can't drop %s on solid ground" % World.PLACE_LABELS[carrying])
				return false
			var other: String = World.place_at(pos)
			if other != "" and other != carrying:
				set_status("%s already stands there" % World.PLACE_LABELS[other])
				return false
			_snapshot()
			if pos == World.PLACE_DEFAULTS[carrying]:
				recipe.places.erase(carrying)
			else:
				recipe.places[carrying] = [pos.x, pos.y]
			set_status("%s moved to (%d, %d)" % [World.PLACE_LABELS[carrying], pos.x, pos.y])
			carrying = ""
			regenerate()
			return true
		"pick":
			for e in recipe.monsters:
				if int(e.x) == pos.x and int(e.y) == pos.y:
					palette_choice.monster = e.enemy_id
					_set_tool("monster")
					return false
			for e in recipe.props:
				if int(e.x) == pos.x and int(e.y) == pos.y:
					palette_choice.prop = e.scene
					_set_tool("prop")
					return false
			var name: String = tile_name_at(pos)
			if MapRecipe.tile_names().has(name):
				palette_choice.tile = name
				_set_tool("tile")
			return false
		"note":
			_note_tile = pos
			var existing := ""
			for e in recipe.notes:
				if int(e.x) == pos.x and int(e.y) == pos.y:
					existing = e.text
			_note_edit.text = existing
			_note_dialog.title = "Note at (%d, %d)" % [pos.x, pos.y]
			_note_dialog.popup_centered()
			_note_edit.grab_focus()
			return false
	return false

func set_note(pos: Vector2i, text: String) -> void:
	_snapshot()
	recipe.notes = _strip_entries(recipe.notes, pos)
	if text.strip_edges() != "":
		recipe.notes.append({"x": pos.x, "y": pos.y, "text": text.strip_edges()})
	_refresh_notes_list()

func undo() -> void:
	if _undo.is_empty():
		return
	_redo.append(recipe.duplicate(true))
	recipe = _undo.pop_back()
	_dirty = true
	regenerate()
	_update_undo_buttons()
	set_status("Undo")

func redo() -> void:
	if _redo.is_empty():
		return
	_undo.append(recipe.duplicate(true))
	recipe = _redo.pop_back()
	_dirty = true
	regenerate()
	_update_undo_buttons()
	set_status("Redo")

func save() -> bool:
	var ok: bool = MapRecipe.save_to(MapRecipe.active_path, recipe)
	_dirty = not ok
	set_status(("Saved %s" % MapRecipe.active_path) if ok else ("Could not write %s" % MapRecipe.active_path))
	return ok

func reload() -> void:
	recipe = _fresh(MapRecipe.load_from(MapRecipe.active_path))
	_undo.clear()
	_redo.clear()
	_dirty = false
	regenerate()
	_update_undo_buttons()
	set_status("Reloaded %s" % MapRecipe.active_path)

# --- camera ---

func set_zoom_index(i: int, around: Vector2 = Vector2.INF) -> void:
	zoom_index = clampi(i, 0, ZOOMS.size() - 1)
	var before: Vector2 = camera.get_global_mouse_position() if around == Vector2.INF else around
	camera.zoom = Vector2.ONE * ZOOMS[zoom_index]
	if around != Vector2.INF:
		var after: Vector2 = camera.get_global_mouse_position()
		camera.position += before - after
	zoom_label.text = "%d%%" % int(ZOOMS[zoom_index] * 100)

func mouse_tile() -> Vector2i:
	var p: Vector2 = camera.get_global_mouse_position()
	return Vector2i(floori(p.x / 32.0), floori(p.y / 32.0))

func _over_ui() -> bool:
	var m: Vector2 = get_viewport().get_mouse_position()
	return m.x < PANEL_W or m.y < BAR_H or m.y > get_viewport().get_visible_rect().size.y - BAR_H

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			set_zoom_index(zoom_index + 1, camera.get_global_mouse_position())
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			set_zoom_index(zoom_index - 1, camera.get_global_mouse_position())
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if not mb.pressed:
				_painting = false
				_panning = false
			elif not _over_ui():
				if tool == "pan" or Input.is_key_pressed(KEY_SPACE):
					_panning = true
				else:
					_painting = true
					apply_at(mouse_tile())
		elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _panning:
			camera.position -= mm.relative / camera.zoom.x
		elif _painting and tool in ["tile", "erase", "remove"]:
			apply_at(mouse_tile())
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: InputEventKey = event
		if k.ctrl_pressed and k.keycode == KEY_Z:
			undo()
		elif k.ctrl_pressed and k.keycode == KEY_Y:
			redo()
		elif k.ctrl_pressed and k.keycode == KEY_S:
			save()
		elif k.keycode == KEY_R:
			regenerate()
			set_status("Regenerated")
		elif k.keycode == KEY_G:
			grid_btn.button_pressed = not grid_btn.button_pressed
		elif k.keycode == KEY_M:
			marks_btn.button_pressed = not marks_btn.button_pressed
		elif k.keycode == KEY_N:
			notes_btn.button_pressed = not notes_btn.button_pressed
		elif k.keycode == KEY_BRACKETLEFT:
			set_brush(brush - 2)
		elif k.keycode == KEY_BRACKETRIGHT:
			set_brush(brush + 2)
		elif k.keycode == KEY_H:
			_set_tool("pan")
		elif k.keycode == KEY_ESCAPE and carrying != "":
			carrying = ""
			set_status("Dropped back")
		elif k.keycode >= KEY_1 and k.keycode <= KEY_8:
			_set_tool(EDIT_TOOLS[k.keycode - KEY_1])

func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) and not Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if dir != Vector2.ZERO and not (_note_dialog != null and _note_dialog.visible):
		camera.position += dir.normalized() * PAN_SPEED * delta / camera.zoom.x
	if overworld != null:
		var t: Vector2i = mouse_tile()
		if t != hover_tile:
			hover_tile = t
			_update_readout()
	overlay.queue_redraw()

func _update_readout() -> void:
	if not MapRecipe.in_world(hover_tile):
		readout_label.text = ""
		return
	var biome: Dictionary = World.biome_at(hover_tile.x, hover_tile.y)
	var parts: Array = ["(%d, %d)" % [hover_tile.x, hover_tile.y], World.ZONE_NAMES.get(biome.zone, "?"), "ground: %s" % tile_name_at(hover_tile)]
	var things: Array = []
	for n in nodes_at(hover_tile):
		var scene: String = n.scene_file_path.get_file().get_basename()
		things.append(("%s (%s)" % [scene, n.enemy_id]) if scene == "WildMonster" else scene)
	if not things.is_empty():
		parts.append("here: " + ", ".join(things))
	var r: Array = recipe_at(hover_tile)
	if not r.is_empty():
		parts.append("recipe: " + ", ".join(r))
	readout_label.text = "   ".join(parts)

# --- overlay ---

func _draw_overlay() -> void:
	if overworld == null:
		return
	var view: Rect2 = Rect2(camera.get_screen_center_position() - get_viewport().get_visible_rect().size / camera.zoom.x / 2.0, get_viewport().get_visible_rect().size / camera.zoom.x)
	var x0: int = maxi(0, floori(view.position.x / 32.0))
	var y0: int = maxi(0, floori(view.position.y / 32.0))
	var x1: int = mini(World.OVERWORLD_WIDTH, ceili(view.end.x / 32.0) + 1)
	var y1: int = mini(World.OVERWORLD_HEIGHT, ceili(view.end.y / 32.0) + 1)
	if show_grid and camera.zoom.x >= 0.5:
		var gc := Color(1, 1, 1, 0.08)
		for x in range(x0, x1 + 1):
			overlay.draw_line(Vector2(x * 32, y0 * 32), Vector2(x * 32, y1 * 32), gc)
		for y in range(y0, y1 + 1):
			overlay.draw_line(Vector2(x0 * 32, y * 32), Vector2(x1 * 32, y * 32), gc)
	if show_marks:
		for k in recipe.tiles.keys():
			var p: Vector2i = MapRecipe.pos_of(String(k))
			overlay.draw_rect(Rect2(p.x * 32 + 1, p.y * 32 + 1, 30, 30), MARK_TILE, false, 1.5)
		for e in recipe.props:
			overlay.draw_rect(Rect2(int(e.x) * 32 + 2, int(e.y) * 32 + 2, 28, 28), MARK_PROP, false, 2.0)
		for e in recipe.monsters:
			overlay.draw_rect(Rect2(int(e.x) * 32 + 2, int(e.y) * 32 + 2, 28, 28), MARK_MONSTER, false, 2.0)
		for k in recipe.removed:
			var p: Vector2i = MapRecipe.pos_of(String(k))
			var o := Vector2(p.x * 32, p.y * 32)
			overlay.draw_line(o + Vector2(6, 6), o + Vector2(26, 26), MARK_REMOVED, 2.0)
			overlay.draw_line(o + Vector2(26, 6), o + Vector2(6, 26), MARK_REMOVED, 2.0)
		# Movable places: an outline and, zoomed in, the name; the carried one blinks.
		var pfont: Font = ThemeDB.fallback_font
		for pid in World.PLACE_DEFAULTS.keys():
			var pp: Vector2i = World.place(pid)
			var colour: Color = MARK_PLACE
			if pid == carrying and int(Time.get_ticks_msec() / 250) % 2 == 0:
				colour = Color(1, 1, 1, 1)
			overlay.draw_rect(Rect2(pp.x * 32 - 2, pp.y * 32 - 2, 36, 36), colour, false, 2.0)
			if camera.zoom.x >= 0.75:
				overlay.draw_string(pfont, Vector2(pp.x * 32 - 2, pp.y * 32 - 6), World.PLACE_LABELS[pid], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, colour)
	if show_notes:
		var font: Font = ThemeDB.fallback_font
		for e in recipe.notes:
			var o := Vector2(int(e.x) * 32 + 16, int(e.y) * 32 + 16)
			overlay.draw_circle(o, 7.0, MARK_NOTE)
			overlay.draw_circle(o, 7.0, Color(0.2, 0.15, 0.05), false, 1.5)
			if camera.zoom.x >= 0.75:
				var text: String = String(e.text)
				var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 8.0
				overlay.draw_rect(Rect2(o.x + 10, o.y - 12, w, 20), Color(0.1, 0.08, 0.04, 0.85))
				overlay.draw_string(font, Vector2(o.x + 14, o.y + 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MARK_NOTE)
	if MapRecipe.in_world(hover_tile) and not _over_ui() and tool != "pan":
		var half: int = (brush - 1) / 2 if tool in ["tile", "erase"] else 0
		var r := Rect2((hover_tile.x - half) * 32, (hover_tile.y - half) * 32, (2 * half + 1) * 32, (2 * half + 1) * 32)
		overlay.draw_rect(r, Color(1, 1, 1, 0.9), false, 2.0)

# --- UI ---

func _button(text: String, parent: Node, callback: Callable, variation: StringName = &"SecondaryButton") -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(0, 28)
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func _toggle(text: String, parent: Node, initial: bool, callback: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = initial
	c.add_theme_font_size_override("font_size", 13)
	c.toggled.connect(callback)
	parent.add_child(c)
	return c

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.name = "UI"
	ui.layer = 10
	add_child(ui)
	# Top bar.
	var top := PanelContainer.new()
	top.name = "TopBar"
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.custom_minimum_size = Vector2(0, BAR_H)
	ui.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	top.add_child(row)
	var title := Label.new()
	title.text = "Map designer"
	title.theme_type_variation = &"PanelTitle"
	row.add_child(title)
	_button("Save (Ctrl+S)", row, save, &"PrimaryButton")
	_button("Reload", row, reload)
	_button("Regenerate (R)", row, func() -> void:
		regenerate()
		set_status("Regenerated"))
	undo_btn = _button("Undo", row, undo)
	redo_btn = _button("Redo", row, redo)
	grid_btn = _toggle("Grid (G)", row, show_grid, func(on: bool) -> void: show_grid = on)
	marks_btn = _toggle("Marks (M)", row, show_marks, func(on: bool) -> void: show_marks = on)
	notes_btn = _toggle("Notes (N)", row, show_notes, func(on: bool) -> void: show_notes = on)
	_button("-", row, func() -> void: set_zoom_index(zoom_index - 1))
	zoom_label = Label.new()
	zoom_label.text = "%d%%" % int(ZOOMS[zoom_index] * 100)
	zoom_label.custom_minimum_size = Vector2(44, 0)
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(zoom_label)
	_button("+", row, func() -> void: set_zoom_index(zoom_index + 1))
	status_label = Label.new()
	status_label.name = "Status"
	status_label.theme_type_variation = &"DimLabel"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(status_label)
	# Bottom bar: the readout.
	var bottom := PanelContainer.new()
	bottom.name = "BottomBar"
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.custom_minimum_size = Vector2(0, BAR_H)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui.add_child(bottom)
	readout_label = Label.new()
	readout_label.name = "Readout"
	readout_label.add_theme_font_size_override("font_size", 13)
	bottom.add_child(readout_label)
	# Left panel: tools, brush, palette, notes.
	var left := PanelContainer.new()
	left.name = "LeftPanel"
	left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left.offset_top = BAR_H
	left.offset_bottom = -BAR_H
	left.custom_minimum_size = Vector2(PANEL_W, 0)
	ui.add_child(left)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	left.add_child(col)
	var tools_title := Label.new()
	tools_title.text = "Tools"
	tools_title.theme_type_variation = &"PanelTitle"
	tools_title.add_theme_font_size_override("font_size", 14)
	col.add_child(tools_title)
	for t in TOOLS:
		_tool_buttons[t] = _button(TOOL_LABELS[t], col, _set_tool.bind(t), &"TabButton")
	help_label = Label.new()
	help_label.theme_type_variation = &"DimLabel"
	help_label.add_theme_font_size_override("font_size", 11)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.custom_minimum_size = Vector2(PANEL_W - 16, 40)
	col.add_child(help_label)
	var brush_row := HBoxContainer.new()
	col.add_child(brush_row)
	_button("[", brush_row, func() -> void: set_brush(brush - 2))
	brush_label = Label.new()
	brush_label.text = "Brush 1"
	brush_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brush_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brush_row.add_child(brush_label)
	_button("]", brush_row, func() -> void: set_brush(brush + 2))
	palette_title = Label.new()
	palette_title.name = "PaletteTitle"
	palette_title.text = "Palette"
	palette_title.theme_type_variation = &"PanelTitle"
	palette_title.add_theme_font_size_override("font_size", 14)
	col.add_child(palette_title)
	palette_scroll = ScrollContainer.new()
	palette_scroll.name = "PaletteScroll"
	palette_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette_scroll.custom_minimum_size = Vector2(0, 160)
	palette_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(palette_scroll)
	palette_box = VBoxContainer.new()
	palette_box.name = "Palette"
	palette_box.add_theme_constant_override("separation", 2)
	palette_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette_scroll.add_child(palette_box)
	var notes_title := Label.new()
	notes_title.text = "Notes"
	notes_title.theme_type_variation = &"PanelTitle"
	notes_title.add_theme_font_size_override("font_size", 14)
	col.add_child(notes_title)
	var notes_scroll := ScrollContainer.new()
	notes_scroll.custom_minimum_size = Vector2(0, 120)
	notes_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(notes_scroll)
	notes_box = VBoxContainer.new()
	notes_box.name = "NotesList"
	notes_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes_scroll.add_child(notes_box)
	# The note dialog.
	_note_dialog = AcceptDialog.new()
	_note_dialog.name = "NoteDialog"
	_note_dialog.ok_button_text = "Pin note"
	_note_edit = LineEdit.new()
	_note_edit.placeholder_text = "What goes here? (empty removes the note)"
	_note_edit.custom_minimum_size = Vector2(420, 0)
	_note_dialog.add_child(_note_edit)
	_note_dialog.confirmed.connect(func() -> void: set_note(_note_tile, _note_edit.text))
	_note_edit.text_submitted.connect(func(_t: String) -> void:
		_note_dialog.hide()
		set_note(_note_tile, _note_edit.text))
	ui.add_child(_note_dialog)
	_update_undo_buttons()

func _set_tool(t: String) -> void:
	tool = t
	for id in _tool_buttons.keys():
		_tool_buttons[id].theme_type_variation = &"TabButtonActive" if id == t else &"TabButton"
	help_label.text = TOOL_HELP[t]
	var uses_palette: bool = PALETTE_TOOLS.has(t)
	if palette_title != null:
		palette_title.visible = uses_palette
		palette_scroll.visible = uses_palette
	_build_palette()

func set_brush(b: int) -> void:
	brush = clampi(b, 1, 9)
	brush_label.text = "Brush %d" % brush

func _palette_entries() -> Array:
	match tool:
		"tile":
			return MapRecipe.tile_names().keys()
		"prop":
			return prop_scenes.keys()
		"monster":
			return Enemies.ENEMIES.keys()
	return [] # the other tools do not use the palette (and it is hidden)

func _palette_kind() -> String:
	return "prop" if tool == "prop" else ("monster" if tool == "monster" else "tile")

func _build_palette() -> void:
	for child in palette_box.get_children():
		child.queue_free()
	_palette_buttons.clear()
	var kind: String = _palette_kind()
	for id in _palette_entries():
		var b := Button.new()
		b.name = String(id).to_pascal_case() + "Choice"
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 26)
		b.add_theme_font_size_override("font_size", 12)
		b.theme_type_variation = &"TabButtonActive" if palette_choice[kind] == id else &"TabButton"
		if kind == "tile":
			b.text = "   " + String(id)
			b.icon = _swatch(TILE_COLOURS.get(id, Color.MAGENTA))
		elif kind == "monster":
			b.text = "%s" % Enemies.ENEMIES[id].name
			var tex_path: String = Enemies.ENEMIES[id].get("sprite", "")
			if tex_path != "" and ResourceLoader.exists(tex_path):
				b.icon = load(tex_path)
				b.expand_icon = true
		else:
			b.text = String(id)
		b.pressed.connect(func() -> void:
			palette_choice[kind] = id
			_build_palette())
		palette_box.add_child(b)
		_palette_buttons[id] = b

func _swatch(c: Color) -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)

func _refresh_notes_list() -> void:
	if notes_box == null:
		return
	for child in notes_box.get_children():
		child.queue_free()
	for e in recipe.notes:
		var b := Button.new()
		b.text = "(%d,%d) %s" % [int(e.x), int(e.y), String(e.text).left(28)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.theme_type_variation = &"TabButton"
		b.add_theme_font_size_override("font_size", 11)
		b.custom_minimum_size = Vector2(0, 24)
		var target := Vector2i(int(e.x), int(e.y))
		b.pressed.connect(func() -> void: camera.position = tile_center(target))
		notes_box.add_child(b)

func _update_undo_buttons() -> void:
	if undo_btn != null:
		undo_btn.disabled = _undo.is_empty()
		redo_btn.disabled = _redo.is_empty()

func set_status(text: String) -> void:
	status_label.text = text + ("   (unsaved changes)" if _dirty else "")
