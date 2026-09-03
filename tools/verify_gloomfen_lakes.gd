extends SceneTree
# Verifies World.scatter_biome_lakes() - a lake tile actually gets painted,
# every one lands in Zone.GLOOMFEN, none sit within OBSTACLE_RIVER_CLEARANCE
# of the ford, and collision actually blocks a walk-in. Run via:
# godot --script res://tools/verify_gloomfen_lakes.gd (NOT --headless - this
# takes a real screenshot via get_texture()).

func _walk(player: CharacterBody2D, action: String, frames: int) -> void:
	Input.action_press(action)
	for i in range(frames):
		await physics_frame
	Input.action_release(action)
	await physics_frame

func _initialize() -> void:
	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	var world: Node = root.get_node("World")
	var tilemap: TileMapLayer = overworld.get_node("TileMapLayer")
	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")
	var combat: Node = root.get_node("Combat")
	await process_frame

	var lake_tiles: Array = []
	for y in range(world.OVERWORLD_HEIGHT):
		for x in range(world.OVERWORLD_WIDTH):
			if tilemap.get_cell_source_id(Vector2i(x, y)) == world.SRC_GLOOMFEN_WATER:
				lake_tiles.append(Vector2i(x, y))
	print("Lake tiles painted: ", lake_tiles.size())
	print("At least one lake tile present: ", lake_tiles.size() > 0)

	if lake_tiles.is_empty():
		quit()
		return

	var all_in_zone := true
	var all_clear_of_river := true
	for pos in lake_tiles:
		if world.biome_at(pos.x, pos.y).zone != world.Zone.GLOOMFEN:
			all_in_zone = false
		if not world._far_enough_from_river(pos, world.Zone.GLOOMFEN):
			all_clear_of_river = false
	print("Every lake tile is in Zone.GLOOMFEN: ", all_in_zone)
	print("Every lake tile clear of the river: ", all_clear_of_river)

	# --- Real collision check: walk straight into a known lake tile. ---
	var target: Vector2i = lake_tiles[0]
	player.position = Vector2(target.x, target.y) * 32.0 + Vector2(16, 64) # a tile and a half below it
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	if combat.in_combat:
		combat.player_run()
		await physics_frame
	await _walk(player, "move_up", 60)
	var target_center := Vector2(target.x, target.y) * 32.0 + Vector2(16, 16)
	print("Blocks movement (player stopped short of it): ", player.position.y > target_center.y + 8.0)

	# --- Real screenshot near a lake for visual confirmation. ---
	player.position = target_center + Vector2(0, 80)
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	root.get_texture().get_image().save_png("res://verify_gloomfen_lakes.png")
	print("Saved verify_gloomfen_lakes.png")

	quit()
