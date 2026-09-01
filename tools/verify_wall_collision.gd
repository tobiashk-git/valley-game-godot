extends SceneTree
# Find the nearest wall in any direction from the player's spawn tile, walk
# straight at it, and confirm the player actually stops instead of passing
# through.

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/Dungeon.tscn")
	var instance: Node2D = scene.instantiate()
	root.add_child(instance)
	await process_frame

	var terrain: TileMapLayer = instance.get_node("TerrainLayer")
	var player: CharacterBody2D = instance.get_node("YSort/Player")
	var player_tile := Vector2i(int(player.position.x / 32), int(player.position.y / 32))

	var directions := {
		"move_down": Vector2i(0, 1),
		"move_up": Vector2i(0, -1),
		"move_right": Vector2i(1, 0),
		"move_left": Vector2i(-1, 0),
	}
	var chosen_action := ""
	var target_wall := Vector2i(-9999, -9999)
	for action in directions:
		var d: Vector2i = directions[action]
		for r in range(1, 10):
			var candidate: Vector2i = player_tile + d * r
			if terrain.get_cell_source_id(candidate) == 0:
				chosen_action = action
				target_wall = candidate
				break
		if chosen_action != "":
			break

	print("Player tile: ", player_tile, " chosen direction: ", chosen_action, " target wall: ", target_wall)
	if chosen_action == "":
		print("No nearby wall found - inconclusive test")
		quit()
		return

	Input.action_press(chosen_action)
	for i in range(300):
		await physics_frame
	Input.action_release(chosen_action)

	var final_tile := Vector2i(int(player.position.x / 32), int(player.position.y / 32))
	print("Final position: ", player.position, " tile: ", final_tile)
	print("Wall tile itself still solid (never entered): ", terrain.get_cell_source_id(final_tile) != 0)
	quit()
