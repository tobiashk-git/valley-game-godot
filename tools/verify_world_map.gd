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
# Fog of war (2026-09-12): only the ground Oliver has walked near shows on
# the Map tab (the title backdrop stays whole); a hunt quest names its lair
# as a rumoured marker with a small clearing; walking reveals; the bitmap
# survives a save round-trip and a new game clears it.
# Zoom + pan (2026-09-12, phase 2): the map opens at the closest of three
# zoom steps centred on Oliver; +/- step out and in about the centre, a
# drag pans and is clamped to the chart, a list row centres on its place.

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
	var save: Node = root.get_node("SaveSystem")
	print("Dungeon undiscovered at boot: ", not game_state.discovered_pois.dungeon)
	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var here: Vector2i = Vector2i(floori(player.position.x / 32.0), floori(player.position.y / 32.0))
	var far: Vector2i = here + Vector2i(30, 0)
	print("Fog of war: the ground around Oliver's start is revealed, 30 tiles east is not: ", game_state.is_overworld_revealed(here) and game_state.is_overworld_revealed(here + Vector2i(5, 0)) and not game_state.is_overworld_revealed(here + Vector2i(9, 0)) and not game_state.is_overworld_revealed(far))
	var fogged: Image = world_map.render_map(panel.MAP_REGION, true).get_image()
	var fp: Vector2i = far - panel.MAP_REGION.position
	var hp: Vector2i = here - panel.MAP_REGION.position
	var far_px: Color = fogged.get_pixel(fp.x, fp.y)
	print("A fogged render paints unrevealed tiles in the fog colour and revealed ones in their palette colour: ", (_close(far_px, world_map.FOG_COLOUR) or _close(far_px, world_map.FOG_COLOUR.darkened(0.06))) and not _close(fogged.get_pixel(hp.x, hp.y), world_map.FOG_COLOUR) and not _close(fogged.get_pixel(hp.x, hp.y), world_map.FOG_COLOUR.darkened(0.06)))
	print("Nothing is rumoured before a hunt is handed out: ", world_map.named_places().is_empty() and not world_map.is_shown("dungeon"))

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
	var inner_centre: Vector2 = Vector2(panel.FRAME_PAD, panel.FRAME_PAD) + panel._inner() / 2.0
	print("Opens at the closest zoom (16px per tile on PC, base 4) centred on Oliver, the chart clipped to the frame: ", panel.map_rect.texture != null and panel.base_scale == 4.0 and panel.zoom_index == 2 and panel.map_scale == 16.0 and panel.map_rect.size == Vector2(1600, 1600) and panel.map_frame.clip_contents and (panel.markers.position + panel._map_pos(here)).distance_to(inner_centre) < 1.0)
	print("Zoom buttons in the frame's corner, + disabled at the closest step: ", panel.zoom_in_btn.disabled and not panel.zoom_out_btn.disabled and panel.zoom_in_btn.get_global_rect().intersects(panel.map_frame.get_global_rect()))
	panel.zoom_out_btn.pressed.emit()
	panel.zoom_out_btn.pressed.emit()
	print("Two zoom-outs show the whole valley at 4px per tile, no pan: ", panel.zoom_index == 0 and panel.map_scale == 4.0 and panel.map_rect.size == Vector2(400, 400) and panel.pan == Vector2.ZERO and panel.zoom_out_btn.disabled)
	panel.zoom_in_btn.pressed.emit()
	print("Zooming in keeps the frame's centre tile (the chart's middle at 8px): ", panel.zoom_index == 1 and panel.map_scale == 8.0 and (panel.markers.position + panel._map_pos(panel.MAP_REGION.position + Vector2i(50, 50))).distance_to(inner_centre) < 8.0)
	var pan_before: Vector2 = panel.pan
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.relative = Vector2(-60, -30)
	panel._dragging = true
	panel._on_frame_input(drag)
	print("A drag pans the chart and the markers with it: ", panel.pan == pan_before + Vector2(-60, -30) and panel.markers.position == panel.map_rect.position)
	drag.relative = Vector2(-5000, -5000)
	panel._on_frame_input(drag)
	print("...clamped so the chart's far edge never leaves the frame: ", panel.pan == panel._inner() - panel._map_px() and panel.map_rect.position + panel.map_rect.size == Vector2(panel.FRAME_PAD, panel.FRAME_PAD) + panel._inner())
	panel._dragging = false
	panel.places_list.get_node("HouseRow").pressed.emit()
	await process_frame
	print("Picking a place from the list centres the chart on it: ", (panel.markers.position + panel._map_pos(world_map.poi_tile("house"))).distance_to(inner_centre) < 1.0 and panel.selected_poi == "house")
	panel.zoom_to(2)
	panel.select_poi("village", true) # back to the opening state for the checks below (markers rebuilt at 16px)
	await process_frame
	var names: Array = _marker_names(panel)
	print("Markers for the known places only (house, village): ", names.has("HouseMarker") and names.has("VillageMarker") and not names.has("DungeonMarker") and names.size() == 2)
	print("Subtitle counts known places and the explored share: ", panel.subtitle_label.text.begins_with("You are in the Valley  -  2 of 9 places known  -  ") and panel.subtitle_label.text.ends_with("% explored") and world_map.explored_percent(panel.MAP_REGION) > 0 and world_map.explored_percent(panel.MAP_REGION) < 10)
	# The bug that moved the map in here: from the Map tab you can switch
	# straight to Inventory (and back) without losing the tab strip.
	sheet.tabs.get_node("InventoryTab").pressed.emit()
	await process_frame
	print("Items tab from the Map tab switches (header back): ", sheet.is_open() and sheet.current_tab == "inventory" and sheet.header.visible and not panel.visible)
	sheet.tabs.get_node("MapTab").pressed.emit()
	await process_frame
	print("...and Map tab returns to the map: ", sheet.current_tab == "map" and panel.visible and not sheet.header.visible)
	var dot: Control = panel.markers.get_node("HereMarker")
	print("You-are-here dot sits on the player's tile: ", dot != null and (dot.position + Vector2(8, 8)).is_equal_approx(panel._map_pos(here)))
	var village_marker: Button = panel.markers.get_node("VillageMarker")
	print("Village marker sits on the village spawn tile: ", (village_marker.position + Vector2(14, 14)).is_equal_approx(panel._map_pos(world_map.poi_tile("village"))))
	print("Starts on the village (where the player stands), Fast Travel disabled there: ", panel.selected_poi == "village" and panel.poi_name.text == "Village" and panel.poi_where.text == "Village, Golden Plains" and panel.poi_status.text == "You are here." and panel.travel_btn.disabled)
	panel.markers.get_node("HouseMarker").pressed.emit()
	await process_frame
	print("Tapping the house marker selects it (Fast Travel stays off away from home - it only leaves from the house): ", panel.selected_poi == "house" and panel.poi_name.text == "Your House" and panel.poi_desc.text.begins_with("Home.") and panel.travel_btn.disabled and panel.poi_status.text == "From your house only." and panel.places_list.get_node("HouseRow").theme_type_variation == &"TabButtonActive")
	root.get_texture().get_image().save_png("res://verify_map_before_dungeon.png")
	print("Saved verify_map_before_dungeon.png")
	await _press("toggle_map")
	print("M again closes: ", not sheet.is_open() and not alias.is_open())

	# --- Walk to the dungeon entrance and enter through the real portal. ---
	combat._steps_since_encounter = -100000 # no random encounter mid-walk
	root.get_node("Quests").quest_state["hunt_dungeon"] = "accepted" # the dungeon gate is barred until the Elder hands this out (2026-09-08)
	var approach: Vector2i = world.place("dungeon") + Vector2i(0, 2)
	# --- The hunt names the dungeon: rumoured on the map, a clearing around it. ---
	print("The hunt names the Dungeon: rumoured (shown, not discovered), its ground revealed in a small circle only: ", world_map.is_named("dungeon") and world_map.is_shown("dungeon") and not world_map.is_discovered("dungeon") and world_map.is_tile_revealed(approach, world_map.named_places()) and not world_map.is_tile_revealed(world.place("dungeon") + Vector2i(0, 8), world_map.named_places()) and not game_state.is_overworld_revealed(approach))
	await _press("toggle_map")
	var rumour: Button = panel.markers.get_node_or_null("DungeonMarker")
	print("...a hollow marker and a '(rumoured)' row: ", rumour != null and rumour.icon == panel._rumour_tex and panel.places_list.get_node("DungeonRow").text.contains("(rumoured)"))
	rumour.pressed.emit()
	await process_frame
	print("...selected, the pane names it but offers no Fast Travel: ", panel.selected_poi == "dungeon" and panel.poi_name.text == "Dungeon" and panel.poi_status.text == "Rumoured - find it on foot." and not panel.travel_btn.visible)
	root.get_texture().get_image().save_png("res://verify_map_rumoured.png")
	print("Saved verify_map_rumoured.png")
	# --- Walking past a door marks the place found (the user met the barred dungeon and expected it on the map). ---
	game_state.reveal_overworld(world.place("dungeon"))
	game_state.reveal_overworld(world.place("golden_plains_interior"))
	panel.refresh()
	await process_frame
	print("Walking past the dungeon's door marks it found: gold marker, no '(rumoured)', still no Fast Travel until entered: ", world_map.is_seen("dungeon") and not world_map.is_discovered("dungeon") and panel.markers.get_node("DungeonMarker").icon != panel._rumour_tex and not panel.places_list.get_node("DungeonRow").text.contains("rumoured") and panel.poi_status.text == "Found - step inside to unlock Fast Travel." and not panel.travel_btn.visible)
	print("...but the barrow's spot, walked over before the barrow exists, is not: ", not world_map.is_seen("golden_plains_interior") and not world_map.is_shown("golden_plains_interior"))
	await _press("toggle_map")
	player.position = Vector2(approach.x * 32 + 16, approach.y * 32 + 16)
	var cam: Camera2D = player.get_node("Camera2D")
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	await _walk("move_up", 40)
	await _press("interact")
	print("Entered the Dungeon via the real portal: ", current_scene.name == "Dungeon")
	print("Dungeon marked discovered after entering: ", game_state.discovered_pois.dungeon)
	print("Walking up to it revealed the ground on the way: ", game_state.is_overworld_revealed(approach) and game_state.is_overworld_revealed(approach + Vector2i(0, -1)))
	var snap: Dictionary = save.snapshot()
	game_state.overworld_revealed = PackedByteArray()
	save.apply(snap)
	print("The revealed bitmap survives a save round-trip (compressed base64 in the save): ", str(snap.game_state.overworld_revealed).length() > 0 and game_state.is_overworld_revealed(approach) and game_state.is_overworld_revealed(here) and not game_state.is_overworld_revealed(far))

	# --- Inside the Dungeon the dot stands on its entrance, and the map
	# starts on the Dungeon. ---
	combat._steps_since_encounter = -100000
	await _press("toggle_map")
	print("Inside the Dungeon: dot on the dungeon entrance, Dungeon selected: ", alias.is_open() and world_map.here_tile() == world_map.poi_tile("dungeon") and panel.selected_poi == "dungeon" and _marker_names(panel).has("DungeonMarker"))
	print("Subtitle now 3 of 9, the Dungeon marker gold now: ", panel.subtitle_label.text.begins_with("You are in the Dungeon  -  3 of 9 places known") and panel.markers.get_node("DungeonMarker").icon != panel._rumour_tex and not panel.places_list.get_node("DungeonRow").text.contains("rumoured"))
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
	print("Phone: base 3px per tile (opens at 12), full-width square frame, pane below inside the window with its list: ", layout.width == 400 and sheet.narrow and panel.base_scale == 3.0 and panel.map_scale == 12.0 and panel.map_frame.size == Vector2(sheet.window.size.x - 40.0, sheet.window.size.x - 40.0) and absf(frame_rect.get_center().x - 200.0) < 2.0 and pane_rect.position.y >= frame_rect.end.y and pane_rect.end.y <= sheet.window.get_global_rect().end.y and panel.places_grid.visible and not panel.places_scroll.visible and not panel.places_title.visible and panel.places_grid.get_global_rect().end.y <= pane_rect.end.y)
	for poi_id in world_map.POI_NAMES:
		game_state.discovered_pois[poi_id] = true
	panel.refresh()
	await process_frame
	var grid_rows: Array = panel.places_grid.get_children().filter(func(c): return c.visible)
	var last_row: Control = grid_rows[-1]
	print("Phone: all nine places sit in a two-column grid inside the pane, no scrolling: ", grid_rows.size() == 9 and panel.places_grid.columns == 2 and last_row.get_global_rect().end.y <= pane_rect.end.y and last_row.get_global_rect().end.x <= pane_rect.end.x and panel.places_grid.get_node("DungeonRow").text.begins_with(" Dungeon"))
	for poi_id in world_map.POI_NAMES:
		game_state.discovered_pois[poi_id] = poi_id in ["house", "village", "dungeon"]
	panel.refresh()
	await process_frame
	panel.zoom_to(0)
	print("Phone, whole valley: the 300px chart sits centred in the wider frame: ", panel.pan == ((panel._inner() - Vector2(300, 300)) / 2.0).round() and panel.pan.x > 0.0 and panel.map_rect.size == Vector2(300, 300))
	panel.zoom_to(2)
	root.get_texture().get_image().save_png("res://verify_map_phone.png")
	print("Saved verify_map_phone.png")
	sheet.close()
	root.size = Vector2i(800, 600)
	for i in range(4):
		await process_frame
	game_state.reset()
	print("A new game clears the fog record: ", not game_state.is_overworld_revealed(here) and game_state.overworld_revealed_count(panel.MAP_REGION) == 0)
	quit()
