extends SceneTree
# Verdantwood overland maze (Phase 1 prototype) verification. Run via:
# godot --script res://tools/verify_verdantwood_maze.gd (NOT --headless -
# this takes real screenshots via get_texture()).
#
# Applies the same lessons every other verify script in this project has
# already learned: physics_frame for movement waits, a combat.in_combat
# clear after every teleport in a live-encounter zone, a retry loop around
# the interact press (see verify_frostpeak_interior.gd/
# verify_badlands_interior.gd - a single-attempt press can lose a one-frame
# race against combat-clearing).

func _walk(player: CharacterBody2D, action: String, frames: int) -> void:
	Input.action_press(action)
	for i in range(frames):
		await physics_frame
	Input.action_release(action)
	await physics_frame

func _clear_combat(combat: Node) -> void:
	var attempts := 0
	while combat.in_combat and attempts < 10:
		combat.player_run()
		await physics_frame
		attempts += 1

# True once `pos` is standing in the blocker's own tile. NOT a "crossed past
# its center by some margin" check - the blocker sits on a deliberate 1-tile
# dead-end pocket (see _find_exit_stub() in scripts/world.gd), walled solid
# on the far side, so a margin-past-center criterion is sometimes physically
# unreachable (confirmed directly: a debug trace showed the player
# consistently stopping ~2-6px short of an 8px-past-center margin, held
# there by that far wall, not by anything actually wrong - it just never had
# room to go that far). Within half a tile of the blocker's center is "you
# made it into the tile", which is all this is actually meant to prove.
func _reached(pos: Vector2, target: Vector2) -> bool:
	return pos.distance_to(target) < 16.0

func _action_for_dir(dir: Vector2i) -> String:
	if dir.x > 0:
		return "move_right"
	if dir.x < 0:
		return "move_left"
	if dir.y > 0:
		return "move_down"
	return "move_up"

func _initialize() -> void:
	var world: Node = root.get_node("World")
	var game_state: Node = root.get_node("GameState")
	var combat: Node = root.get_node("Combat")
	var character: Node = root.get_node("Character")

	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame

	var tilemap: TileMapLayer = overworld.get_node("TileMapLayer")
	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")
	var ysort: Node2D = overworld.get_node("YSort")
	var maze: Dictionary = overworld.verdantwood_maze_data

	# --- 1. Region correctness: every tile in the maze box is Verdantwood. ---
	var origin: Vector2i = world.VERDANTWOOD_MAZE_ORIGIN
	var w: int = world.VERDANTWOOD_MAZE_WIDTH
	var h: int = world.VERDANTWOOD_MAZE_HEIGHT
	var all_verdantwood := true
	var wall_count := 0
	var floor_count := 0
	# Not just the first wall cell found (row-major from the top-left) - that
	# tends to sit deep inside a solid wall mass with no open approach, since
	# walls dominate most of the box's area (only rooms/corridors are floor).
	# Require a confirmed floor tile immediately south so "teleport 1.5 tiles
	# south and walk up into it" is a valid, open approach.
	var sample_wall_pos := Vector2i(-9999, -9999)
	for y in range(origin.y, origin.y + h):
		for x in range(origin.x, origin.x + w):
			var pos := Vector2i(x, y)
			if world.biome_at(x, y).zone != world.Zone.VERDANTWOOD:
				all_verdantwood = false
			var source := tilemap.get_cell_source_id(pos)
			if source == world.SRC_FOREST_WALL:
				wall_count += 1
				if sample_wall_pos == Vector2i(-9999, -9999) and tilemap.get_cell_source_id(pos + Vector2i(0, 1)) == world.SRC_VERDANTWOOD:
					sample_wall_pos = pos
			elif source == world.SRC_VERDANTWOOD:
				floor_count += 1
	print("Every maze tile resolves to Zone.VERDANTWOOD: ", all_verdantwood)
	print("Wall cells painted: ", wall_count, " (>0: ", wall_count > 0, ")")
	print("Floor cells left as plain ground: ", floor_count, " (>0: ", floor_count > 0, ")")

	# --- 2. Guardian/blocker sit on floor, not wall. ---
	var guardian_pos: Vector2i = maze.guardian_pos
	var blocker_pos: Vector2i = maze.blocker_pos
	var door_pos: Vector2i = maze.door_pos
	print("Guardian room tile is floor: ", tilemap.get_cell_source_id(guardian_pos) == world.SRC_VERDANTWOOD)
	print("Blocker tile is floor (log sits on top, not a wall cell): ", tilemap.get_cell_source_id(blocker_pos) == world.SRC_VERDANTWOOD)

	# --- 2b. Boundary trees/bushes - the actual "thick lush forest" visual,
	# mostly MightyOak with a little TangledBush mixed in for variety - were
	# instanced at every returned boundary_positions cell, with the correct
	# scene at each. ---
	var boundary_positions: Array = maze.boundary_positions
	var boundary_tiles := {} # Vector2i -> scene_file_path found there
	for child in ysort.get_children():
		if child.scene_file_path == "res://scenes/props/MightyOak.tscn" or child.scene_file_path == "res://scenes/props/TangledBush.tscn":
			boundary_tiles[Vector2i(int(child.position.x / 32), int(child.position.y / 32))] = child.scene_file_path
	var all_present := true
	var bush_count := 0
	for entry in boundary_positions:
		var expected_path: String = "res://scenes/props/%s.tscn" % entry.scene
		if boundary_tiles.get(entry.pos, "") != expected_path:
			all_present = false
			break
		if entry.scene == "TangledBush":
			bush_count += 1
	print("Boundary positions returned: ", boundary_positions.size(), " (>0: ", boundary_positions.size() > 0, ")")
	print("The correct prop (oak or bush) exists at every boundary position: ", all_present)
	print("TangledBush mixed in for variety: ", bush_count, " of ", boundary_positions.size(), " (>0: ", bush_count > 0, ")")

	# --- 3. A wall tile actually blocks movement. ---
	var wall_world: Vector2 = Vector2(sample_wall_pos.x * 32 + 16, sample_wall_pos.y * 32 + 16)
	player.position = wall_world + Vector2(0, 48)
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	await _clear_combat(combat)
	await _walk(player, "move_up", 30)
	print("Wall tile blocks movement (player stopped short of it): ", player.position.y > wall_world.y + 8.0)

	# --- 4. A glade's floor is genuinely walkable (not accidentally solid). ---
	var guardian_world: Vector2 = Vector2(guardian_pos.x * 32 + 16, guardian_pos.y * 32 + 16)
	player.position = guardian_world
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	await _clear_combat(combat)
	var before_move: Vector2 = player.position
	await _walk(player, "move_left", 5)
	await _clear_combat(combat)
	print("Glade floor is walkable (player actually moved): ", player.position.distance_to(before_move) > 2.0)

	# --- 5. Blocker prop exists at blocker_pos and blocks the exit stub. ---
	# approach_pos (returned by carve_verdantwood_maze()) is the room's own
	# boundary cell right next to blocker_pos (the newly-carved stub cell) -
	# whatever side of the room _find_exit_stub() picked, not necessarily
	# related to the entrance's own direction, so the movement direction
	# here is derived from the real generated layout rather than assumed.
	var approach_pos: Vector2i = maze.approach_pos
	var blocker: Node2D = null
	for child in ysort.get_children():
		if child.scene_file_path == "res://scenes/props/FallenLog.tscn" and Vector2i(int(child.position.x / 32), int(child.position.y / 32)) == blocker_pos:
			blocker = child
	print("Blocker (FallenLog) instance found at blocker_pos: ", blocker != null)

	var blocker_world: Vector2 = Vector2(blocker_pos.x * 32 + 16, blocker_pos.y * 32 + 16)
	var approach_world: Vector2 = Vector2(approach_pos.x * 32 + 16, approach_pos.y * 32 + 16)
	var approach_dir: Vector2i = blocker_pos - approach_pos # one of the 4 cardinal unit vectors

	player.position = approach_world - Vector2(approach_dir) * 8.0 # start just outside the corridor tile, clear of the log's own collision
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	await _clear_combat(combat)
	await _walk(player, _action_for_dir(approach_dir), 30)
	print("Blocker blocks the exit before the guardian is defeated: ", not _reached(player.position, blocker_world))

	# --- 6. The glade's own entrance must always be freely reachable - this
	# is the exact bug a live user report caught: an earlier version placed
	# the blocker directly on the room's only entrance, sealing the guardian
	# inside forever unreachable. Independent flood-fill from the door (the
	# blocker cell treated as an extra wall, since the log genuinely
	# occupies it) should reach the guardian's room tile freely, and should
	# NOT reach the exit stub beyond the blocker - that's the part still
	# meant to be gated. ---
	var visited := {}
	var stack: Array = [door_pos]
	while not stack.is_empty():
		var pos: Vector2i = stack.pop_back()
		if visited.has(pos) or pos == blocker_pos:
			continue
		if pos.x < origin.x or pos.x >= origin.x + w or pos.y < origin.y or pos.y >= origin.y + h:
			continue
		if tilemap.get_cell_source_id(pos) == world.SRC_FOREST_WALL:
			continue
		visited[pos] = true
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			stack.append(pos + offset)
	print("Boss room is freely reachable through its own entrance (not sealed by the blocker): ", visited.has(guardian_pos))
	print("Exit stub beyond the blocker is NOT reachable pre-defeat (still genuinely gated): ", not visited.has(blocker_pos))

	# --- 7. Interacting with the guardian starts the correct fight. ---
	var guardian: Node = null
	for child in ysort.get_children():
		if child.scene_file_path == "res://scenes/props/Boss.tscn":
			guardian = child
	print("Guardian (Boss) instance found: ", guardian != null)
	print("Guardian boss_id is correct: ", guardian.boss_id == world.VERDANTWOOD_MAZE_GUARDIAN_ID)

	player.position = guardian.position + Vector2(0, 20)
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	await _clear_combat(combat)

	var interact_attempts := 0
	while not combat.in_combat and interact_attempts < 5:
		Input.action_press("interact")
		await process_frame
		await process_frame
		Input.action_release("interact")
		await process_frame
		interact_attempts += 1
	print("Guardian fight started: ", combat.in_combat)
	print("Fighting the right guardian: ", combat.in_combat and combat.current_enemies[0].name == "Thornback Warden")

	# --- 8. Defeat -> state flips -> blocker freed -> exit now walkable. ---
	character.stats.max_hp = 500
	character.stats.hp = 500
	character.stats.mp = 999
	var guard := 0
	while combat.in_combat and guard < 40:
		combat.cast_spell("fireball")
		await process_frame
		guard += 1
	print("Guardian defeated (", guard, " actions): ", not combat.in_combat)
	print("GameState.boss_defeated set for the guardian: ", game_state.boss_defeated.get(world.VERDANTWOOD_MAZE_GUARDIAN_ID, false))

	await process_frame
	await process_frame
	print("Blocker instance freed after defeat: ", not is_instance_valid(blocker))

	player.position = approach_world - Vector2(approach_dir) * 8.0
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	await _clear_combat(combat)
	# Retry-until-actually-reached, not a single fixed-tick walk - this scene
	# is a live Overworld instance with its own _process() still running
	# random encounters in Verdantwood, same lesson already learned
	# repeatedly for this project's interior verify scripts: an encounter
	# firing mid-walk zeroes player velocity for the rest of a single-attempt
	# walk with nothing to retry it.
	var reach_attempts := 0
	while not _reached(player.position, blocker_world) and reach_attempts < 8:
		await _walk(player, _action_for_dir(approach_dir), 20)
		await _clear_combat(combat)
		reach_attempts += 1
	print("Exit now walkable after the guardian is defeated: ", _reached(player.position, blocker_world))

	# --- 9. Regression: normal Verdantwood scatter never lands inside the
	# reserved maze box. MightyOak/TangledBush are excluded from this check
	# for any tile that's one of our OWN intentional boundary_positions -
	# those are the boundary trees/bushes just verified in check 2b, not a
	# leak. Either prop at any OTHER tile inside the box would still
	# correctly be flagged (that would mean the box reservation failed). ---
	var buffer: int = world.VERDANTWOOD_MAZE_RESERVE_BUFFER
	var box_min := origin - Vector2i(buffer, buffer)
	var box_max := origin + Vector2i(w + buffer, h + buffer)
	var known_boundary_tiles := {} # Vector2i -> scene_file_path
	for entry in boundary_positions:
		known_boundary_tiles[entry.pos] = "res://scenes/props/%s.tscn" % entry.scene
	var scatter_paths := ["res://scenes/props/MightyOak.tscn", "res://scenes/props/FallenLog.tscn", "res://scenes/props/TangledBush.tscn"]
	var leaked_into_maze := false
	for child in ysort.get_children():
		if child.scene_file_path in scatter_paths:
			var tile := Vector2i(int(child.position.x / 32), int(child.position.y / 32))
			if known_boundary_tiles.get(tile, "") == child.scene_file_path:
				continue
			if tile.x >= box_min.x and tile.x < box_max.x and tile.y >= box_min.y and tile.y < box_max.y:
				leaked_into_maze = true
				break
	print("No normal scatter obstacle landed inside the reserved maze box: ", not leaked_into_maze)

	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	root.get_texture().get_image().save_png("res://verify_verdantwood_maze.png")
	print("Saved verify_verdantwood_maze.png")

	quit()
