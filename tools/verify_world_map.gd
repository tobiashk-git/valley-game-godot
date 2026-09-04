extends SceneTree
# World Map verification (UI redesign Phase 3b: the rendered map). Run via:
# godot --script res://tools/verify_world_map.gd (NOT --headless).
#
# The map is drawn from the world builder (river ring, mountains, village,
# biome colours; an opened ford shows), discovered places get markers and
# list rows, the you-are-here dot follows the player on the Overworld and
# stands on the entrance while inside a place, entering the Dungeon through
# its real portal discovers it, Fast Travel works from the Overworld and
# from inside a house, and the phone layout stacks the pane under the map.

func _walk(direction: String, frames: int) -> void:
	Input.action_press(direction)
	for i in range(frames):
		await process_frame
	Input.action_release(direction)
	await process_frame

func _press(action: String) -> void:
	Input.action_press(action)
	await process_frame
	await process_frame
	Input.action_release(action)
	await process_frame

# Image pixels are 8-bit, so compare with a tolerance, not is_equal_approx.
func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01

func _marker_names(panel: Node) -> Array:
	var out: Array = []
	for child in panel.markers.get_children():
		if child.visible and child is Button:
			out.append(child.name)
	return out

func _initialize() -> void:
	var world: Node = root.get_node("World")
	var game_state: Node = root.get_node("GameState")
	var world_map: Node = root.get_node("WorldMap")
	var sheet: Node = root.get_node("CharacterSheet")
	var alias: Node = root.get_node("WorldMapPanel")
	var combat: Node = root.get_node("Combat")
	var layout: Node = root.get_node("Layout")

	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame
	# The Map tab's view (the old WorldMapPanel window is now an alias). Read
	# after the first frames: autoload @onready fields aren't set before.
	var panel: Node = sheet.map_view
	print("Dungeon undiscovered at boot: ", not game_state.discovered_pois.dungeon)

	# --- The rendered map itself. ---
	var tex: Texture2D = world_map.render_map(panel.MAP_REGION)
	var img: Image = tex.get_image()
	var c := Vector2i(50, 50) # the altar, at the centre of the crop
	print("Map is one pixel per tile of the 100x100 crop: ", img.get_width() == 100 and img.get_height() == 100)
	print("Altar, fence, river ring and mountains take their palette colours: ", _close(img.get_pixel(c.x, c.y), world_map.MAP_COLOURS[world.SRC_ALTAR]) and _close(img.get_pixel(c.x - 8, c.y - 3), world_map.MAP_COLOURS[world.SRC_FENCE]) and _close(img.get_pixel(c.x, c.y - 22), world_map.MAP_COLOURS[world.SRC_RIVER]) and (_close(img.get_pixel(c.x + 40, c.y - 40), world_map.MAP_COLOURS[world.SRC_MOUNTAIN]) or _close(img.get_pixel(c.x + 40, c.y - 40), world_map.MAP_COLOURS[world.SRC_MOUNTAIN].darkened(0.07))))
	var north: Color = img.get_pixel(c.x, c.y - 40)
	var east: Color = img.get_pixel(c.x + 45, c.y + 3)
	print("Frostpeak north, Verdantwood east (biome wedges coloured): ", _close(north, world_map.MAP_COLOURS[world.SRC_FROSTPEAK]) or _close(north, world_map.MAP_COLOURS[world.SRC_FROSTPEAK].darkened(0.07)), " / ", _close(east, world_map.MAP_COLOURS[world.SRC_VERDANTWOOD]) or _close(east, world_map.MAP_COLOURS[world.SRC_VERDANTWOOD].darkened(0.07)))
	game_state.biome_paths_open.frostpeak = true
	var img2: Image = world_map.render_map(panel.MAP_REGION).get_image()
	print("An opened ford shows on the map: ", _close(img2.get_pixel(c.x, c.y - 22), world_map.MAP_COLOURS[world.SRC_FORD]))
	game_state.biome_paths_open.frostpeak = false

	# --- Open with M: markers for house + village only, you-are-here dot. ---
	await _press("toggle_map")
	print("M opens the sheet on its Map tab (the alias autoload agrees): ", sheet.is_open() and sheet.current_tab == "map" and panel.visible and alias.is_open())
	print("Header hidden on the Map tab so the map gets the height; tab strip still there: ", not sheet.header.visible and sheet.tabs.visible and sheet.tabs.get_node("InventoryTab").visible)
	print("Map texture drawn at 4px per tile: ", panel.map_rect.texture != null and panel.map_rect.size == Vector2(400, 400) and panel.map_scale == 4.0)
	var names: Array = _marker_names(panel)
	print("Markers for the known places only (house, village): ", names.has("HouseMarker") and names.has("VillageMarker") and not names.has("DungeonMarker") and names.size() == 2)
	print("Subtitle counts known places: ", panel.subtitle_label.text == "You are in the Valley  -  2 of 9 places known")
	# The bug that moved the map in here: from the Map tab you can switch
	# straight to Inventory (and back) without losing the tab strip.
	sheet.tabs.get_node("InventoryTab").pressed.emit()
	await process_frame
	print("Items tab from the Map tab switches (header back): ", sheet.is_open() and sheet.current_tab == "inventory" and sheet.header.visible and not panel.visible)
	sheet.tabs.get_node("MapTab").pressed.emit()
	await process_frame
	print("...and Map tab returns to the map: ", sheet.current_tab == "map" and panel.visible and not sheet.header.visible)
	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var here: Vector2i = Vector2i(floori(player.position.x / 32.0), floori(player.position.y / 32.0))
	var dot: Control = panel.markers.get_node("HereMarker")
	print("You-are-here dot sits on the player's tile: ", dot != null and (dot.position + Vector2(8, 8)).is_equal_approx(panel._map_pos(here)))
	var village_marker: Button = panel.markers.get_node("VillageMarker")
	print("Village marker sits on the village spawn tile: ", (village_marker.position + Vector2(14, 14)).is_equal_approx(panel._map_pos(world_map.poi_tile("village"))))
	print("Starts on the village (where the player stands), Fast Travel disabled there: ", panel.selected_poi == "village" and panel.poi_name.text == "Village" and panel.poi_where.text == "Village, Golden Plains" and panel.poi_status.text == "You are here." and panel.travel_btn.disabled)
	panel.markers.get_node("HouseMarker").pressed.emit()
	await process_frame
	print("Tapping the house marker selects it: ", panel.selected_poi == "house" and panel.poi_name.text == "Your House" and panel.poi_desc.text.begins_with("Home.") and not panel.travel_btn.disabled and panel.places_list.get_node("HouseRow").theme_type_variation == &"TabButtonActive")
	root.get_texture().get_image().save_png("res://verify_map_before_dungeon.png")
	print("Saved verify_map_before_dungeon.png")
	await _press("toggle_map")
	print("M again closes: ", not sheet.is_open() and not alias.is_open())

	# --- Walk to the dungeon entrance and enter through the real portal. ---
	combat._steps_since_encounter = -100000 # no random encounter mid-walk
	var approach: Vector2i = world.DUNGEON_ENTRANCE + Vector2i(0, 2)
	player.position = Vector2(approach.x * 32 + 16, approach.y * 32 + 16)
	var cam: Camera2D = player.get_node("Camera2D")
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	await _walk("move_up", 40)
	await _press("interact")
	print("Entered the Dungeon via the real portal: ", current_scene.name == "Dungeon")
	print("Dungeon marked discovered after entering: ", game_state.discovered_pois.dungeon)

	# --- Inside the Dungeon the dot stands on its entrance, and the map
	# starts on the Dungeon. ---
	combat._steps_since_encounter = -100000
	await _press("toggle_map")
	print("Inside the Dungeon: dot on the dungeon entrance, Dungeon selected: ", alias.is_open() and world_map.here_tile() == world_map.poi_tile("dungeon") and panel.selected_poi == "dungeon" and _marker_names(panel).has("DungeonMarker"))
	print("Subtitle now 3 of 9: ", panel.subtitle_label.text == "You are in the Dungeon  -  3 of 9 places known")
	root.get_texture().get_image().save_png("res://verify_map_after_dungeon.png")
	print("Saved verify_map_after_dungeon.png")

	# --- Fast travel to the House from inside the Dungeon. ---
	panel.places_list.get_node("HouseRow").pressed.emit()
	await process_frame
	panel.travel_btn.pressed.emit()
	await process_frame
	await process_frame
	print("Fast travel closes the sheet and lands on the Overworld: ", not sheet.is_open() and current_scene.name == "Overworld")
	var house_tile := Vector2i(int(current_scene.get_node("YSort/Player").position.x / 32), int(current_scene.get_node("YSort/Player").position.y / 32))
	print("Landed at the House entrance: ", house_tile == world.HOUSE_ENTRANCE + Vector2i(0, 1))

	# --- Fast travel from inside an interior (Elder House) to the Village. ---
	change_scene_to_packed(load("res://scenes/ElderHouse.tscn"))
	await process_frame
	await process_frame
	print("Now inside the Elder's House: ", current_scene.name == "ElderHouse")
	await _press("toggle_map")
	print("Map from a house: dot on the village, subtitle names the house: ", world_map.here_tile() == world_map.poi_tile("village") and panel.subtitle_label.text.begins_with("You are in the Elder's House"))
	panel.markers.get_node("VillageMarker").pressed.emit()
	await process_frame
	panel.travel_btn.pressed.emit()
	await process_frame
	await process_frame
	print("Fast travel from an interior lands on Overworld: ", current_scene.name == "Overworld")
	var village_tile := Vector2i(int(current_scene.get_node("YSort/Player").position.x / 32), int(current_scene.get_node("YSort/Player").position.y / 32))
	print("Landed at the village spawn point: ", village_tile == world.VILLAGE_GATES.south + Vector2i(0, -2))

	# --- Phone layout: map at an integer scale centred, pane below it. ---
	root.size = Vector2i(400, 860)
	for i in range(6):
		await process_frame
	sheet.open("map")
	await process_frame
	await process_frame
	var frame_rect: Rect2 = panel.map_frame.get_global_rect()
	var pane_rect: Rect2 = panel.detail_pane.get_global_rect()
	print("Phone: map at 3px per tile, centred, pane below inside the window: ", layout.width == 400 and sheet.narrow and panel.map_scale == 3.0 and panel.map_rect.size == Vector2(300, 300) and absf(frame_rect.get_center().x - 200.0) < 2.0 and pane_rect.position.y >= frame_rect.end.y and pane_rect.end.y <= sheet.window.get_global_rect().end.y)
	root.get_texture().get_image().save_png("res://verify_map_phone.png")
	print("Saved verify_map_phone.png")
	sheet.close()
	root.size = Vector2i(800, 600)
	for i in range(4):
		await process_frame
	quit()
