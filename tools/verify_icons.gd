extends SceneTree

func _initialize() -> void:
	var overworld_scene: PackedScene = load("res://scenes/Overworld.tscn")
	var overworld: Node2D = overworld_scene.instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame

	var inventory: Node = root.get_node("Inventory")
	var character: Node = root.get_node("Character")
	var combat: Node = root.get_node("Combat")

	inventory.add_item("wood", 12)
	inventory.add_item("stone", 8)
	inventory.add_item("gold", 50)
	inventory.add_item("wooden_pickaxe", 1)
	inventory.add_item("healing_potion", 2)
	character.equip("weapon", "wooden_pickaxe")

	await process_frame
	root.get_texture().get_image().save_png("res://verify_icons_hud.png")

	# --- Inventory panel ---
	Input.action_press("toggle_inventory")
	await process_frame
	Input.action_release("toggle_inventory")
	await process_frame
	root.get_texture().get_image().save_png("res://verify_icons_inventory.png")
	Input.action_press("toggle_inventory")
	await process_frame
	Input.action_release("toggle_inventory")
	await process_frame

	# --- Character panel ---
	Input.action_press("toggle_character")
	await process_frame
	Input.action_release("toggle_character")
	await process_frame
	root.get_texture().get_image().save_png("res://verify_icons_character.png")
	Input.action_press("toggle_character")
	await process_frame
	Input.action_release("toggle_character")
	await process_frame

	# --- Crafting panel ---
	Input.action_press("toggle_crafting")
	await process_frame
	Input.action_release("toggle_crafting")
	await process_frame
	root.get_texture().get_image().save_png("res://verify_icons_crafting.png")
	Input.action_press("toggle_crafting")
	await process_frame
	Input.action_release("toggle_crafting")
	await process_frame

	# --- Battle magic submenu ---
	combat.start_combat("dungeon_rat")
	await process_frame
	combat.open_magic_menu()
	await process_frame
	root.get_texture().get_image().save_png("res://verify_icons_magic.png")
	combat.player_run()
	await process_frame

	quit()
