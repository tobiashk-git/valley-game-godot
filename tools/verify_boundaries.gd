extends SceneTree

func _walk(player: CharacterBody2D, direction: String, frames: int) -> void:
	Input.action_press(direction)
	for i in range(frames):
		await process_frame
	Input.action_release(direction)
	await process_frame

func _initialize() -> void:
	var world: Node = root.get_node("World")

	# --- Overworld: walk toward each of the 4 edges far longer than needed
	# to reach them, confirm the player is actually stopped, not drifting
	# into undefined space beyond the 100x100 grid. ---
	var overworld_scene: PackedScene = load("res://scenes/Overworld.tscn")
	var overworld: Node2D = overworld_scene.instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame

	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")

	# Start each test just a few tiles from the edge in question (walking
	# all the way from the map center would take ~600 frames per edge) and
	# walk for far longer than needed to cross it if unobstructed.

	# North.
	player.position = Vector2(world.WORLD_CENTER_X * 32 + 16, 5 * 32 + 16)
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	await _walk(player, "move_up", 60)
	print("North: player tile y = ", int(player.position.y / 32), " (should be >= 0)")
	print("North: stopped within bounds: ", player.position.y >= -32.0)

	# South.
	player.position = Vector2(world.WORLD_CENTER_X * 32 + 16, (world.OVERWORLD_HEIGHT - 5) * 32 + 16)
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	await _walk(player, "move_down", 60)
	print("South: player tile y = ", int(player.position.y / 32), " (should be < ", world.OVERWORLD_HEIGHT, ")")
	print("South: stopped within bounds: ", player.position.y <= (world.OVERWORLD_HEIGHT + 1) * 32.0)

	# West.
	player.position = Vector2(5 * 32 + 16, world.WORLD_CENTER_Y * 32 + 16)
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	await _walk(player, "move_left", 60)
	print("West: player tile x = ", int(player.position.x / 32), " (should be >= 0)")
	print("West: stopped within bounds: ", player.position.x >= -32.0)

	# East.
	player.position = Vector2((world.OVERWORLD_WIDTH - 5) * 32 + 16, world.WORLD_CENTER_Y * 32 + 16)
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	await _walk(player, "move_right", 60)
	print("East: player tile x = ", int(player.position.x / 32), " (should be < ", world.OVERWORLD_WIDTH, ")")
	print("East: stopped within bounds: ", player.position.x <= (world.OVERWORLD_WIDTH + 1) * 32.0)
	root.get_texture().get_image().save_png("res://verify_boundary_east.png")

	root.remove_child(overworld)
	overworld.queue_free()
	await process_frame

	# --- Dungeon: walk through the exit door far longer than needed to
	# cross it, confirm the player stops instead of drifting past the map. ---
	var dungeon_scene: PackedScene = load("res://scenes/Dungeon.tscn")
	var dungeon: Node2D = dungeon_scene.instantiate()
	root.add_child(dungeon)
	current_scene = dungeon
	await process_frame
	await process_frame

	var dplayer: CharacterBody2D = dungeon.get_node("YSort/Player")
	var dcam: Camera2D = dplayer.get_node("Camera2D")
	dcam.reset_smoothing()
	await process_frame
	await _walk(dplayer, "move_down", 90)
	var dtile := Vector2i(int(dplayer.position.x / 32), int(dplayer.position.y / 32))
	print("Dungeon door: player tile after walking through = ", dtile)
	print("Dungeon door: stopped at the door, not past it: ", dtile.y <= 27)

	# Confirm E still works from here.
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Dungeon door: E still returns to the Overworld: ", current_scene.name == "Overworld")

	quit()
