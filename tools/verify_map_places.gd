extends SceneTree
# Movable places verification (map tool phase 3a). Run via:
# godot --script res://tools/verify_map_places.gd (NOT --headless).
#
# The recipe's "places" section moves dungeon doors, interior entrances and
# NPC camps: the overworld builds the door prop and its portal at the new
# tile with nothing at the old one, the camp NPC stands at its new tile,
# the interior's way back lands beside the moved door, the World Map's
# fast travel targets it, and the scatter keeps clear of it. The designer's
# Move tool picks a place up, refuses solid ground, drops it, and Erase or
# Undo put it back.

const TEST_PATH := "res://tools/verify_places_recipe.json"

func _nodes_at(scene: Node2D, tile: Vector2i, suffix: String) -> Array:
	var out: Array = []
	var centre := Vector2(tile.x * 32 + 16, tile.y * 32 + 16)
	for child in scene.get_node("YSort").get_children():
		if child is Node2D and not child.is_queued_for_deletion() and child.position.distance_to(centre) < 1.0 and child.scene_file_path.ends_with(suffix):
			out.append(child)
	return out

func _portal_at(scene: Node2D, tile: Vector2i, target: String) -> bool:
	var centre := Vector2(tile.x * 32 + 16, tile.y * 32 + 16)
	for child in scene.get_children():
		if child is Area2D and child.get("target_scene") == target and child.position.distance_to(centre) < 1.0:
			return true
	return false

func _npc_at(scene: Node2D, tile: Vector2i, npc_name: String) -> bool:
	var centre := Vector2(tile.x * 32 + 16, tile.y * 32 + 16)
	for child in scene.get_node("YSort").get_children():
		if child.get("npc_name") == npc_name and child.position.distance_to(centre) < 1.0:
			return true
	return false

func _initialize() -> void:
	var world: Node = root.get_node("World")
	var world_map: Node = root.get_node("WorldMap")
	await process_frame
	root.get_node("GameState").reset()
	root.get_node("Quests").reset()
	var cx: int = world.WORLD_CENTER_X
	var cy: int = world.WORLD_CENTER_Y
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

	# --- defaults ---
	MapRecipe.active_path = "res://tools/no_such_recipe.json"
	world.reload_places()
	print("Fourteen movable places, each defaulting to its constant (dungeon at ", world.place("dungeon"), "): ", world.PLACE_DEFAULTS.size() == 14 and world.place("dungeon") == world.PLACE_DEFAULTS.dungeon and world.place("ranger_camp") == world.PLACE_DEFAULTS.ranger_camp and world.place_at(world.PLACE_DEFAULTS.castle) == "castle" and world.place_at(Vector2i(3, 3)) == "")

	# --- a recipe moves the dungeon door and the Ranger's camp ---
	var new_door := Vector2i(cx - 15, cy + 8)
	var new_camp := Vector2i(cx - 6, cy - 10)
	MapRecipe.save_to(TEST_PATH, {"version": 1, "places": {"dungeon": [new_door.x, new_door.y], "ranger_camp": {"x": new_camp.x, "y": new_camp.y}, "no_such_place": [1, 1], "castle": [999, 5]}})
	MapRecipe.active_path = TEST_PATH
	world.reload_places()
	print("place() follows the recipe (array or x/y form), unknown ids and off-map tiles are ignored: ", world.place("dungeon") == new_door and world.place("ranger_camp") == new_camp and world.place("castle") == world.PLACE_DEFAULTS.castle)
	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	for i in range(3):
		await process_frame
	print("The dungeon door prop and its portal stand at the new tile, nothing at the old one: ", _nodes_at(overworld, new_door, "DungeonEntrance.tscn").size() == 1 and _portal_at(overworld, new_door, "res://scenes/Dungeon.tscn") and _nodes_at(overworld, world.PLACE_DEFAULTS.dungeon, "DungeonEntrance.tscn").is_empty() and not _portal_at(overworld, world.PLACE_DEFAULTS.dungeon, "res://scenes/Dungeon.tscn"))
	print("The Frostpeak Ranger camps at the new tile, not the old: ", _npc_at(overworld, new_camp, "Frostpeak Ranger") and not _npc_at(overworld, world.PLACE_DEFAULTS.ranger_camp, "Frostpeak Ranger"))
	var clear := true
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var t: Vector2i = new_door + Vector2i(dx, dy)
			for child in overworld.get_node("YSort").get_children():
				if child is Node2D and child.position == Vector2(t.x * 32 + 16, t.y * 32 + 16) and not child.scene_file_path.ends_with("DungeonEntrance.tscn"):
					clear = false
	print("The scatter keeps a clear ring around the moved door: ", clear)
	print("World Map: fast travel to the dungeon lands beside the moved door: ", world_map.poi_tile("dungeon") == new_door + Vector2i(0, 1) and world_map.poi_target("dungeon") == Vector2(new_door.x * 32 + 16, (new_door.y + 1) * 32 + 16))
	overworld.queue_free()
	await process_frame
	await process_frame
	var dungeon: Node2D = load("res://scenes/Dungeon.tscn").instantiate()
	root.add_child(dungeon)
	current_scene = dungeon
	for i in range(3):
		await process_frame
	var way_back := false
	for child in dungeon.get_children():
		if child is Area2D and child.get("target_scene") == "res://scenes/Overworld.tscn" and child.target_spawn == Vector2(new_door.x * 32 + 16, (new_door.y + 1) * 32 + 16):
			way_back = true
	print("Leaving the dungeon lands beside the moved door: ", way_back)
	dungeon.queue_free()
	await process_frame
	await process_frame

	# --- the designer's Move tool ---
	var designer: Control = load("res://scenes/MapDesigner.tscn").instantiate()
	root.add_child(designer)
	current_scene = designer
	for i in range(4):
		await process_frame
	designer._set_tool("move")
	print("Designer: the recipe's moved places load (dungeon at the new tile) and the readout names the place: ", designer.recipe.places.has("dungeon") and world.place("dungeon") == new_door and designer.recipe_at(new_door).has("place dungeon (moved)"))
	print("Move: clicking empty ground picks nothing up: ", not designer.apply_at(Vector2i(cx - 8, cy + 8)) and designer.carrying == "")
	designer.apply_at(new_door)
	print("Move: clicking the dungeon door picks it up: ", designer.carrying == "dungeon")
	var river := Vector2i(cx, cy - world.VALLEY_RADIUS)
	print("Move: a river tile refuses the drop (still carrying): ", not designer.apply_at(river) and designer.carrying == "dungeon")
	print("Move: the castle's tile refuses the drop: ", not designer.apply_at(world.place("castle")) and designer.carrying == "dungeon")
	var drop := Vector2i(cx - 15, cy + 12)
	var dropped: bool = designer.apply_at(drop)
	await process_frame
	await process_frame
	print("Move: open ground takes it - recipe updated, world regenerated with the door there: ", dropped and designer.carrying == "" and designer.recipe.places.dungeon == [drop.x, drop.y] and world.place("dungeon") == drop and _nodes_at(designer.overworld, drop, "DungeonEntrance.tscn").size() == 1 and _nodes_at(designer.overworld, new_door, "DungeonEntrance.tscn").is_empty())
	designer.undo()
	await process_frame
	await process_frame
	print("Undo puts it back: ", world.place("dungeon") == new_door and _nodes_at(designer.overworld, new_door, "DungeonEntrance.tscn").size() == 1)
	designer._set_tool("erase")
	designer.apply_at(new_door)
	await process_frame
	await process_frame
	print("Erase on a moved place returns it to its default spot: ", not designer.recipe.places.has("dungeon") and world.place("dungeon") == world.PLACE_DEFAULTS.dungeon and _nodes_at(designer.overworld, world.PLACE_DEFAULTS.dungeon, "DungeonEntrance.tscn").size() == 1)
	designer._set_tool("move")
	designer.apply_at(world.place("ranger_camp"))
	designer.apply_at(world.PLACE_DEFAULTS.dungeon + Vector2i(0, 2))
	await process_frame
	await process_frame
	print("A camp moves on its own (the Ranger now waits below the dungeon door): ", designer.recipe.places.ranger_camp == [world.PLACE_DEFAULTS.dungeon.x, world.PLACE_DEFAULTS.dungeon.y + 2] and _npc_at(designer.overworld, world.PLACE_DEFAULTS.dungeon + Vector2i(0, 2), "Frostpeak Ranger"))
	print("Save carries the places section: ", designer.save() and MapRecipe.places(MapRecipe.load_from(TEST_PATH)).has("ranger_camp"))
	designer.camera.position = designer.tile_center(world.PLACE_DEFAULTS.dungeon)
	for i in range(3):
		await process_frame
	root.get_texture().get_image().save_png("res://verify_map_places.png")
	print("Saved verify_map_places.png")
	designer.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	MapRecipe.active_path = MapRecipe.DEFAULT_PATH
	MapRecipe.override = {}
	world.reload_places()
	quit()
