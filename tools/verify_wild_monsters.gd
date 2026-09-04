extends SceneTree
# Static farmable wild monster verification. Run via:
# godot --script res://tools/verify_wild_monsters.gd (NOT --headless - this
# reads real Sprite2D state and takes a real screenshot via get_texture()).
#
# Applies the same lessons every other verify script in this project has
# already learned: physics_frame for movement waits, a combat.in_combat
# clear after every teleport, a retry loop around the interact press (a
# single-attempt press can lose a one-frame race against combat-clearing).

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

func _initialize() -> void:
	var world: Node = root.get_node("World")
	var game_state: Node = root.get_node("GameState")
	var combat: Node = root.get_node("Combat")
	var character: Node = root.get_node("Character")
	var inventory: Node = root.get_node("Inventory")

	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame

	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")
	var ysort: Node2D = overworld.get_node("YSort")
	var placements: Array = overworld.wild_monster_data

	# --- 1. Placements exist, one per outer biome at least, right zone each,
	# none in Golden Plains. ---
	print("Total placements: ", placements.size(), " (>0: ", placements.size() > 0, ")")
	var zones_seen := {}
	var all_zones_correct := true
	var none_in_valley := true
	for entry in placements:
		zones_seen[entry.zone] = true
		if world.biome_at(entry.pos.x, entry.pos.y).zone != entry.zone:
			all_zones_correct = false
		if entry.zone == world.Zone.VALLEY:
			none_in_valley = false
	print("Every placement's tile resolves to its own declared zone: ", all_zones_correct)
	print("Zero placements in Golden Plains/Zone.VALLEY: ", none_in_valley)
	print("All 4 outer biomes represented: ", zones_seen.has(world.Zone.FROSTPEAK) and zones_seen.has(world.Zone.VERDANTWOOD) and zones_seen.has(world.Zone.BADLANDS) and zones_seen.has(world.Zone.GLOOMFEN))

	# --- 2. None land inside the Verdantwood maze's reserved box. ---
	var maze_origin: Vector2i = world.VERDANTWOOD_MAZE_ORIGIN
	var maze_w: int = world.VERDANTWOOD_MAZE_WIDTH
	var maze_h: int = world.VERDANTWOOD_MAZE_HEIGHT
	var maze_buffer: int = world.VERDANTWOOD_MAZE_RESERVE_BUFFER
	var box_min: Vector2i = maze_origin - Vector2i(maze_buffer, maze_buffer)
	var box_max: Vector2i = maze_origin + Vector2i(maze_w + maze_buffer, maze_h + maze_buffer)
	var none_in_maze_box := true
	for entry in placements:
		if entry.pos.x >= box_min.x and entry.pos.x < box_max.x and entry.pos.y >= box_min.y and entry.pos.y < box_max.y:
			none_in_maze_box = false
			break
	print("No placement lands inside the Verdantwood maze's reserved box: ", none_in_maze_box)

	# --- 3. Deterministic placement across a real scene reload - the actual
	# guarantee this exists for (every house visit/dungeon return reloads
	# Overworld.tscn in real play). A second full instantiation should
	# reproduce the exact same wild-monster positions+species, even though
	# scatter_biome_obstacles() itself is NOT seeded and will place different
	# trees/rocks each time. ---
	var overworld2: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld2)
	await process_frame
	await process_frame
	var first_run_positions := {}
	for entry in placements:
		first_run_positions[entry.pos] = entry.enemy_id
	var deterministic: bool = overworld2.wild_monster_data.size() == placements.size()
	if deterministic:
		for entry in overworld2.wild_monster_data:
			if first_run_positions.get(entry.pos, "") != entry.enemy_id:
				deterministic = false
				break
	print("Placement is deterministic across a scene reload (same positions+species both times): ", deterministic)
	root.remove_child(overworld2)
	overworld2.queue_free()
	await process_frame
	await process_frame

	# --- 4. Correct sprite + tint renders for a sample placement, and it
	# blocks movement (StaticBody2D collider). ---
	var sample: Dictionary = placements[0]
	var monster: Node = null
	for child in ysort.get_children():
		if child.scene_file_path == "res://scenes/props/WildMonster.tscn" and child.placement_key == sample.placement_key:
			monster = child
	print("Sample WildMonster node found: ", monster != null)
	var def: Dictionary = Enemies.ENEMIES[sample.enemy_id]
	print("Sprite texture matches its species: ", monster.sprite.texture.resource_path == def.sprite)
	print("Alive tint matches its species: ", monster.sprite.modulate.is_equal_approx(def.get("tint", Color(1, 1, 1, 1))))
	print("Sprite drawn at half the boss scale (0.8): ", monster.sprite.scale.is_equal_approx(Vector2(0.8, 0.8)))
	var sample_visual_size: Vector2 = monster.sprite.texture.get_size() * monster.sprite.scale
	var sample_visual_center: Vector2 = monster.sprite.offset * monster.sprite.scale
	var sample_feet_y: float = sample_visual_center.y + sample_visual_size.y / 2.0
	print("Sprite's feet sit on its tile (bottom edge ", sample_feet_y, "px below the body): ", absf(sample_feet_y - monster.FEET_DROP) < 0.5)

	var sample_world: Vector2 = Vector2(sample.pos.x * 32 + 16, sample.pos.y * 32 + 16)
	player.position = sample_world + Vector2(0, 48)
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	await _clear_combat(combat)
	await _walk(player, "move_up", 30)
	print("Wild monster blocks movement (player stopped short of it): ", player.position.y > sample_world.y + 8.0)

	# --- 5. Interacting starts a fight that includes the guaranteed species.
	# The InteractArea is sized around the visible sprite at runtime (see
	# wild_monster.gd) and always reaches at least 24px below the body, so
	# 20px keeps the player inside it without needing to be outside the 28x28
	# blocking collider too (that only matters for the movement-blocking test
	# above). Every-side approach coverage is section 7 below. ---
	player.position = sample_world + Vector2(0, 20)
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
	print("Wild monster fight started: ", combat.in_combat)
	var anchor_present := false
	for enemy in combat.current_enemies:
		if enemy != null and enemy.name == def.name:
			anchor_present = true
	print("The guaranteed species is present in the fight: ", anchor_present)
	print("Group size is between 1 and 3: ", combat.current_enemies.size() >= 1 and combat.current_enemies.size() <= 3)

	# --- 6. Defeat -> monster_fur granted -> placement permanently marked
	# defeated -> re-approaching no longer starts a fight. ---
	character.stats.max_hp = 500
	character.stats.hp = 500
	character.stats.mp = 999
	var fur_before: int = inventory.get_count("monster_fur")
	var guard := 0
	# Unlike every existing boss-fight verify script (always exactly 1
	# enemy, so cast_spell() auto-resolves), a wild-monster group can be 2-3
	# - cast_spell() with 2+ enemies alive just sets a pending
	# selecting_target instead of resolving, same as player_attack() - needs
	# an explicit select_target() to actually land the hit.
	while combat.in_combat and guard < 60:
		if combat.selecting_target != "":
			combat.select_target(combat.alive_enemies()[0])
		else:
			combat.cast_spell("fireball")
		await process_frame
		guard += 1
	print("Wild monster group defeated (", guard, " actions): ", not combat.in_combat)
	print("monster_fur granted: ", inventory.get_count("monster_fur") > fur_before)
	print("GameState.wild_monsters_defeated set for this placement: ", game_state.wild_monsters_defeated.get(sample.placement_key, false))

	await process_frame
	var alive_tint: Color = def.get("tint", Color(1, 1, 1, 1))
	print("Defeated sprite is dimmed: ", monster.sprite.modulate.is_equal_approx(alive_tint.darkened(0.55)))

	player.position = sample_world + Vector2(0, 20)
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	await _clear_combat(combat)
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Re-approaching a defeated placement does not start a fight: ", not combat.in_combat)

	# --- 7. A real player stops the moment their own sprite visually touches
	# the monster's sprite, from whichever side they came, and presses E right
	# there. The InteractArea is sized at runtime around the VISIBLE sprite
	# (not the small blocking collider at its feet) precisely so that press
	# lands from every side. Regression for the original playtest bug: at 1.6x
	# with the scene's baked 48x48 area only a south approach ever worked.
	# One not-yet-defeated placement per distinct sprite file, since the 5
	# files are all different sizes. ---
	var tilemap: TileMapLayer = overworld.tilemap
	var covered_sprites := {}
	for entry in placements:
		var sprite_path: String = Enemies.ENEMIES[entry.enemy_id].sprite
		if covered_sprites.has(sprite_path) or game_state.wild_monsters_defeated.get(entry.placement_key, false):
			continue
		var target: Node = null
		for child in ysort.get_children():
			if child.scene_file_path == "res://scenes/props/WildMonster.tscn" and child.placement_key == entry.placement_key:
				target = child
		if target == null:
			continue
		var visual_size: Vector2 = target.sprite.texture.get_size() * target.sprite.scale
		var visual_center: Vector2 = target.position + target.sprite.offset * target.sprite.scale
		var body_pos: Vector2 = target.position
		# 13 = player half-width (10) + 3px "stopped just short of touching".
		# South is the one side where the blocking collider stops the player
		# first (at 24px), before their sprite reaches the monster's feet.
		var approaches := {
			"east": Vector2(visual_center.x + visual_size.x / 2.0 + 13.0, body_pos.y),
			"west": Vector2(visual_center.x - visual_size.x / 2.0 - 13.0, body_pos.y),
			"north": Vector2(body_pos.x, visual_center.y - visual_size.y / 2.0 - 13.0),
			"south": Vector2(body_pos.x, maxf(visual_center.y + visual_size.y / 2.0 + 13.0, body_pos.y + 24.0)),
		}
		# Only use a placement whose 4 approach spots are plain ground for its
		# zone - scatter only checks the monster's OWN tile, so one can
		# legitimately sit right beside a mountain/river/lake tile, and a real
		# player simply can't come from that side (a teleport there lands in
		# a solid tile and gets shoved elsewhere). Painted tiles can't be
		# cleared the way props can, so skip to the next placement instead.
		var ground_source: int = world._ground_source_for_zone(entry.zone)
		var open_all_round := true
		for dir in approaches:
			if tilemap.get_cell_source_id(tilemap.local_to_map(approaches[dir])) != ground_source:
				open_all_round = false
		if not open_all_round:
			continue
		covered_sprites[sprite_path] = true
		# Scattered props (and any neighbouring monster) near the target are
		# cleared so a teleport can't land inside a boulder's collider or a
		# neighbour's own interact area - same _clear_point() pattern the
		# interior/seam verify scripts use. queue_free() is deferred, so wait.
		for child in ysort.get_children():
			if child == target or child == player:
				continue
			if child is Node2D and child.position.distance_to(body_pos) < 110.0:
				child.queue_free()
		await process_frame
		await process_frame
		var all_sides := true
		var failed_sides: Array = []
		for dir in approaches:
			player.position = approaches[dir]
			cam.reset_smoothing()
			for i in range(4):
				await physics_frame
			await _clear_combat(combat)
			var tries := 0
			while not combat.in_combat and tries < 5:
				Input.action_press("interact")
				await process_frame
				await process_frame
				Input.action_release("interact")
				await process_frame
				tries += 1
			# Must be THIS monster's fight - a neighbouring placement's area
			# can overlap the approach spot, and that would mask a failure.
			if not (combat.in_combat and combat.current_wild_monster_key == entry.placement_key):
				all_sides = false
				failed_sides.append(dir)
			await _clear_combat(combat)
		print("Interact lands from all 4 sides when stopping at the visible sprite edge [", entry.enemy_id, ", ", sprite_path.get_file(), "]: ", all_sides, "" if all_sides else " (failed: %s)" % [failed_sides])

	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	root.get_texture().get_image().save_png("res://verify_wild_monsters.png")
	print("Saved verify_wild_monsters.png")

	quit()
