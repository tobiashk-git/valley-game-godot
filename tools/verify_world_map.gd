extends SceneTree

func _walk(direction: String, frames: int) -> void:
	Input.action_press(direction)
	for i in range(frames):
		await process_frame
	Input.action_release(direction)
	await process_frame

func _initialize() -> void:
	var world: Node = root.get_node("World")
	var game_state: Node = root.get_node("GameState")
	var world_map: Node = root.get_node("WorldMap")
	var world_map_panel: Node = root.get_node("WorldMapPanel")

	# --- Fresh Overworld: dungeon not yet discovered, map lists house+village only. ---
	var overworld_scene: PackedScene = load("res://scenes/Overworld.tscn")
	var overworld: Node2D = overworld_scene.instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame

	print("Dungeon undiscovered at boot: ", not game_state.discovered_pois.dungeon)

	Input.action_press("toggle_map")
	await process_frame
	Input.action_release("toggle_map")
	await process_frame
	var list: VBoxContainer = world_map_panel.get_node("Panel/Margin/VBox/List")
	var row_names: Array = []
	for row in list.get_children():
		if row is HBoxContainer:
			row_names.append((row.get_child(0) as Label).text)
	print("Map lists House: ", "Your House" in row_names)
	print("Map lists Village: ", "Village" in row_names)
	print("Map does NOT list Dungeon yet: ", not ("Dungeon" in row_names))
	print("Status line while on Overworld: ", world_map_panel.status_label.text)
	root.get_texture().get_image().save_png("res://verify_map_before_dungeon.png")
	Input.action_press("toggle_map")
	await process_frame
	Input.action_release("toggle_map")
	await process_frame

	# --- Walk to the dungeon entrance's adjacent tile and press E: real portal path. ---
	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var approach: Vector2i = world.DUNGEON_ENTRANCE + Vector2i(0, 2)
	player.position = Vector2(approach.x * 32 + 16, approach.y * 32 + 16)
	var cam: Camera2D = player.get_node("Camera2D")
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	await _walk("move_up", 40)
	# Portals are E-press, never walk-through (matching every interactable's
	# convention in this project) - the walk above just gets us adjacent.
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Entered the Dungeon via the real portal: ", current_scene.name == "Dungeon")
	print("Dungeon marked discovered after entering: ", game_state.discovered_pois.dungeon)

	# --- Walk to the dungeon's door and back out. ---
	var dungeon_player: CharacterBody2D = current_scene.get_node("YSort/Player")
	# The player spawns right next to the door already (door_y - 1); one
	# step down onto the door tile puts them in range, then E triggers it.
	for i in range(3):
		await process_frame
	await _walk("move_down", 20)
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Left the Dungeon via the real portal: ", current_scene.name == "Overworld")
	var back_tile := Vector2i(int(current_scene.get_node("YSort/Player").position.x / 32), int(current_scene.get_node("YSort/Player").position.y / 32))
	print("Landed just outside the dungeon entrance: ", back_tile == world.DUNGEON_ENTRANCE + Vector2i(0, 1))

	# --- Map now lists Dungeon too. ---
	Input.action_press("toggle_map")
	await process_frame
	Input.action_release("toggle_map")
	await process_frame
	row_names = []
	for row in list.get_children():
		if row is HBoxContainer:
			row_names.append((row.get_child(0) as Label).text)
	print("Map now lists Dungeon: ", "Dungeon" in row_names)
	root.get_texture().get_image().save_png("res://verify_map_after_dungeon.png")

	# --- Fast travel to House from the Overworld itself. ---
	var house_row: HBoxContainer = null
	for row in list.get_children():
		if row is HBoxContainer and (row.get_child(0) as Label).text == "Your House":
			house_row = row
	var house_btn: Button = house_row.get_child(1)
	house_btn.pressed.emit()
	await process_frame
	await process_frame
	print("Fast travel landed on Overworld: ", current_scene.name == "Overworld")
	var house_tile := Vector2i(int(current_scene.get_node("YSort/Player").position.x / 32), int(current_scene.get_node("YSort/Player").position.y / 32))
	print("Fast travel landed at the House entrance: ", house_tile == world.HOUSE_ENTRANCE + Vector2i(0, 1))

	# --- Fast travel from inside an interior (Elder House) to the Village. ---
	var elder_scene: PackedScene = load("res://scenes/ElderHouse.tscn")
	change_scene_to_packed(elder_scene)
	await process_frame
	await process_frame
	print("Now inside the Elder's House: ", current_scene.name == "ElderHouse")
	Input.action_press("toggle_map")
	await process_frame
	Input.action_release("toggle_map")
	await process_frame
	print("Status line while inside a house: ", world_map_panel.status_label.text)
	var village_row: HBoxContainer = null
	for row in list.get_children():
		if row is HBoxContainer and (row.get_child(0) as Label).text == "Village":
			village_row = row
	var village_btn: Button = village_row.get_child(1)
	village_btn.pressed.emit()
	await process_frame
	await process_frame
	print("Fast travel from an interior lands on Overworld: ", current_scene.name == "Overworld")
	var village_tile := Vector2i(int(current_scene.get_node("YSort/Player").position.x / 32), int(current_scene.get_node("YSort/Player").position.y / 32))
	print("Landed at the village spawn point: ", village_tile == world.VILLAGE_GATES.south + Vector2i(0, -2))

	quit()
