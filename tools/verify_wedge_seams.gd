extends SceneTree
# Phase 6b (inter-biome wedge-seam crossings) verification. Run via:
# godot --script res://tools/verify_wedge_seams.gd (NOT --headless - this
# takes real screenshots via get_texture()).
#
# All 4 seams are structurally identical (a diagonal river/ravine divider,
# one ford, one standalone NPC, one gather quest) so this loops the same
# checks over a small data table rather than 4 near-duplicate blocks. Applies
# every established lesson from the start: physics_frame for movement waits,
# a combat.in_combat clear after every teleport/walk in a live-encounter
# zone, positioning with real margin, npc_id-based NPC lookup (there are 7
# standalone NPCs in the overworld now), and tile-source assertions (not just
# movement) for the geometry checks, which are exact and don't depend on
# move_and_slide()'s contact-angle variability the way a pure walk-based
# check would.

func _walk(player: CharacterBody2D, actions: Array, frames: int) -> void:
	for action in actions:
		Input.action_press(action)
	for i in range(frames):
		await physics_frame
	for action in actions:
		Input.action_release(action)
	await physics_frame

func _clear_combat(combat: Node) -> void:
	if combat.in_combat:
		combat.player_run()
		await physics_frame

func _initialize() -> void:
	var world: Node = root.get_node("World")
	var game_state: Node = root.get_node("GameState")
	var quests: Node = root.get_node("Quests")
	var inventory: Node = root.get_node("Inventory")
	var dialogue_ui: Node = root.get_node("DialogueUI")
	var combat: Node = root.get_node("Combat")

	# Each of the 4 seams needs its OWN biome already reachable (its own ring
	# ford open) to even stand near the seam NPC - already covered by each
	# biome's own verify_*_interior.gd, not what this test is about, so just
	# set every flag needed to reach all 4 NPCs directly.
	game_state.village_gates_open = true
	game_state.biome_paths_open.frostpeak = true
	game_state.biome_paths_open.verdantwood = true
	game_state.biome_paths_open.badlands = true
	game_state.biome_paths_open.gloomfen = true

	var seams := [
		{
			"key": "frostpeak_verdantwood", "quest_id": "cross_frostpeak_verdantwood",
			"npc_id": "frost_wood_trailblazer", "npc_pos": world.FROST_TRAILBLAZER_POS,
			"intro_prefix": "Verdantwood's just past this thaw-line",
			"objective": {"type": "gather", "item_id": "wood", "amount": 10},
			"expected_source": world.SRC_RIVER,
			"diagonal": ["move_right", "move_up"], "continue_action": "move_right", "far_zone": world.Zone.VERDANTWOOD,
		},
		{
			"key": "verdantwood_badlands", "quest_id": "cross_verdantwood_badlands",
			"npc_id": "ravine_runner", "npc_pos": world.RAVINE_RUNNER_POS,
			"intro_prefix": "That ravine's the only thing",
			"objective": {"type": "gather_multi", "items": [{"item_id": "wood", "amount": 8}, {"item_id": "stone", "amount": 8}]},
			"expected_source": world.SRC_RAVINE,
			"diagonal": ["move_right", "move_down"], "continue_action": "move_down", "far_zone": world.Zone.BADLANDS,
		},
		{
			"key": "badlands_gloomfen", "quest_id": "cross_badlands_gloomfen",
			"npc_id": "bog_ash_wanderer", "npc_pos": world.BOG_ASH_WANDERER_POS,
			"intro_prefix": "Gloomfen's past that bog",
			"objective": {"type": "gather", "item_id": "stone", "amount": 10},
			"expected_source": world.SRC_RIVER,
			"diagonal": ["move_left", "move_down"], "continue_action": "move_left", "far_zone": world.Zone.GLOOMFEN,
		},
		{
			"key": "gloomfen_frostpeak", "quest_id": "cross_gloomfen_frostpeak",
			"npc_id": "frozen_mire_scout", "npc_pos": world.FROZEN_MIRE_SCOUT_POS,
			"intro_prefix": "Frostpeak's just past this mire",
			"objective": {"type": "gather", "item_id": "wood", "amount": 10},
			"expected_source": world.SRC_RIVER,
			"diagonal": ["move_left", "move_up"], "continue_action": "move_up", "far_zone": world.Zone.FROSTPEAK,
		},
	]

	# --- 0. Geometry: each seam's divider is solid before any quest completes. ---
	var overworld0: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld0)
	current_scene = overworld0
	await process_frame
	await process_frame
	var terrain0: TileMapLayer = overworld0.get_node("TileMapLayer")
	for seam in seams:
		var ford_pos: Vector2i = world.SEAM_FORDS[seam.key]
		print("[%s] Divider blocks the seam before its quest (source): " % seam.key, terrain0.get_cell_source_id(ford_pos) == seam.expected_source)
	root.remove_child(overworld0)
	overworld0.queue_free()
	await process_frame

	# --- For each seam: quest flow via its NPC, then the ford opens and the
	# crossing actually reaches the far biome. ---
	for seam in seams:
		var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
		root.add_child(overworld)
		current_scene = overworld
		await process_frame
		await process_frame

		var player: CharacterBody2D = overworld.get_node("YSort/Player")
		var cam: Camera2D = player.get_node("Camera2D")
		var ysort: Node2D = overworld.get_node("YSort")
		var npc: Node = null
		for child in ysort.get_children():
			if child.get("npc_id") == seam.npc_id:
				npc = child
		print("[%s] NPC found: " % seam.key, npc != null)

		player.position = npc.position + Vector2(0, 20)
		cam.reset_smoothing()
		for i in range(3):
			await process_frame
		await _clear_combat(combat)

		# One-time intro first.
		Input.action_press("interact")
		await process_frame
		await process_frame
		Input.action_release("interact")
		await process_frame
		print("[%s] Intro shown first: " % seam.key, dialogue_ui.text_label.text.begins_with(seam.intro_prefix))
		Input.action_press("interact")
		await process_frame
		Input.action_release("interact")
		await process_frame

		# Offer -> accept.
		await _clear_combat(combat)
		Input.action_press("interact")
		await process_frame
		await process_frame
		Input.action_release("interact")
		await process_frame
		var offer_actions: Array = dialogue_ui.actions_row.get_children()
		offer_actions[0].pressed.emit()
		await process_frame
		print("[%s] Quest accepted: " % seam.key, quests.quest_state.get(seam.quest_id, "") == "accepted")

		# Give the full gather amount directly (each individual gather-quest
		# mechanic - partial progress, gather_multi - is already thoroughly
		# covered by the 5 earlier ford/gate quest verify scripts; this test's
		# job is the seam/NPC/quest wiring, not re-testing that UI).
		if seam.objective.has("items"):
			for entry in seam.objective.items:
				inventory.add_item(entry.item_id, entry.amount)
		else:
			inventory.add_item(seam.objective.item_id, seam.objective.amount)
		await _clear_combat(combat)
		Input.action_press("interact")
		await process_frame
		await process_frame
		Input.action_release("interact")
		await process_frame
		var ready_actions: Array = dialogue_ui.actions_row.get_children()
		ready_actions[0].pressed.emit()
		await process_frame
		print("[%s] Quest marked completed: " % seam.key, quests.quest_state.get(seam.quest_id, "") == "completed")
		print("[%s] Seam flag opened: " % seam.key, game_state.seam_paths_open[seam.key] == true)

		root.remove_child(overworld)
		overworld.queue_free()
		await process_frame

		# --- Ford now open (fresh Overworld reload), crossing reaches the far biome. ---
		var overworld2: Node2D = load("res://scenes/Overworld.tscn").instantiate()
		root.add_child(overworld2)
		current_scene = overworld2
		await process_frame
		await process_frame
		var terrain2: TileMapLayer = overworld2.get_node("TileMapLayer")
		var ford_pos: Vector2i = world.SEAM_FORDS[seam.key]
		print("[%s] Ford opened (source is SRC_FORD): " % seam.key, terrain2.get_cell_source_id(ford_pos) == world.SRC_FORD)

		var player2: CharacterBody2D = overworld2.get_node("YSort/Player")
		var cam2: Camera2D = player2.get_node("Camera2D")
		# Every OTHER tile along the same diagonal (both nearer and farther
		# from center) is still solid river/ravine - the ford is a single-tile
		# gap - so teleporting a few tiles back along the exact diagonal (as
		# an "approach" position) risks landing ON one of those still-solid
		# tiles. Start directly on the now-open ford tile itself instead
		# (already confirmed walkable above) and walk outward from there.
		player2.position = Vector2(ford_pos.x * 32 + 16, ford_pos.y * 32 + 16)
		cam2.reset_smoothing()
		for i in range(3):
			await process_frame
		await _clear_combat(combat)
		# A pure diagonal walk stays exactly on the seam's tie line forever -
		# biome_at()'s own tie-break always resolves an exact dx==dy tile to
		# the dy-branch (Frostpeak/Badlands), so it can never reach a
		# Verdantwood/Gloomfen far_zone even standing right on an open ford.
		# A real player naturally drifts off that line - walk in just one
		# cardinal direction (continue_action) to do the same.
		await _walk(player2, [seam.continue_action], 80)
		await _clear_combat(combat)
		var landed_zone: int = world.biome_at(int(player2.position.x / 32), int(player2.position.y / 32)).zone
		print("[%s] Crossing reaches the far biome: " % seam.key, landed_zone == seam.far_zone)

		root.remove_child(overworld2)
		overworld2.queue_free()
		await process_frame

	root.get_texture().get_image().save_png("res://verify_wedge_seams.png")
	quit()
