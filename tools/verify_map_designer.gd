extends SceneTree
# Map designer verification (map tool phase 2). Run via:
# godot --script res://tools/verify_map_designer.gd (NOT --headless).
#
# The designer scene builds the real overworld as its canvas with the
# player parked and the game overlays hidden; tools edit the recipe and
# the world follows live (tiles, props, monsters, removal); erase brings
# the generated content back; undo / redo restore through regeneration;
# pick reads the palette; notes pin text; Save writes the JSON the game
# loads; zoom and pan move the camera; the scene is kept out of the web export.

const TEST_PATH := "res://tools/verify_designer_recipe.json"

func _initialize() -> void:
	var world: Node = root.get_node("World")
	await process_frame
	root.get_node("GameState").reset()
	root.get_node("Quests").reset()
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	MapRecipe.active_path = TEST_PATH
	var designer: Control = load("res://scenes/MapDesigner.tscn").instantiate()
	root.add_child(designer)
	current_scene = designer
	for i in range(4):
		await process_frame
	var cx: int = world.WORLD_CENTER_X
	var cy: int = world.WORLD_CENTER_Y

	print("The canvas is the real overworld with the player parked and the game overlays hidden: ", designer.overworld != null and designer.overworld.has_node("YSort/ParkedPlayer") and not designer.overworld.has_node("YSort/Player") and not root.get_node("GameState").is_gameplay() and not root.get_node("HUD").visible)
	print("Camera starts on the altar at 100% with the Pan tool open (a first drag moves the map, paints nothing): ", designer.camera.position == Vector2(cx * 32 + 16, cy * 32 + 16) and designer.camera.zoom == Vector2.ONE and designer.camera.is_current() and designer.tool == "pan" and not designer.apply_at(Vector2i(cx - 8, cy + 8)) and designer.recipe.tiles.is_empty())
	print("Tools, palette and notes panels exist; tile palette lists every recipe tile name: ", designer.ui.has_node("LeftPanel") and designer.palette_box.get_child_count() == MapRecipe.tile_names().size() and designer.ui.has_node("TopBar") and designer.ui.has_node("BottomBar"))

	# --- paint ---
	var t1 := Vector2i(cx - 8, cy + 8)
	designer._set_tool("tile")
	designer.palette_choice.tile = "path"
	designer.set_brush(3)
	var changed: bool = designer.apply_at(t1)
	var painted := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if designer.overworld.tilemap.get_cell_source_id(t1 + Vector2i(dx, dy)) == world.SRC_PATH:
				painted += 1
	print("Paint tile with a 3-brush: nine path tiles on the map and in the recipe: ", changed and painted == 9 and designer.recipe.tiles.size() == 9 and designer.recipe.tiles[MapRecipe.key(t1)] == "path")
	print("Painting the same again changes nothing (no extra undo step): ", not designer.apply_at(t1) and designer._undo.size() == 1)

	# --- props and monsters ---
	var t2 := Vector2i(cx - 12, cy + 8)
	designer._set_tool("prop")
	designer.palette_choice.prop = "MightyOak"
	designer.apply_at(t2)
	var at2: Array = designer.nodes_at(t2)
	print("Place prop: a MightyOak stands on the tile and the recipe lists it: ", at2.size() == 1 and at2[0].scene_file_path.ends_with("MightyOak.tscn") and designer.recipe.props.size() == 1 and designer.recipe.props[0].scene == "MightyOak")
	var t3 := Vector2i(cx - 12, cy + 10)
	designer._set_tool("monster")
	designer.palette_choice.monster = "swamp_hag"
	designer.apply_at(t3)
	var at3: Array = designer.nodes_at(t3)
	print("Place monster: a Swamp Hag stands there with the Gloomfen pool: ", at3.size() == 1 and at3[0].enemy_id == "swamp_hag" and at3[0].zone == world.Zone.GLOOMFEN and designer.recipe.monsters.size() == 1)
	designer._set_tool("prop")
	designer.palette_choice.prop = "Rock"
	designer.apply_at(t3)
	print("Placing a prop over the monster swaps it (one entry per tile): ", designer.recipe.monsters.is_empty() and designer.recipe.props.size() == 2 and designer.nodes_at(t3).size() == 1 and designer.nodes_at(t3)[0].scene_file_path.ends_with("Rock.tscn"))

	# --- remove generated ---
	var generated: Vector2i = designer.overworld.wild_monster_data[0].pos
	designer._set_tool("remove")
	print("Remove generated: the wild monster at ", generated, " goes and the tile is listed as removed: ", designer.nodes_at(generated).size() == 1 and designer.apply_at(generated) and designer.nodes_at(generated).is_empty() and designer.recipe.removed.has(MapRecipe.key(generated)))
	print("Remove on an empty tile (the path north of the altar) is a no-op: ", not designer.apply_at(Vector2i(cx, cy - 2)) and designer.recipe.removed.size() == 1)

	# --- readout and pick ---
	designer.hover_tile = t2
	designer._update_readout()
	print("The readout names the tile, biome, ground and recipe entry: ", designer.readout_label.text.begins_with("(%d, %d)" % [t2.x, t2.y]) and designer.readout_label.text.contains(world.ZONE_NAMES[world.Zone.VALLEY]) and designer.readout_label.text.contains("recipe: prop MightyOak"))
	designer._set_tool("pick")
	designer.palette_choice.prop = "Tree"
	designer.apply_at(t2)
	print("Pick on the oak selects the prop tool with MightyOak: ", designer.tool == "prop" and designer.palette_choice.prop == "MightyOak")
	designer._set_tool("pick")
	designer.apply_at(t1)
	print("Pick on a painted tile selects the tile tool with path: ", designer.tool == "tile" and designer.palette_choice.tile == "path")

	# --- notes ---
	designer.set_note(t2, "The lost camp")
	print("A note pins to the tile and appears in the notes list: ", designer.recipe.notes.size() == 1 and designer.recipe.notes[0].text == "The lost camp" and designer.notes_box.get_child_count() == 1)

	# --- erase brings the generated world back ---
	designer._set_tool("erase")
	designer.set_brush(1)
	designer.apply_at(generated)
	await process_frame
	await process_frame
	print("Erase on the removed tile: the generated monster is back after the regenerate: ", not designer.recipe.removed.has(MapRecipe.key(generated)) and designer.nodes_at(generated).size() == 1)

	# --- undo / redo ---
	var steps: int = designer._undo.size()
	designer.undo()
	await process_frame
	await process_frame
	print("Undo restores the previous recipe (the removal is back, monster gone again): ", designer.recipe.removed.has(MapRecipe.key(generated)) and designer.nodes_at(generated).is_empty() and designer._undo.size() == steps - 1 and designer._redo.size() == 1)
	designer.redo()
	await process_frame
	await process_frame
	print("Redo re-applies it: ", not designer.recipe.removed.has(MapRecipe.key(generated)) and designer.nodes_at(generated).size() == 1 and designer._redo.is_empty())

	# --- save, then the game loads it ---
	print("Save writes the recipe and MapRecipe reads the same back: ", designer.save() and FileAccess.file_exists(TEST_PATH) and MapRecipe.load_from(TEST_PATH).tiles.size() == 9 and MapRecipe.load_from(TEST_PATH).props.size() == 2 and MapRecipe.load_from(TEST_PATH).notes[0].text == "The lost camp")
	designer.queue_free()
	await process_frame
	await process_frame
	var game: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in range(3):
		await process_frame
	var oak_in_game := false
	for child in game.get_node("YSort").get_children():
		if child is Node2D and child.position == Vector2(t2.x * 32 + 16, t2.y * 32 + 16) and child.scene_file_path.ends_with("MightyOak.tscn"):
			oak_in_game = true
	print("The game builds the saved design: path painted, oak standing: ", game.tilemap.get_cell_source_id(t1) == world.SRC_PATH and oak_in_game)
	game.queue_free()
	await process_frame

	# --- reload from disk, zoom, pan ---
	MapRecipe.override = {}
	var again: Control = load("res://scenes/MapDesigner.tscn").instantiate()
	root.add_child(again)
	current_scene = again
	for i in range(4):
		await process_frame
	print("A fresh designer loads the saved recipe with its note: ", again.recipe.tiles.size() == 9 and again.recipe.notes.size() == 1 and again.nodes_at(t2).size() == 1)
	again.set_zoom_index(again.zoom_index + 2)
	var zoomed: bool = again.camera.zoom == Vector2.ONE * 2.0 and again.zoom_label.text == "200%"
	again.set_zoom_index(0)
	print("Zoom steps through the ladder and clamps (200%, then 25%): ", zoomed and again.camera.zoom == Vector2.ONE * 0.25 and again.zoom_label.text == "25%")
	var before: Vector2 = again.camera.position
	again.camera.position += Vector2(64, 0)
	print("Panning moves the camera: ", again.camera.position == before + Vector2(64, 0))
	again.set_zoom_index(3)
	again.camera.position = again.tile_center(t2)
	for i in range(3):
		await process_frame
	root.get_texture().get_image().save_png("res://verify_map_designer.png")
	print("Saved verify_map_designer.png")
	var preset: String = FileAccess.get_file_as_string("res://export_presets.cfg")
	print("The designer scene and script are excluded from the web export: ", preset.contains("scenes/MapDesigner.tscn") and preset.contains("scripts/map_designer.gd"))
	again.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	MapRecipe.active_path = MapRecipe.DEFAULT_PATH
	MapRecipe.override = {}
	quit()
