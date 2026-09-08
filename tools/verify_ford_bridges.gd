extends SceneTree
# Ford bridge art verification. Run via:
# godot --script res://tools/verify_ford_bridges.gd (NOT --headless).
#
# An open ford draws a painted plank footbridge over its crossing tile (the
# ford tile itself now looks like river, so the bridge is what marks the
# way): upright on the northern and southern fords, turned a quarter for
# the eastern and western ones, under the walkers (before the YSort).
# A closed ford shows nothing.

func _initialize() -> void:
	var world: Node = root.get_node("World")
	var quests: Node = root.get_node("Quests")
	var game_state: Node = root.get_node("GameState")
	await process_frame
	game_state.reset()
	quests.reset()
	root.get_node("Inventory").reset()
	root.get_node("Character").reset()
	MapRecipe.active_path = "res://tools/no_such_recipe.json"
	world.reload_places()
	game_state.village_gates_open = true
	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	for i in range(3):
		await process_frame
	var ysort: Node = overworld.get_node("YSort")
	var tilemap: Node = overworld.get_node("TileMapLayer")
	var bridge := func(zone: int) -> Node: return overworld.get_node_or_null("FordBridge%d" % zone)
	print("With every ford closed there is no bridge: ", bridge.call(world.Zone.FROSTPEAK) == null and bridge.call(world.Zone.VERDANTWOOD) == null and bridge.call(world.Zone.BADLANDS) == null and bridge.call(world.Zone.GLOOMFEN) == null)
	print("The bridge art exists and the ford tile looks like river: ", ResourceLoader.exists("res://assets/ford_bridge.png") and ResourceLoader.exists("res://assets/ford.png"))

	game_state.biome_paths_open.frostpeak = true
	game_state.biome_paths_open.verdantwood = true
	quests.changed.emit()
	await process_frame
	var north: Node = bridge.call(world.Zone.FROSTPEAK)
	var east: Node = bridge.call(world.Zone.VERDANTWOOD)
	var north_tile: Vector2i = world.BIOME_FORDS[world.Zone.FROSTPEAK]
	var east_tile: Vector2i = world.BIOME_FORDS[world.Zone.VERDANTWOOD]
	print("Opening the northern and eastern fords draws a bridge on each crossing tile, none on the closed ones: ", north != null and east != null and north.position == Vector2(north_tile.x * 32 + 16, north_tile.y * 32 + 16) and east.position == Vector2(east_tile.x * 32 + 16, east_tile.y * 32 + 16) and bridge.call(world.Zone.BADLANDS) == null)
	print("The northern bridge stands upright (spanning the east-west river), the eastern one is turned a quarter: ", north != null and east != null and is_equal_approx(north.rotation, 0.0) and is_equal_approx(absf(east.rotation), PI / 2.0))
	print("Bridges draw under the walkers: right after the tile map, before the YSort: ", north != null and north.get_index() > tilemap.get_index() and north.get_index() < ysort.get_index() and north.texture != null and north.texture.get_width() >= 32)
	quests.changed.emit()
	await process_frame
	print("A second repaint reuses the bridges (no duplicates): ", overworld.get_children().filter(func(c): return String(c.name).begins_with("FordBridge")).size() == 2)
	# A look at the northern crossing.
	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	player.position = Vector2(north_tile.x * 32 + 16, (north_tile.y + 2) * 32 + 16)
	for i in range(4):
		await process_frame
	root.get_texture().get_image().save_png("res://verify_ford_bridge.png")
	print("Saved verify_ford_bridge.png")
	quit()
