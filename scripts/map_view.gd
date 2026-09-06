extends Control
# The character sheet's Map tab (UI redesign Phase 3b, moved INTO the sheet
# after the user found the standalone map window lost the tab strip - "you
# can't switch back to inventory"). A rendered chart of the valley:
# WorldMap.render_map() draws the central MAP_REGION of the Overworld one
# pixel per tile from the world builder itself (biome wedges, river ring
# with whichever fords are open, mountain ranges, the village's fence,
# paths and altar); discovered places get a gold marker button on it, the
# player a red you-are-here dot; the pane on the right (below, on a phone)
# describes the selected place with a Fast Travel button and lists every
# known place as a button too. Undiscovered places are simply absent - the
# subtitle's "N of 9 places known" is the nudge to go and look.
#
# Skeleton from tools/setup_character_sheet.gd; character_sheet.gd calls
# apply_layout() and refresh() and owns open/close/tab switching.

# The 100x100 tiles around the village at 4px each: every place sits within
# ~30 tiles of the centre, so the full 200x200 world would be mostly empty
# outer biome; this crop still shows the river ring, all four wedges and
# the mountain ranges between them.
const MAP_REGION := Rect2i(World.WORLD_CENTER_X - 50, World.WORLD_CENTER_Y - 50, 100, 100)
const MARKER_SIZE := 28.0

@onready var subtitle_label: Label = $SubtitleLabel
@onready var map_frame: Panel = $MapFrame
@onready var map_rect: TextureRect = $MapFrame/MapRect
@onready var markers: Control = $MapFrame/Markers
@onready var detail_pane: Panel = $DetailPane
@onready var poi_name: Label = $DetailPane/PoiName
@onready var poi_where: Label = $DetailPane/PoiWhere
@onready var poi_desc: Label = $DetailPane/PoiDesc
@onready var poi_status: Label = $DetailPane/PoiStatus
@onready var travel_btn: Button = $DetailPane/TravelBtn
@onready var places_title: Label = $DetailPane/PlacesTitle
@onready var places_scroll: ScrollContainer = $DetailPane/PlacesScroll
@onready var places_list: VBoxContainer = $DetailPane/PlacesScroll/PlacesList
@onready var hint_label: Label = $HintLabel

var selected_poi := ""
var map_scale := 4.0
var _marker_tex: Texture2D
var _marker_selected_tex: Texture2D
var _here_tex: Texture2D

func _ready() -> void:
	travel_btn.pressed.connect(_on_travel_pressed)
	_marker_tex = _circle_texture(10, Color(0.95, 0.78, 0.35), Color(0.25, 0.15, 0.05))
	_marker_selected_tex = _circle_texture(13, Color(1.0, 0.9, 0.55), Color(1, 1, 1))
	_here_tex = _circle_texture(8, Color(0.9, 0.2, 0.2), Color(1, 1, 1))

# A filled disc with a 2px outline, generated once (no art file needed).
func _circle_texture(radius: int, fill: Color, outline: Color) -> ImageTexture:
	var size: int = radius * 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var centre := Vector2(radius, radius)
	for y in range(size):
		for x in range(size):
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(centre)
			if d <= radius - 2.0:
				img.set_pixel(x, y, fill)
			elif d <= radius:
				img.set_pixel(x, y, outline)
	return ImageTexture.create_from_image(img)

# --- layout (called by the sheet with the view's rect; the sheet hides its
# header on this tab so the 408px map frame has the height it needs) ---

func _place(c: Control, pos: Vector2, size: Vector2) -> void:
	c.position = pos
	c.size = size

func apply_layout(narrow: bool, view_size: Vector2) -> void:
	var pane_h: float
	if not narrow:
		map_scale = 4.0
		_place(subtitle_label, Vector2(20, 0), Vector2(680, 18))
		subtitle_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_place(map_frame, Vector2(20, 22), Vector2(408, 408))
		pane_h = 408.0
		_place(detail_pane, Vector2(452, 22), Vector2(248, pane_h))
		hint_label.position = Vector2(20, 436)
		hint_label.visible = true
	else:
		var iw: float = view_size.x
		_place(subtitle_label, Vector2(20, 0), Vector2(iw - 40.0, 36))
		subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		# Integer scale keeps the one-pixel-per-tile map crisp under NEAREST;
		# on a short viewport (a phone browser's toolbars) drop a step so the
		# pane below still has its 200px.
		map_scale = maxf(1.0, floorf((iw - 48.0) / MAP_REGION.size.x))
		var room: float = view_size.y - 40.0 - 24.0 - 200.0
		while map_scale > 1.0 and map_scale * MAP_REGION.size.x > room:
			map_scale -= 1.0
		var map_px: float = map_scale * MAP_REGION.size.x
		_place(map_frame, Vector2(floorf((iw - map_px - 8.0) / 2.0), 40), Vector2(map_px + 8.0, map_px + 8.0))
		var pane_y: float = 40.0 + map_px + 8.0 + 8.0
		pane_h = maxf(200.0, view_size.y - pane_y - 4.0)
		_place(detail_pane, Vector2(20, pane_y), Vector2(iw - 40.0, pane_h))
		hint_label.visible = false
	var map_px2: float = map_scale * MAP_REGION.size.x
	_place(map_rect, Vector2(4, 4), Vector2(map_px2, map_px2))
	_place(markers, Vector2(4, 4), Vector2(map_px2, map_px2))
	var pw: float = detail_pane.size.x
	_place(poi_name, Vector2(12, 10), Vector2(pw - 24.0, 44))
	poi_where.position = Vector2(12, 56)
	_place(poi_desc, Vector2(12, 76), Vector2(pw - 24.0, 62))
	poi_status.position = Vector2(12, 140)
	_place(travel_btn, Vector2(12, 164), Vector2(pw - 24.0, 40))
	places_title.position = Vector2(12, 216)
	_place(places_scroll, Vector2(12, 238), Vector2(pw - 24.0, maxf(40.0, pane_h - 238.0 - 12.0)))

# --- selection ---

# Start on the place the player is at (if known), else the village.
func select_default() -> void:
	var here: Vector2i = WorldMap.here_tile()
	selected_poi = ""
	for poi_id in WorldMap.POI_NAMES:
		if WorldMap.is_discovered(poi_id) and WorldMap.poi_tile(poi_id) == here:
			selected_poi = poi_id
	var current: Node = get_tree().current_scene
	if selected_poi == "" and current != null and WorldMap.SCENE_POIS.has(current.name) and WorldMap.is_discovered(WorldMap.SCENE_POIS[current.name]):
		selected_poi = WorldMap.SCENE_POIS[current.name]
	if selected_poi == "":
		selected_poi = "village"

func select_poi(poi_id: String) -> void:
	selected_poi = poi_id
	refresh()

# --- refresh ---

func _map_pos(tile: Vector2i) -> Vector2:
	return (Vector2(tile - MAP_REGION.position) + Vector2(0.5, 0.5)) * map_scale

func _clear(container: Node) -> void:
	for child in container.get_children():
		child.name = "Dying" + str(child.get_index())
		child.visible = false
		child.queue_free()

func refresh() -> void:
	if not visible:
		return
	map_rect.texture = WorldMap.render_map(MAP_REGION)
	var known: int = WorldMap.discovered_count()
	var here: Vector2i = WorldMap.here_tile()
	var location: String = WorldMap.current_location_name()
	if here == Vector2i(-1, -1):
		subtitle_label.text = "You are in %s - this map shows the Valley  -  %d of %d places known" % [location, known, WorldMap.POI_NAMES.size()]
	else:
		subtitle_label.text = "You are in %s  -  %d of %d places known" % [location, known, WorldMap.POI_NAMES.size()]

	# Markers: one button per discovered place, then the you-are-here dot on
	# top (it's not a button; the place under it is still tappable).
	_clear(markers)
	_clear(places_list)
	for poi_id in WorldMap.POI_NAMES:
		if not WorldMap.is_discovered(poi_id):
			continue
		var selected: bool = poi_id == selected_poi
		var btn := Button.new()
		btn.name = poi_id.to_pascal_case() + "Marker"
		btn.flat = true
		btn.icon = _marker_selected_tex if selected else _marker_tex
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.tooltip_text = WorldMap.POI_NAMES[poi_id]
		for state in ["normal", "hover", "pressed", "focus"]:
			btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		btn.size = Vector2(MARKER_SIZE, MARKER_SIZE)
		btn.position = _map_pos(WorldMap.poi_tile(poi_id)) - Vector2(MARKER_SIZE, MARKER_SIZE) / 2.0
		btn.pressed.connect(select_poi.bind(poi_id))
		markers.add_child(btn)
		var row := Button.new()
		row.name = poi_id.to_pascal_case() + "Row"
		row.text = "  " + WorldMap.POI_NAMES[poi_id]
		row.theme_type_variation = &"TabButtonActive" if selected else &"TabButton"
		row.add_theme_font_size_override("font_size", 12)
		row.custom_minimum_size = Vector2(places_scroll.size.x, 28)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.pressed.connect(select_poi.bind(poi_id))
		places_list.add_child(row)
	if here != Vector2i(-1, -1):
		var dot := TextureRect.new()
		dot.name = "HereMarker"
		dot.texture = _here_tex
		dot.size = Vector2(16, 16)
		dot.position = _map_pos(here) - Vector2(8, 8)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.tooltip_text = "You are here"
		markers.add_child(dot)

	# Detail pane.
	if selected_poi == "" or not WorldMap.is_discovered(selected_poi):
		poi_name.text = "Nowhere selected"
		poi_where.text = ""
		poi_desc.text = ""
		poi_status.text = ""
		travel_btn.visible = false
		return
	poi_name.text = WorldMap.POI_NAMES[selected_poi]
	poi_where.text = WorldMap.poi_where(selected_poi)
	poi_desc.text = WorldMap.POI_DESCRIPTIONS.get(selected_poi, "")
	var at_it: bool = here == WorldMap.poi_tile(selected_poi)
	# Fast travel only LEAVES from home (Oliver's house): the way back from a
	# run is on foot, by Angel Feather, or a nap that costs the pack.
	var from_home: bool = GameState.is_home()
	if at_it:
		poi_status.text = "You are here."
	elif from_home:
		poi_status.text = "Fast Travel lands at its entrance."
	else:
		poi_status.text = "From your house only." # walk back, or use an Angel Feather
	travel_btn.visible = true
	travel_btn.disabled = at_it or not from_home

func _on_travel_pressed() -> void:
	if selected_poi != "":
		var poi_id := selected_poi
		CharacterSheet.close()
		WorldMap.travel_to(poi_id)
