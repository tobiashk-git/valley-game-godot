extends SceneTree
# Map design recipe verification (map tool phase 1). Run via:
# godot --script res://tools/verify_map_recipe.gd (NOT --headless).
#
# A recipe (maps/overworld.json format) stamps over the generated overworld:
# painted tiles by name or id, props by scene name, wild monsters by species
# (fighting in their own biome's pool), removed tiles drop what the generator
# put there, and the generator keeps off every claimed tile. The World Map
# chart shows painted tiles. A missing or broken recipe is ignored quietly.

const TEST_PATH := "res://tools/verify_recipe.json"

func _open() -> Node2D:
	var scene: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	return scene

func _close(scene: Node2D) -> void:
	scene.queue_free()
	await process_frame
	await process_frame

# Every YSort child standing on a tile.
func _at(scene: Node2D, tile: Vector2i) -> Array:
	var out: Array = []
	var centre := Vector2(tile.x * 32 + 16, tile.y * 32 + 16)
	for child in scene.get_node("YSort").get_children():
		if child is Node2D and child.position.distance_to(centre) < 1.0:
			out.append(child)
	return out

func _scene_of(node: Node) -> String:
	return node.scene_file_path.get_file().get_basename() if node.scene_file_path != "" else ""

func _initialize() -> void:
	var game_state: Node = root.get_node("GameState")
	var world: Node = root.get_node("World")
	var world_map: Node = root.get_node("WorldMap")
	await process_frame
	game_state.reset()
	root.get_node("Quests").reset()
	var cx: int = world.WORLD_CENTER_X
	var cy: int = world.WORLD_CENTER_Y

	# --- no recipe at all ---
	MapRecipe.active_path = "res://tools/no_such_recipe.json"
	var plain: Node2D = _open()
	for i in range(3):
		await process_frame
	var generated_monster: Vector2i = plain.wild_monster_data[0].pos
	var monsters_before: int = plain.wild_monster_data.size()
	print("Without a recipe the overworld builds as before (", monsters_before, " wild monsters, one at ", generated_monster, "): ", monsters_before > 10 and _at(plain, generated_monster).size() == 1)
	await _close(plain)

	# --- a broken file is ignored ---
	var bad := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	bad.store_string("{ not json")
	bad.close()
	MapRecipe.active_path = TEST_PATH
	print("A broken recipe file loads as empty: ", MapRecipe.load_active().is_empty() and MapRecipe.parse('{"version": 7}', "v7").is_empty())

	# --- a real recipe ---
	var path_a := Vector2i(cx - 8, cy + 8)
	var path_b := Vector2i(cx - 8, cy + 9)
	var water := Vector2i(cx - 8, cy + 10)
	var oak := Vector2i(cx - 10, cy + 8)
	var tree := Vector2i(cx - 10, cy + 10)
	var wolf := Vector2i(cx - 12, cy + 8)
	var rat := Vector2i(cx - 12, cy + 10)
	var recipe := {
		"version": 1,
		"tiles": {MapRecipe.key(path_a): "path", MapRecipe.key(path_b): world.SRC_PATH, MapRecipe.key(water): "gloomfen_water", "nonsense": "path", MapRecipe.key(Vector2i(cx - 8, cy + 11)): "no_such_tile"},
		"props": [{"scene": "MightyOak", "x": oak.x, "y": oak.y}, {"scene": "Tree", "x": tree.x, "y": tree.y}, {"scene": "NoSuchProp", "x": tree.x + 1, "y": tree.y}],
		"monsters": [{"enemy_id": "frost_wolf", "x": wolf.x, "y": wolf.y}, {"enemy_id": "dungeon_rat", "x": rat.x, "y": rat.y}, {"enemy_id": "no_such_beast", "x": rat.x + 1, "y": rat.y}],
		"removed": [MapRecipe.key(generated_monster)],
		"notes": [{"x": oak.x, "y": oak.y, "text": "A designed oak."}],
	}
	print("Recipe saved through MapRecipe.save_to and read back: ", MapRecipe.save_to(TEST_PATH, recipe) and MapRecipe.load_active().get("version", 0) == 1 and MapRecipe.tiles(MapRecipe.load_active()).size() == 3)
	var designed: Node2D = _open()
	for i in range(3):
		await process_frame
	var tilemap: TileMapLayer = designed.tilemap
	print("Painted tiles: path by name, path by id, gloomfen water by name; bad entries skipped: ", tilemap.get_cell_source_id(path_a) == world.SRC_PATH and tilemap.get_cell_source_id(path_b) == world.SRC_PATH and tilemap.get_cell_source_id(water) == world.SRC_GLOOMFEN_WATER and tilemap.get_cell_source_id(Vector2i(cx - 8, cy + 11)) == world.SRC_GRASS)
	var at_oak: Array = _at(designed, oak)
	var at_tree: Array = _at(designed, tree)
	print("Props by scene name stand on their tiles (MightyOak, Tree), the unknown one skipped: ", at_oak.size() == 1 and _scene_of(at_oak[0]) == "MightyOak" and at_tree.size() == 1 and _scene_of(at_tree[0]) == "Tree" and _at(designed, tree + Vector2i(1, 0)).is_empty())
	var at_wolf: Array = _at(designed, wolf)
	var at_rat: Array = _at(designed, rat)
	var wolf_ok: bool = at_wolf.size() == 1 and _scene_of(at_wolf[0]) == "WildMonster" and at_wolf[0].enemy_id == "frost_wolf" and at_wolf[0].zone == world.Zone.FROSTPEAK and at_wolf[0].placement_key == "recipe:%d,%d" % [wolf.x, wolf.y]
	var rat_ok: bool = at_rat.size() == 1 and at_rat[0].enemy_id == "dungeon_rat" and at_rat[0].zone == -1
	print("Wild monsters by species in the valley, each in its own pool (frost wolf -> Frostpeak, dungeon rat -> dungeon), the unknown one skipped: ", wolf_ok and rat_ok and _at(designed, rat + Vector2i(1, 0)).is_empty())
	var listed: bool = designed.wild_monster_data.any(func(e): return e.placement_key == "recipe:%d,%d" % [wolf.x, wolf.y])
	print("Recipe monsters join wild_monster_data; the removed generated one is gone from the map and the list: ", listed and _at(designed, generated_monster).is_empty() and not designed.wild_monster_data.any(func(e): return e.pos == generated_monster) and designed.wild_monster_data.size() == monsters_before - 1 + 2)
	# Fight the designed wolf to prove the pool holds together.
	var combat: Node = root.get_node("Combat")
	combat.start_wild_encounter("frost_wolf", at_wolf[0].zone, at_wolf[0].placement_key)
	var names: Array = combat.current_enemies.map(func(e): return e.name)
	print("A fight at the designed wolf starts with a Frost Wolf in a Frostpeak group (", names, "): ", combat.in_combat and names.has("Frost Wolf") and names.all(func(n): return n in ["Frost Wolf", "Ice Wraith", "Stone Sentinel"]))
	combat.player_run()
	await process_frame
	await _close(designed)

	# --- the chart shows painted tiles ---
	var region: Rect2i = root.get_node("CharacterSheet").map_view.MAP_REGION
	var with_recipe: Image = world_map.render_map(region).get_image()
	MapRecipe.active_path = "res://tools/no_such_recipe.json"
	var without: Image = world_map.render_map(region).get_image()
	var px: Vector2i = water - region.position
	print("The World Map chart paints the recipe's water tile differently from the plain grass underneath: ", with_recipe.get_pixel(px.x, px.y) != without.get_pixel(px.x, px.y))

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	MapRecipe.active_path = MapRecipe.DEFAULT_PATH
	print("The shipped recipe is a valid version-1 file with no tiles yet: ", MapRecipe.load_active().get("version", 0) == 1 and MapRecipe.tiles(MapRecipe.load_active()).is_empty())
	quit()
