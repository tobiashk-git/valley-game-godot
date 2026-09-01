extends SceneTree
# Reproduces the reported bug: dying in combat *inside the Dungeon* (or
# Castle/FinalBoss) respawned the player outside the house instead of
# inside it. Root cause: overworld.gd's dungeon-entrance portal sets
# GameState's pending spawn override to Vector2.ZERO (a deliberate
# placeholder - maze_interior.gd always uses its own freshly-generated
# spawn_tile instead, see its comment), but never consumed/cleared that
# placeholder - so it sat there until whatever scene loaded *next* wrongly
# picked it up. On combat defeat, House.tscn does exactly that, landing the
# player at world position (0,0): the house's top-left wall corner, well
# outside its playable room. Run via:
# godot --script res://tools/verify_defeat_respawn.gd (NOT --headless - this
# takes a real screenshot via get_texture()).

func _initialize() -> void:
	var overworld_scene: PackedScene = load("res://scenes/Overworld.tscn")
	var overworld: Node2D = overworld_scene.instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame

	var game_state: Node = root.get_node("GameState")

	# --- Enter the Dungeon exactly the way its real entrance portal does
	# (see overworld.gd's _add_entrance() call for it, target_spawn =
	# Vector2.ZERO) - a placeholder maze_interior.gd is expected to ignore. ---
	game_state.set_next_spawn(Vector2.ZERO)
	change_scene_to_file("res://scenes/Dungeon.tscn")
	await process_frame
	await process_frame
	await process_frame
	print("Entered the Dungeon: ", current_scene.scene_file_path == "res://scenes/Dungeon.tscn")
	print("Placeholder spawn override was consumed/cleared: ", game_state.next_spawn_position == game_state.NO_OVERRIDE)

	var player: CharacterBody2D = current_scene.get_node("YSort/Player")
	var dungeon_spawn_pos: Vector2 = player.position
	print("Player spawned at the maze's own spawn tile, not (0,0): ", dungeon_spawn_pos != Vector2.ZERO)

	# --- Die in combat while inside the Dungeon. ---
	var combat: Node = root.get_node("Combat")
	var character: Node = root.get_node("Character")
	combat.start_combat("dungeon_rat")
	await process_frame
	character.stats.hp = 0
	combat._defeat()
	await process_frame
	await process_frame
	await process_frame

	print("Landed in the House: ", current_scene.scene_file_path == "res://scenes/House.tscn")
	var house_player: CharacterBody2D = current_scene.get_node("YSort/Player")
	print("House player position: ", house_player.position)

	# House interior is an 11x9 room (352x288 px) - a position outside that
	# range (like the (0,0) top-left corner the stale override used to
	# apply) means the player landed outside the visible house.
	var inside_room: bool = house_player.position.x > 0 and house_player.position.x < 352 and house_player.position.y > 0 and house_player.position.y < 288
	print("Player landed inside the house's room bounds (bug fixed): ", inside_room)

	root.get_texture().get_image().save_png("res://verify_defeat_respawn.png")
	quit()
