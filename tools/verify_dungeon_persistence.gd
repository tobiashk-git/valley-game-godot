extends SceneTree
# Dungeon persistence verification. Run via:
# godot --script res://tools/verify_dungeon_persistence.gd (NOT --headless).
#
# A maze keeps its layout for the whole save (seed per dungeon, drawn on
# the first visit): re-entering gives the same map, the Castle gets its own,
# the seed survives a save round-trip through JSON, and a new game draws a
# fresh layout. Monsters respawn every visit until the boss is beaten, then
# the maze stays empty.

func _map_of(scene: Node2D) -> Array:
	var out: Array = []
	for row in scene._gen.map:
		out.append(row.duplicate())
	return out

func _open(path: String) -> Node2D:
	var scene: Node2D = load(path).instantiate()
	root.add_child(scene)
	current_scene = scene
	return scene

func _close(scene: Node2D) -> void:
	scene.queue_free()
	await process_frame
	await process_frame

func _clear_combat(combat: Node) -> void:
	var attempts := 0
	while combat.in_combat and attempts < 10:
		combat.player_run()
		await physics_frame
		attempts += 1

# Hop along every corridor tile (each uncovers fog); true if a fight started.
func _explore(scene: Node2D, combat: Node) -> bool:
	var player: CharacterBody2D = scene.get_node("YSort/Player")
	for corridor in scene._gen.corridors:
		for t in corridor:
			player.position = scene._tile_center(t)
			await process_frame
			await physics_frame
			if combat.in_combat:
				return true
	return false

func _initialize() -> void:
	var combat: Node = root.get_node("Combat")
	var game_state: Node = root.get_node("GameState")
	var storage: Node = root.get_node("Storage")
	var save: Node = root.get_node("SaveSystem")
	await process_frame
	game_state.reset()
	root.get_node("Inventory").reset()
	storage.reset()
	combat._steps_since_encounter = -1000000

	# --- same layout on every visit ---
	var d1: Node2D = _open("res://scenes/Dungeon.tscn")
	for i in range(3):
		await process_frame
	var map_a: Array = _map_of(d1)
	var seed_a: int = game_state.dungeon_seeds.get("dungeon", -1)
	var chest_a: Vector2 = d1.chests[0].position
	await _close(d1)
	var d2: Node2D = _open("res://scenes/Dungeon.tscn")
	for i in range(3):
		await process_frame
	print("First visit draws a seed for the dungeon and keeps it: ", seed_a >= 0 and game_state.dungeon_seeds.get("dungeon", -2) == seed_a)
	print("Second visit lays out the identical maze, chest in the same place: ", _map_of(d2) == map_a and d2.chests[0].position == chest_a)
	await _close(d2)
	var c1: Node2D = _open("res://scenes/Castle.tscn")
	for i in range(3):
		await process_frame
	print("The Castle draws its own seed and a different map: ", game_state.dungeon_seeds.has("castle") and game_state.dungeon_seeds.castle != seed_a and _map_of(c1) != map_a)
	await _close(c1)

	# --- the seed rides in the save (through JSON like the real file) ---
	var snap: Dictionary = save.snapshot()
	var json: Variant = JSON.parse_string(JSON.stringify(snap))
	game_state.reset()
	print("A new game forgets every seed: ", game_state.dungeon_seeds.is_empty())
	var d3: Node2D = _open("res://scenes/Dungeon.tscn")
	for i in range(3):
		await process_frame
	var fresh_differs: bool = game_state.dungeon_seeds.dungeon != seed_a and _map_of(d3) != map_a
	await _close(d3)
	print("...and lays out a fresh dungeon: ", fresh_differs)
	save.apply(json)
	var d4: Node2D = _open("res://scenes/Dungeon.tscn")
	for i in range(3):
		await process_frame
	print("Loading the save brings the old seed (as an int) and the old maze back: ", game_state.dungeon_seeds.dungeon == seed_a and typeof(game_state.dungeon_seeds.dungeon) == TYPE_INT and _map_of(d4) == map_a)

	# --- monsters until the boss sleeps, then nothing ---
	combat._steps_since_encounter = 1000
	var fought: bool = await _explore(d4, combat)
	print("Boss still awake: exploring the corridors runs into a monster (encounters active): ", d4.encounters_active() and fought)
	await _clear_combat(combat)
	await _close(d4)
	game_state.boss_defeated.dungeon_boss = true
	var d5: Node2D = _open("res://scenes/Dungeon.tscn")
	for i in range(3):
		await process_frame
	combat._steps_since_encounter = 1000
	var steps_before: int = d5.explore_steps
	var fought_after: bool = await _explore(d5, combat)
	print("Boss beaten: the whole maze explored (", d5.explore_steps - steps_before, " new-ground steps) without a single encounter: ", not d5.encounters_active() and not fought_after and d5.explore_steps - steps_before >= 20 and not combat.in_combat)
	# --- the map stays revealed across visits and saves ---
	var remembered: Vector2i = d5._gen.corridors[1][2]
	var boss_seen: bool = not d5._boss_reveal_pending
	var snap2: Variant = JSON.parse_string(JSON.stringify(save.snapshot()))
	await _close(d5)
	var d6: Node2D = _open("res://scenes/Dungeon.tscn")
	for i in range(3):
		await process_frame
	print("Ground uncovered on an earlier visit is already clear on the next, and the boss room reveal does not replay: ", boss_seen and d6.fog.get_cell_source_id(remembered) == -1 and not d6._boss_reveal_pending)
	combat._steps_since_encounter = -1000000
	var steps6: int = d6.explore_steps
	var p6: CharacterBody2D = d6.get_node("YSort/Player")
	for t in d6._gen.corridors[0].slice(0, 6):
		p6.position = d6._tile_center(t)
		await process_frame
		await process_frame
	print("Remembered corridors still count as new ground for this visit (monsters roam them again): ", d6.explore_steps - steps6 >= 3)
	await _close(d6)
	game_state.reset()
	print("A new game forgets the revealed ground: ", game_state.dungeon_revealed.is_empty())
	save.apply(snap2)
	var d7: Node2D = _open("res://scenes/Dungeon.tscn")
	for i in range(3):
		await process_frame
	print("Loading the save brings the revealed ground back through JSON: ", d7.fog.get_cell_source_id(remembered) == -1 and not d7._boss_reveal_pending)
	await _close(d7)
	game_state.cutscene = false
	quit()
