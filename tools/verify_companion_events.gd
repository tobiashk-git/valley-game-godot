extends SceneTree
# Companion joining events verification. Run via:
# godot --script res://tools/verify_companion_events.gd (NOT --headless).
#
# Luigi and Eden follow the story: once a ford opens, the one who comes
# along for that biome waits ON the crossing (blocking it) with a "!";
# accepting settles the quest on the spot and they walk with Oliver (off the
# map). Luigi for Frostpeak; Eden alone for Verdantwood (Luigi is sent
# home); both at the Badlands ford. Combat's roster reads the same states.

func _npc(scene: Node2D, npc_name: String) -> Node:
	for child in scene.get_node("YSort").get_children():
		if child.get("npc_name") == npc_name:
			return child
	return null

func _talk(player: CharacterBody2D, npc: Node, side: Vector2 = Vector2(0, 30)) -> void:
	player.position = npc.position + side
	for i in range(3):
		await physics_frame
	await process_frame
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame
	await process_frame

func _press_e() -> void:
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame
	await process_frame
	await process_frame

# Whether a solid body stands on a tile (the ford blocker).
func _body_at(scene: Node2D, tile: Vector2i) -> Node:
	var params := PhysicsPointQueryParameters2D.new()
	params.position = Vector2(tile.x * 32 + 16, tile.y * 32 + 16)
	params.collide_with_bodies = true
	params.collide_with_areas = false
	for hit in scene.get_world_2d().direct_space_state.intersect_point(params, 8):
		if hit.collider is StaticBody2D and hit.collider.get("npc_name") != null:
			return hit.collider
	return null

func _initialize() -> void:
	var world: Node = root.get_node("World")
	var quests: Node = root.get_node("Quests")
	var combat: Node = root.get_node("Combat")
	var game_state: Node = root.get_node("GameState")
	var dialogue_ui: Node = root.get_node("DialogueUI")
	await process_frame
	game_state.reset()
	quests.reset()
	root.get_node("Inventory").reset()
	root.get_node("Character").reset()
	MapRecipe.active_path = "res://tools/no_such_recipe.json"
	world.reload_places()
	quests.quest_state.meet_villagers = "completed"
	quests.npcs_met.luigi = true
	quests.npcs_met.eden = true
	game_state.village_gates_open = true
	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	for i in range(3):
		await process_frame
	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var luigi: Node = _npc(overworld, "Luigi the Fearless")
	var eden: Node = _npc(overworld, "Eden")
	var north: Vector2i = world.BIOME_FORDS[world.Zone.FROSTPEAK]
	var east: Vector2i = world.BIOME_FORDS[world.Zone.VERDANTWOOD]
	var south: Vector2i = world.BIOME_FORDS[world.Zone.BADLANDS]
	var at := func(npc: Node, tile: Vector2i) -> bool: return npc.visible and npc.position == Vector2(tile.x * 32 + 16, tile.y * 32 + 16)

	print("With the gates open and no ford yet, both stand on the square with no quest: ", at.call(luigi, world.place("luigi")) and at.call(eden, world.place("eden")) and luigi.quest_ids.is_empty() and luigi.marker_kind() == "")
	print("The joining events sit in their chapters of the story line: ", quests.chapter_of("join_luigi") == "frostpeak" and quests.chapter_of("join_eden") == "verdantwood" and quests.chapter_of("join_pair") == "badlands" and quests.chapter_quests("frostpeak").has("join_luigi"))

	# --- the northern ford opens: Luigi waits on the crossing ---
	quests.quest_state.cross_frostpeak = "completed"
	game_state.biome_paths_open.frostpeak = true
	quests.changed.emit()
	await physics_frame
	await process_frame
	print("The northern ford opens: Luigi moves onto the crossing tile with a '!', Eden stays on the square: ", at.call(luigi, north) and luigi.marker_kind() == "!" and luigi.active_quest() == "join_luigi" and at.call(eden, world.place("eden")))
	print("He blocks the ford (a solid body on the crossing tile): ", _body_at(overworld, north) == luigi)
	print("Frostpeak fights are still Oliver alone until he is asked: ", combat.roster_for_zone(world.Zone.FROSTPEAK).is_empty())
	root.get_texture().get_image().save_png("res://verify_companion_events_ford.png")
	await _talk(player, luigi)
	print("Talking gives his offer with Accept: ", dialogue_ui.is_open() and dialogue_ui.text_label.text.begins_with("Woof - there you are") and dialogue_ui.actions_row.get_child_count() >= 2)
	await _press_e() # Accept (the highlighted first choice)
	await process_frame
	print("Accepting settles it on the spot: A Fearless Friend completed, his 'walks at your side' line shows: ", quests.quest_state.get("join_luigi", "") == "completed" and dialogue_ui.is_open() and dialogue_ui.text_label.text.begins_with("Luigi the Fearless walks at your side"))
	dialogue_ui.hide_dialogue()
	await physics_frame
	await process_frame
	print("Luigi is with Oliver now: off the map, the ford clear: ", not luigi.visible and _body_at(overworld, north) == null)
	print("Frostpeak fights bring Luigi (and the Revenant's), nobody in Verdantwood yet: ", combat.roster_for_zone(world.Zone.FROSTPEAK) == ["luigi"] and combat.roster_for_event(combat.BOSS_EVENT.frostpeak_boss) == ["luigi"] and combat.roster_for_zone(world.Zone.VERDANTWOOD).is_empty())

	# --- the eastern ford opens: Eden waits, Luigi beside her ---
	quests.quest_state.cross_verdantwood = "completed"
	game_state.biome_paths_open.verdantwood = true
	quests.changed.emit()
	await physics_frame
	await process_frame
	var beside_east: Vector2i = overworld._ford_spots(world.Zone.VERDANTWOOD).beside
	print("The eastern ford opens: Eden on the crossing with a '!', Luigi waiting beside her on the bank: ", at.call(eden, east) and eden.marker_kind() == "!" and _body_at(overworld, east) == eden and at.call(luigi, beside_east) and luigi.marker_kind() == "")
	await _talk(player, eden, Vector2(-30, 0)) # the valley bank is west of the eastern ford
	var offer_ok: bool = dialogue_ui.is_open() and dialogue_ui.text_label.text.begins_with("Verdantwood, hm?")
	await _press_e()
	await process_frame
	dialogue_ui.hide_dialogue()
	await physics_frame
	await process_frame
	print("Her offer, accepted: A Small Loud Guide completed, Eden with Oliver, Luigi sent home to the square: ", offer_ok and quests.quest_state.get("join_eden", "") == "completed" and not eden.visible and at.call(luigi, world.place("luigi")) and luigi.dialogue_text.begins_with("Woods, pup?"))
	print("Verdantwood fights bring Eden alone; Frostpeak still Luigi: ", combat.roster_for_zone(world.Zone.VERDANTWOOD) == ["eden"] and combat.roster_for_zone(world.Zone.FROSTPEAK) == ["luigi"] and combat.roster_for_zone(world.Zone.BADLANDS).is_empty())

	# --- the southern ford opens: the pair wait together ---
	quests.quest_state.cross_badlands = "completed"
	game_state.biome_paths_open.badlands = true
	quests.changed.emit()
	await physics_frame
	await process_frame
	var beside_south: Vector2i = overworld._ford_spots(world.Zone.BADLANDS).beside
	print("The southern ford opens: Luigi on the crossing with the pair's '!', Eden beside him: ", at.call(luigi, south) and luigi.active_quest() == "join_pair" and luigi.marker_kind() == "!" and at.call(eden, beside_south) and eden.dialogue_text.begins_with("Talk to Luigi"))
	root.get_texture().get_image().save_png("res://verify_companion_events_pair.png")
	await _talk(player, luigi, Vector2(0, -30)) # the valley bank is north of the southern ford
	var pair_offer: bool = dialogue_ui.is_open() and dialogue_ui.text_label.text.begins_with("Woof! We've talked it over")
	await _press_e()
	await process_frame
	dialogue_ui.hide_dialogue()
	await physics_frame
	await process_frame
	print("The Fearless Pair accepted: both with Oliver, the ford clear: ", pair_offer and quests.quest_state.get("join_pair", "") == "completed" and not luigi.visible and not eden.visible and _body_at(overworld, south) == null)
	print("Badlands, Gloomfen and the finale bring both: ", combat.roster_for_zone(world.Zone.BADLANDS) == ["luigi", "eden"] and combat.roster_for_zone(world.Zone.GLOOMFEN) == ["luigi", "eden"] and combat.roster_for_event(combat.BOSS_EVENT.final_boss) == ["luigi", "eden"])

	# --- the pair event first (fords open in any order): it settles the other two ---
	quests.reset()
	quests.quest_state.meet_villagers = "completed"
	quests.quest_state.cross_gloomfen = "completed"
	game_state.biome_paths_open = {"frostpeak": false, "verdantwood": false, "badlands": false, "gloomfen": true}
	quests.changed.emit()
	await physics_frame
	await process_frame
	print("Gloomfen first: the pair stay on the square (their event is the southern ford's) and the marsh is fought alone: ", at.call(luigi, world.place("luigi")) and at.call(eden, world.place("eden")) and luigi.quest_ids.is_empty() and combat.roster_for_zone(world.Zone.GLOOMFEN).is_empty())
	quests.quest_state.cross_badlands = "completed"
	game_state.biome_paths_open.badlands = true
	quests.changed.emit()
	await physics_frame
	await process_frame
	quests._accept_quest("join_pair")
	await process_frame
	print("Their event settles the single events too, so Luigi and Eden come along everywhere after: ", quests.quest_state.get("join_luigi", "") == "completed" and quests.quest_state.get("join_eden", "") == "completed" and combat.roster_for_zone(world.Zone.FROSTPEAK) == ["luigi"] and combat.roster_for_zone(world.Zone.GLOOMFEN) == ["luigi", "eden"] and not luigi.visible)
	print("Each chapter chain reads ford -> join -> hunt: ", quests.chain_of("hunt_frostpeak") == ["cross_frostpeak", "join_luigi", "hunt_frostpeak"] and quests.chain_of("hunt_badlands") == ["cross_badlands", "join_pair", "hunt_badlands"] and quests.step_of("join_eden") == [2, 3])
	var snap: Dictionary = root.get_node("SaveSystem").snapshot()
	print("The events are part of the save (quest state): ", snap.quests.state.get("join_pair", "") == "completed")
	quit()
