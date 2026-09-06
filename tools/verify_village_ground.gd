extends SceneTree
# Painted village ground. Run via:
# godot --script res://tools/verify_village_ground.gd (NOT --headless).
# One picture (plaza, paths, grass) covers the 15x11-tile interior inside
# the fence ring, drawn over the tile map and under the props; the altar
# is redrawn above it and its trigger still sits on the altar tile.

func _initialize() -> void:
	var world: Node = root.get_node("World")
	var ow: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(ow)
	current_scene = ow
	for i in range(4):
		await process_frame
	var ground: Sprite2D = ow.get_node_or_null("VillageGround")
	var tilemap: TileMapLayer = ow.get_node("TileMapLayer")
	print("VillageGround covers the interior (480x352 from the tile inside the fence corner), over the tiles, under the YSort: ", ground != null and ground.texture.get_size() == Vector2(480, 352) and ground.position == Vector2((world.VILLAGE_BOUNDS.x0 + 1) * 32, (world.VILLAGE_BOUNDS.y0 + 1) * 32) and ground.get_index() == tilemap.get_index() + 1 and ground.get_index() < ow.get_node("YSort").get_index())
	var altar: Sprite2D = ow.get_node_or_null("AltarSprite")
	print("The altar is redrawn above the plate, standing on its tile: ", altar != null and altar.get_index() == ground.get_index() + 1 and absf(altar.position.x - (world.ALTAR_POS.x * 32 + 16)) < 1.0 and altar.position.y + altar.texture.get_height() / 2.0 == world.ALTAR_POS.y * 32 + 32)
	print("Fence ring and gates still come from the tile map around the plate: ", tilemap.get_cell_source_id(Vector2i(world.VILLAGE_BOUNDS.x0, world.VILLAGE_BOUNDS.y0)) == world.SRC_FENCE and tilemap.get_cell_source_id(world.ALTAR_POS) == world.SRC_ALTAR)
	var left := Vector2i(world.VILLAGE_BOUNDS.x0, world.WORLD_CENTER_Y - 2)
	var right := Vector2i(world.VILLAGE_BOUNDS.x1, world.WORLD_CENTER_Y - 2)
	var top := Vector2i(world.WORLD_CENTER_X - 2, world.VILLAGE_BOUNDS.y0)
	print("Side walls are the wall tile turned a quarter (left CW, right CCW); the top run and corners are unrotated: ", tilemap.get_cell_alternative_tile(left) == world.WALL_ROTATE_CW and tilemap.get_cell_alternative_tile(right) == world.WALL_ROTATE_CCW and tilemap.get_cell_alternative_tile(top) == 0 and tilemap.get_cell_alternative_tile(Vector2i(world.VILLAGE_BOUNDS.x0, world.VILLAGE_BOUNDS.y0)) == 0)
	var player: CharacterBody2D = ow.get_node("YSort/Player")
	player.position = Vector2(world.WORLD_CENTER_X * 32 + 16, world.WORLD_CENTER_Y * 32 + 16)
	var cam: Camera2D = player.get_node("Camera2D")
	cam.zoom = Vector2(0.9, 0.9)
	cam.reset_smoothing()
	for i in range(4):
		await process_frame
	root.get_texture().get_image().save_png("res://verify_village_overview.png")
	print("Saved verify_village_overview.png")
	quit()
