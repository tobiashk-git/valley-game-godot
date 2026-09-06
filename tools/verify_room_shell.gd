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
	var bed: Node2D = null
	for child in h.get_node("YSort").get_children():
		if child.scene_file_path == "res://scenes/props/Bed.tscn":
			bed = child
	print("Stove and bed stand on the floor rows below the painted wall (stove centred on the back wall at 5,3; bed 2,5 with its head at the wall base): ", stove != null and stove.position == Vector2(5 * 32 + 16, 3 * 32 + 16) and bed != null and bed.position == Vector2(2 * 32 + 16, 5 * 32 + 16))
	var bed_sprite: Sprite2D = bed.get_node("Sprite2D")
	var bed_top: float = bed.position.y + bed_sprite.offset.y - bed_sprite.texture.get_height() / 2.0
	print("The new bed is the keyed Leonardo piece, 64 wide, its head within a tile-third of the wall base (y=96): ", bed_sprite.texture.get_width() == 64 and absf(bed_top - 96.0) <= 12.0, " top=", bed_top)
	var terrain: TileMapLayer = h.get_node("TerrainLayer")
	print("The whole painted wall band (rows 0-2) is solid, floor from row 3, nap tile free: ", terrain.get_cell_source_id(Vector2i(3, 0)) == 0 and terrain.get_cell_source_id(Vector2i(5, 1)) == 0 and terrain.get_cell_source_id(Vector2i(7, 2)) == 0 and terrain.get_cell_source_id(Vector2i(0, 4)) == 0 and terrain.get_cell_source_id(Vector2i(3, 3)) == 1 and terrain.get_cell_source_id(h.NAP_SPAWN_TILE) == 1 and h.WALL_ROWS == 3)
	# Walk north from the nap tile: the wall base stops Oliver at the top of row 3.
	var player: CharacterBody2D = h.get_node("YSort/Player")
	player.position = Vector2(4 * 32 + 16, h.NAP_SPAWN_TILE.y * 32 + 16) # column 4: no prop between here and the wall
	Input.action_press("move_up")
	for i in range(90):
		await physics_frame
	Input.action_release("move_up")
	print("Oliver cannot walk up onto the painted wall (stops in row 3): ", player.position.y >= 3 * 32 and player.position.y < 4 * 32 + 8, " y=", player.position.y)
	var front: Node2D = null
	var back: Node2D = null
	for child in h.get_node("YSort").get_children():
		if child.scene_file_path == "res://scenes/props/Chair.tscn":
			front = child
		elif child.scene_file_path == "res://scenes/props/ChairBack.tscn":
			back = child
	print("Both chairs face the table: front view above it (8,4), back view below it (8,6): ", front != null and front.position == Vector2(8 * 32 + 16, 4 * 32 + 16) and back != null and back.position == Vector2(8 * 32 + 16, 6 * 32 + 16) and back.get_node("Sprite2D").texture.resource_path.ends_with("chair_back.png"))
	root.get_texture().get_image().save_png("res://verify_room_shell.png")
	print("Saved verify_room_shell.png")
	await _verify_elder()
	await _verify_trader()
	await _verify_smithy()
	quit()

# --- Elder's house: the 9x7 village room with its own shell (2-row wall). ---
func _verify_elder() -> void:
	change_scene_to_packed(load("res://scenes/ElderHouse.tscn"))
	for i in range(8):
		await process_frame
	var e: Node2D = current_scene
	var shell: Sprite2D = e.get_node_or_null("RoomShell")
	var terrain: TileMapLayer = e.get_node("TerrainLayer")
	print("Elder's house has its own shell covering the 9x7 room (288x224), over the tiles, under the props: ", shell != null and shell.texture.get_size() == Vector2(288, 224) and shell.get_index() == terrain.get_index() + 1 and shell.get_index() < e.get_node("YSort").get_index())
	print("Its two painted wall rows are solid, floor from row 2: ", e.wall_rows == 2 and terrain.get_cell_source_id(Vector2i(4, 1)) == 0 and terrain.get_cell_source_id(Vector2i(4, 2)) == 1)
	var bed: Node2D = null
	for child in e.get_node("YSort").get_children():
		if child.scene_file_path == "res://scenes/props/Bed.tscn":
			bed = child
	print("Elder's bed stands with its head at the wall base (2,4): ", bed != null and bed.position == Vector2(2 * 32 + 16, 4 * 32 + 16))
	root.get_texture().get_image().save_png("res://verify_room_shell_elder.png")
	print("Saved verify_room_shell_elder.png")

# --- Trader's house: three-row wall (the painted shelves), NPC on the first floor row. ---
func _verify_trader() -> void:
	change_scene_to_packed(load("res://scenes/TraderHouse.tscn"))
	for i in range(8):
		await process_frame
	var t: Node2D = current_scene
	var shell: Sprite2D = t.get_node_or_null("RoomShell")
	var terrain: TileMapLayer = t.get_node("TerrainLayer")
	print("Trader's house has its shell (288x224) and a three-row solid wall band: ", shell != null and shell.texture.get_size() == Vector2(288, 224) and t.wall_rows == 3 and terrain.get_cell_source_id(Vector2i(4, 2)) == 0 and terrain.get_cell_source_id(Vector2i(4, 3)) == 1)
	var npc: Node2D = null
	var table: Node2D = null
	for child in t.get_node("YSort").get_children():
		if child.scene_file_path == "res://scenes/props/NPC.tscn":
			npc = child
		elif child.scene_file_path == "res://scenes/props/Table.tscn":
			table = child
	print("Trader stands on the first floor row (4,3), the table beside it (2,3): ", npc != null and npc.position == Vector2(4 * 32 + 16, 3 * 32 + 16) and table != null and table.position == Vector2(2 * 32 + 16, 3 * 32 + 16))
	root.get_texture().get_image().save_png("res://verify_room_shell_trader.png")
	print("Saved verify_room_shell_trader.png")

# --- Smithy: three-row stone wall, forge and workbench on the floor rows. ---
func _verify_smithy() -> void:
	change_scene_to_packed(load("res://scenes/BlacksmithHouse.tscn"))
	for i in range(8):
		await process_frame
	var b: Node2D = current_scene
	var shell: Sprite2D = b.get_node_or_null("RoomShell")
	var terrain: TileMapLayer = b.get_node("TerrainLayer")
	print("Smithy has its shell (288x224) and a three-row solid wall band: ", shell != null and shell.texture.get_size() == Vector2(288, 224) and b.wall_rows == 3 and terrain.get_cell_source_id(Vector2i(4, 2)) == 0 and terrain.get_cell_source_id(Vector2i(4, 3)) == 1)
	var forge: Node2D = null
	var bench: Node2D = null
	for child in b.get_node("YSort").get_children():
		if child.scene_file_path == "res://scenes/props/Forge.tscn":
			forge = child
		elif child.scene_file_path == "res://scenes/props/Workbench.tscn":
			bench = child
	print("Forge (6,3) and workbench (2,3) stand on the first floor row: ", forge != null and forge.position == Vector2(6 * 32 + 16, 3 * 32 + 16) and bench != null and bench.position == Vector2(2 * 32 + 16, 3 * 32 + 16))
	root.get_texture().get_image().save_png("res://verify_room_shell_smithy.png")
	print("Saved verify_room_shell_smithy.png")
