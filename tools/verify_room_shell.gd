extends SceneTree
# Painted room shell verification (Oliver's house). Run via:
# godot --script res://tools/verify_room_shell.gd (NOT --headless).
# The shell picture covers the 11x9 room exactly, sits over the tile map and
# under the props, the walls still collide, the stove no longer stands on a
# painted window, and the nap spawn tile stays free.

func _initialize() -> void:
	var h: Node2D = load("res://scenes/House.tscn").instantiate()
	root.add_child(h)
	current_scene = h
	for i in range(6):
		await process_frame
	var shell: Sprite2D = h.get_node_or_null("RoomShell")
	print("House has a RoomShell sprite covering the 11x9 room (352x288) from the origin: ", shell != null and shell.texture.get_size() == Vector2(352, 288) and not shell.centered and shell.position == Vector2.ZERO)
	print("Shell draws over the tiles and under the props/player: ", shell != null and shell.get_index() == h.get_node("TerrainLayer").get_index() + 1 and shell.get_index() < h.get_node("YSort").get_index())
	var stove: Node2D = null
	for child in h.get_node("YSort").get_children():
		if child.scene_file_path == "res://scenes/props/Stove.tscn":
			stove = child
	print("Stove stands on the painted skirting under the right window (tile 8,2), not up on the wall: ", stove != null and stove.position == Vector2(8 * 32 + 16, 2 * 32 + 16))
	var terrain: TileMapLayer = h.get_node("TerrainLayer")
	print("Tile map still carries the walls (collision) under the shell: ", terrain.get_cell_source_id(Vector2i(3, 0)) == 0 and terrain.get_cell_source_id(Vector2i(0, 4)) == 0 and terrain.get_cell_source_id(Vector2i(3, 1)) == 1 and terrain.get_cell_source_id(h.NAP_SPAWN_TILE) == 1)
	root.get_texture().get_image().save_png("res://verify_room_shell.png")
	print("Saved verify_room_shell.png")
	quit()
