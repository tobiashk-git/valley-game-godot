extends SceneTree
# Luigi the Fearless and Eden verification. Run via:
# godot --script res://tools/verify_new_npcs.gd (NOT --headless).
#
# Two new villagers stand on the square off the axis paths, each with a
# one-time intro then an idle line, an npc_id for npcs_met, a portrait slot
# (shown once the bust exists), and each is a movable place the recipe can
# relocate. Painted art, when present, is drawn at its art_height with an
# interact area covering the figure.

const TEST_PATH := "res://tools/verify_npcs_recipe.json"

func _npc(scene: Node2D, npc_name: String) -> Node:
	for child in scene.get_node("YSort").get_children():
		if child.get("npc_name") == npc_name:
			return child
	return null

func _talk(player: CharacterBody2D, npc: Node) -> void:
	player.position = npc.position + Vector2(0, 24)
	for i in range(3):
		await physics_frame
	await process_frame
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame
	await process_frame

func _initialize() -> void:
	var world: Node = root.get_node("World")
	var quests: Node = root.get_node("Quests")
	var dialogue_ui: Node = root.get_node("DialogueUI")
	await process_frame
	root.get_node("GameState").reset()
	quests.reset()
	MapRecipe.active_path = "res://tools/no_such_recipe.json"
	world.reload_places()
	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	for i in range(3):
		await process_frame
	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var luigi: Node = _npc(overworld, "Luigi the Fearless")
	var eden: Node = _npc(overworld, "Eden")
	var cx: int = world.WORLD_CENTER_X
	var cy: int = world.WORLD_CENTER_Y
	print("Luigi and Eden stand on the village square at their places, off the axis paths: ", luigi != null and eden != null and luigi.position == Vector2(world.place("luigi").x * 32 + 16, world.place("luigi").y * 32 + 16) and eden.position == Vector2(world.place("eden").x * 32 + 16, world.place("eden").y * 32 + 16) and world.place("luigi").x != cx and world.place("luigi").y != cy and world.place("eden").x != cx and world.place("eden").y != cy)
	print("Both are movable places with labels: ", world.PLACE_DEFAULTS.has("luigi") and world.PLACE_DEFAULTS.has("eden") and world.PLACE_LABELS.luigi == "Luigi the Fearless" and world.PLACE_LABELS.eden == "Eden" and world.place_at(world.place("eden")) == "eden")
	print("Both carry npc ids and a sprite: ", luigi.npc_id == "luigi" and eden.npc_id == "eden" and luigi.sprite.texture != null and eden.sprite.texture != null)
	var luigi_art: bool = luigi.art_height > 0.0
	print("Luigi: painted art at its height with a figure-sized interact area (or the placeholder until the art lands - art now = ", luigi_art, "): ", (not luigi_art) or (absf(luigi.sprite.get_rect().size.y * luigi.sprite.scale.y - luigi.art_height) < 1.0 and luigi.interact_area.get_node("CollisionShape2D").shape.size.y > 48.0))

	await _talk(player, luigi)
	print("First talk to Luigi: his intro, and he is met: ", dialogue_ui.is_open() and dialogue_ui.text_label.text.begins_with("Woof!") and quests.npcs_met.get("luigi", false))
	dialogue_ui.hide_dialogue()
	await process_frame
	await _talk(player, luigi)
	print("Second talk: his idle line: ", dialogue_ui.text_label.text.begins_with("Stand tall, pup"))
	dialogue_ui.hide_dialogue()
	await process_frame
	await _talk(player, eden)
	print("First talk to Eden: her intro: ", dialogue_ui.text_label.text.begins_with("Oh! A new face") and quests.npcs_met.get("eden", false))
	dialogue_ui.hide_dialogue()
	await process_frame
	await _talk(player, eden)
	print("Second talk: her idle line: ", dialogue_ui.text_label.text.begins_with("Psst."))
	root.get_texture().get_image().save_png("res://verify_new_npcs.png")
	print("Saved verify_new_npcs.png")
	dialogue_ui.hide_dialogue()
	await process_frame
	var have_portraits: bool = ResourceLoader.exists("res://assets/portraits/luigi.png") and ResourceLoader.exists("res://assets/portraits/eden.png")
	print("Portrait slots exist for both (busts present now = ", have_portraits, "): ", dialogue_ui.PORTRAITS.has("Luigi the Fearless") and dialogue_ui.PORTRAITS.has("Eden") and ((not have_portraits) or (dialogue_ui.portrait_for("Luigi the Fearless") != null and dialogue_ui.portrait_for("Eden") != null)))
	overworld.queue_free()
	await process_frame
	await process_frame

	# --- the recipe moves Luigi to the dungeon gate ---
	var gate: Vector2i = world.place("dungeon") + Vector2i(0, 2)
	MapRecipe.save_to(TEST_PATH, {"version": 1, "places": {"luigi": [gate.x, gate.y]}})
	MapRecipe.active_path = TEST_PATH
	world.reload_places()
	var again: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(again)
	current_scene = again
	for i in range(3):
		await process_frame
	var luigi2: Node = _npc(again, "Luigi the Fearless")
	print("A recipe moves Luigi below the dungeon gate (the story can walk him around): ", luigi2 != null and luigi2.position == Vector2(gate.x * 32 + 16, gate.y * 32 + 16))
	again.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	MapRecipe.active_path = MapRecipe.DEFAULT_PATH
	world.reload_places()
	quit()
