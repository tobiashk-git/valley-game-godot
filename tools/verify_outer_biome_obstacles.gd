extends SceneTree
# Stage 1 (Verdantwood mighty oaks) verification. Run via:
# godot --script res://tools/verify_outer_biome_obstacles.gd (NOT --headless -
# this takes a real screenshot via get_texture()).

func _walk(player: CharacterBody2D, action: String, frames: int) -> void:
	Input.action_press(action)
	for i in range(frames):
		await physics_frame
	Input.action_release(action)
	await physics_frame

func _initialize() -> void:
	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	var world: Node = root.get_node("World")
	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")
	var combat: Node = root.get_node("Combat")
	var ysort: Node2D = overworld.get_node("YSort")
	await process_frame

	# Confirmed directly this run: Godot's sibling auto-rename for repeated
	# same-scene instances does NOT produce "MightyOak2"/"MightyOak3" - only
	# the very first instance keeps the name "MightyOak", every other one
	# gets an opaque "@StaticBody2D@N" internal name. scene_file_path (set
	# on the root of any instantiated PackedScene, immune to node renaming)
	# is the reliable match - same lesson as the npc_id-based NPC lookup
	# gotcha, just discovered fresh for props here.
	var oaks: Array = []
	for child in ysort.get_children():
		if child.scene_file_path == "res://scenes/props/MightyOak.tscn":
			oaks.append(child)
	print("MightyOak instances scattered: ", oaks.size())
	print("At least one oak present: ", oaks.size() > 0)

	if oaks.is_empty():
		quit()
		return

	# Every found oak should genuinely be in Verdantwood territory (not
	# leaked into an adjacent biome or the valley).
	var all_in_verdantwood := true
	for oak in oaks:
		var tile := Vector2i(int(oak.position.x / 32), int(oak.position.y / 32))
		if world.biome_at(tile.x, tile.y).zone != world.Zone.VERDANTWOOD:
			all_in_verdantwood = false
			break
	print("Every scattered oak is in Zone.VERDANTWOOD: ", all_in_verdantwood)

	# --- Real collision check: walk straight into a known oak, confirm it
	# actually blocks movement rather than just rendering on top. ---
	var target: Node2D = oaks[0]
	player.position = target.position + Vector2(0, 48) # a tile and a half below it
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	if combat.in_combat:
		combat.player_run()
		await physics_frame
	await _walk(player, "move_up", 60) # 60 ticks * ~2.67px/tick ~= 160px, well past the oak if unobstructed
	print("Oak blocks movement (player stopped short of it): ", player.position.y > target.position.y + 8.0)

	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	root.get_texture().get_image().save_png("res://verify_outer_biome_obstacles.png")
	print("Saved verify_outer_biome_obstacles.png")

	quit()
