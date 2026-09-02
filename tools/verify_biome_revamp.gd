extends SceneTree
# Phase 1 biome revamp verification (see the approved plan). Run via:
# godot --script res://tools/verify_biome_revamp.gd (NOT --headless - this
# takes real screenshots via get_texture()).

# Movement happens in _physics_process (fixed 60Hz tick) - waiting on the
# idle-rate process_frame signal instead gave wildly inconsistent px/frame
# in this environment (likely a high monitor refresh rate decoupling render
# frames from physics ticks). physics_frame fires exactly once per physics
# tick, matching player.gd's SPEED constant (160px/s = ~2.67px/tick) reliably.
func _walk(player: CharacterBody2D, action: String, frames: int) -> void:
	Input.action_press(action)
	for i in range(frames):
		await physics_frame
	Input.action_release(action)
	await physics_frame

# scatter_trees_and_rocks() has no fixed seed, so a rigid single-column
# straight-line walk can randomly land behind a tree/rock. Not the thing this
# test is trying to verify - clear a corridor around the given x column so
# the walk tests river/encounter behavior, not scatter placement luck.
func _clear_corridor(overworld: Node2D, player: CharacterBody2D, x: float) -> void:
	var ysort: Node2D = overworld.get_node("YSort")
	for child in ysort.get_children():
		# Wide enough to cover a neighboring-tile prop's collision shape too
		# (gatherables/rocks in particular reach further than their own tile).
		if child != player and child is Node2D and absf(child.position.x - x) < 56.0:
			child.queue_free()
	# queue_free() is deferred - without waiting a couple frames the freed
	# StaticBody2D collision (e.g. DungeonEntrance) can still be active for
	# the first several physics ticks of the walk that follows.
	await process_frame
	await process_frame

func _initialize() -> void:
	var world: Node = root.get_node("World")
	var game_state: Node = root.get_node("GameState")
	var combat: Node = root.get_node("Combat")

	# --- 1. biome_at() reports the right zone in each direction. ---
	print("North = FROSTPEAK: ", world.biome_at(world.WORLD_CENTER_X, world.WORLD_CENTER_Y - 40).zone == world.Zone.FROSTPEAK)
	print("South = BADLANDS: ", world.biome_at(world.WORLD_CENTER_X, world.WORLD_CENTER_Y + 40).zone == world.Zone.BADLANDS)
	print("East = VERDANTWOOD: ", world.biome_at(world.WORLD_CENTER_X + 40, world.WORLD_CENTER_Y).zone == world.Zone.VERDANTWOOD)
	print("West = GLOOMFEN: ", world.biome_at(world.WORLD_CENTER_X - 40, world.WORLD_CENTER_Y).zone == world.Zone.GLOOMFEN)
	print("Center = VALLEY: ", world.biome_at(world.WORLD_CENTER_X, world.WORLD_CENTER_Y).zone == world.Zone.VALLEY)

	# The village's own gates (a separate, earlier tutorial mechanic - see
	# meet_villagers) start closed and would otherwise strand the player
	# before ever reaching the river ring this test is actually about.
	game_state.village_gates_open = true

	var overworld_scene: PackedScene = load("res://scenes/Overworld.tscn")
	var overworld: Node2D = overworld_scene.instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame

	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")

	# --- World boundary sits at the new 200x200 edge, not the old 100x100 one. ---
	player.position = Vector2(world.OVERWORLD_WIDTH * 32 - 100, world.WORLD_CENTER_Y * 32)
	cam.reset_smoothing()
	await _walk(player, "move_right", 60)
	print("Blocked by the world boundary near the new (200x200) edge, not the old one: ", player.position.x > (world.OVERWORLD_WIDTH - 5) * 32.0 and player.position.x < world.OVERWORLD_WIDTH * 32.0)
	# That walk crosses real Verdantwood territory now that overworld
	# encounters are wired in, so it can genuinely trigger combat - Combat is
	# an autoload, so leaving it in_combat would stall every walk after this
	# one (player.gd zeroes velocity while in_combat), regardless of scene.
	if combat.in_combat:
		combat.player_run()
		await physics_frame

	# --- Walk straight north from the village through Golden Plains - zero
	# encounters the whole way (regression on the existing safe-valley
	# behavior), then blocked by the river before reaching Frostpeak.
	# Start 3 tiles north of world center, already past the altar - it's a
	# single solid tile dead center on this same column (World.ALTAR_POS),
	# and walking straight north into it from the south would just pin the
	# player against it. Also clear the corridor of any randomly-scattered
	# tree/rock so the walk tests river/encounter logic, not scatter luck,
	# and skip past the DUNGEON_ENTRANCE prop (also on this column, still
	# inside the valley radius per the plan's entrance-repositioning
	# deviation) the same way. ---
	var center_x: float = world.WORLD_CENTER_X * 32 + 16
	await _clear_corridor(overworld, player, center_x)
	player.position = Vector2(center_x, (world.WORLD_CENTER_Y - 3) * 32 + 16)
	cam.reset_smoothing()
	var encounter_fired := false
	Input.action_press("move_up")
	for i in range(400): # 704px / ~2.67px-per-physics-tick ~= 264 ticks minimum, plus margin
		await physics_frame
		if combat.in_combat:
			encounter_fired = true
			break
	Input.action_release("move_up")
	await physics_frame
	print("Zero encounters walking north through Golden Plains: ", not encounter_fired)
	var river_y: float = float(world.WORLD_CENTER_Y - world.VALLEY_RADIUS) * 32.0
	print("River blocks further movement before reaching Frostpeak: ", player.position.y > river_y and player.position.y < river_y + 64.0)
	root.get_texture().get_image().save_png("res://verify_biome_river.png")

	# Fully remove this scene before loading the next - change_scene_to_file()
	# does this automatically in the real game, but manually add_child'ing a
	# second top-level Overworld instance alongside this one (as below) would
	# otherwise leave this player alive, still processing, and colliding with
	# the next one - both instances occupy the same coordinate space (same
	# established gotcha documented in verify_village_gates.gd).
	root.remove_child(overworld)
	overworld.queue_free()
	await process_frame

	# --- Open the Frostpeak ford, reload, confirm it's now walkable. Start
	# close (5 tiles south of the ring) so the crossing check needs fewer
	# frames, and clear the corridor again (fresh scatter roll on reload). ---
	game_state.biome_paths_open.frostpeak = true
	var overworld2_scene: PackedScene = load("res://scenes/Overworld.tscn")
	var overworld2: Node2D = overworld2_scene.instantiate()
	root.add_child(overworld2)
	current_scene = overworld2
	await process_frame
	await process_frame
	var player2: CharacterBody2D = overworld2.get_node("YSort/Player")
	var cam2: Camera2D = player2.get_node("Camera2D")

	var start2_x: float = world.WORLD_CENTER_X * 32 + 16
	await _clear_corridor(overworld2, player2, start2_x)
	player2.position = Vector2(start2_x, (world.WORLD_CENTER_Y - world.VALLEY_RADIUS + 5) * 32 + 16)
	cam2.reset_smoothing()
	await _walk(player2, "move_up", 120) # 5 tiles to the ring + a few more past it
	print("Frostpeak ford is walkable once opened (crossed north of the ring): ", player2.position.y < river_y)
	root.get_texture().get_image().save_png("res://verify_biome_ford_crossed.png")

	# --- Encounters now fire in Frostpeak, pulling only the 3 new monsters.
	# Continue walking further north (well into Frostpeak) - random encounters
	# are inherently probabilistic (12% per eligible tile-step, established
	# recurring flakiness elsewhere in this project's tests); a long walk
	# maximizes the odds within one run. ---
	await _clear_corridor(overworld2, player2, player2.position.x)
	var got_frostpeak_encounter := false
	var wrong_enemy_seen := false
	Input.action_press("move_up")
	for i in range(600):
		await physics_frame
		if combat.in_combat:
			got_frostpeak_encounter = true
			break
	Input.action_release("move_up")
	await physics_frame
	print("Encounter fired once inside Frostpeak Ridge: ", got_frostpeak_encounter)
	if got_frostpeak_encounter:
		var names := {"Ice Wraith": true, "Frost Wolf": true, "Stone Sentinel": true}
		for enemy in combat.current_enemies:
			if enemy != null and not names.has(enemy.name):
				wrong_enemy_seen = true
		print("Every enemy in the fight is one of the 3 Frostpeak monsters: ", not wrong_enemy_seen)
		root.get_texture().get_image().save_png("res://verify_biome_frostpeak_encounter.png")
		combat.player_run()
		await process_frame

	quit()
