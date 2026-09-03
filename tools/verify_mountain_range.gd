extends SceneTree
# Real-render check for the new impassable mountain range replacing the old
# wedge-seam crossings. Run via:
# godot --script res://tools/verify_mountain_range.gd (NOT --headless - this
# takes real screenshots via get_texture()).

func _walk(player: CharacterBody2D, action: String, frames: int) -> void:
	Input.action_press(action)
	for i in range(frames):
		await physics_frame
	Input.action_release(action)
	await physics_frame

func _initialize() -> void:
	var world: Node = root.get_node("World")
	var combat: Node = root.get_node("Combat")
	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")
	var tilemap: TileMapLayer = overworld.get_node("TileMapLayer")
	await process_frame

	# --- 1. Screenshot near the map edge on the NE diagonal (Frostpeak<->
	# Verdantwood), to confirm the band actually reaches all the way out,
	# not just to the old SEAM_LENGTH=50 stop. ---
	var far_tile := Vector2i(world.WORLD_CENTER_X + 90, world.WORLD_CENTER_Y - 90)
	player.position = Vector2(far_tile.x * 32 + 16, far_tile.y * 32 + 16)
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	if combat.in_combat:
		combat.player_run()
		await physics_frame
	print("Mountain source present near map edge (dist 90 from center): ", tilemap.get_cell_source_id(far_tile) == world.SRC_MOUNTAIN)
	root.get_texture().get_image().save_png("res://verify_mountain_far.png")

	# --- 2. Screenshot closer in, right where the old seam used to be, for a
	# clearer "does this read as a mountain range" check. ---
	var near_tile := Vector2i(world.WORLD_CENTER_X + 30, world.WORLD_CENTER_Y - 30)
	player.position = Vector2((near_tile.x - 3) * 32 + 16, near_tile.y * 32 + 16)
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	if combat.in_combat:
		combat.player_run()
		await physics_frame
	root.get_texture().get_image().save_png("res://verify_mountain_near.png")

	# --- 3. Collision check: start solidly inside Verdantwood (dx=40,dy=-30,
	# distance-6 from the diagonal, safely outside MOUNTAIN_BAND=4), walk
	# straight toward the Frostpeak<->Verdantwood diagonal, confirm the
	# player gets blocked well before ever reaching Frostpeak. ---
	var approach_tile := Vector2i(world.WORLD_CENTER_X + 40, world.WORLD_CENTER_Y - 30)
	player.position = Vector2(approach_tile.x * 32 + 16, approach_tile.y * 32 + 16)
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	if combat.in_combat:
		combat.player_run()
		await physics_frame
	print("Starts in Zone.VERDANTWOOD: ", world.biome_at(approach_tile.x, approach_tile.y).zone == world.Zone.VERDANTWOOD)
	await _walk(player, "move_up", 80) # 80 ticks * ~2.67px/tick ~= 213px ~= 6.7 tiles - well past the band if unobstructed
	if combat.in_combat:
		combat.player_run()
		await physics_frame
	var landed_zone: int = world.biome_at(int(player.position.x / 32), int(player.position.y / 32)).zone
	print("Player blocked by the mountain, never reached Frostpeak: ", landed_zone != world.Zone.FROSTPEAK)

	quit()
