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
# Fog of war (2026-09-12): the chart shows only the ground Oliver has
# walked near (WorldMap.render_map(..., true)); a lair a hunt quest has
# named shows as a small clearing with a hollow "rumoured" marker (no fast
# travel) until its portal is walked through. The subtitle adds "% explored".
#
# Zoom + pan (2026-09-12, phase 2 - user: "the initial zoom could be much
# more zoomed in to the village"): the frame is a clipped window onto the
# chart at base_scale x ZOOM_STEPS[zoom_index] px per tile. It opens at the
# closest step centred on Oliver; drag (touch or mouse) pans, the +/-
# buttons and the mouse wheel zoom about the frame's centre / the cursor,
# and picking a place from the list centres on it. Markers live in a layer
# that moves with the chart, so _map_pos() stays "tile -> layer pixels".
#
# Skeleton from tools/setup_character_sheet.gd; character_sheet.gd calls
# apply_layout() and refresh() and owns open/close/tab switching.

# The 100x100 tiles around the village at 4px each: every place sits within
# ~30 tiles of the centre, so the full 200x200 world would be mostly empty
# outer biome; this crop still shows the river ring, all four wedges and
# the mountain ranges between them.
const MAP_REGION := Rect2i(World.WORLD_CENTER_X - 50, World.WORLD_CENTER_Y - 50, 100, 100)
const MARKER_SIZE := 28.0
# Whole valley / a biome / the local ground, as multiples of the base scale
# (4 px per tile on PC, 3 on a phone) - so 4/8/16 or 3/6/12 px per tile.
const ZOOM_STEPS := [1.0, 2.0, 4.0]
const DEFAULT_ZOOM := 2
const ZOOM_BTN := 34.0
const FRAME_PAD := 4.0
# Phone (2026-09-12, user: "the locations panel doesn't fit on the bottom
# of the screen", then "the scroll between locations is not good - a
# little grey bar"): the pane keeps at least PANE_MIN_NARROW - its compact
# rows plus a two-column GRID of all nine places (no scrolling at all); the
# map frame, a clipped window now, takes whatever height is left, full
# width, never taller than it is wide.
const PANE_MIN_NARROW := 316.0
const FRAME_MIN_NARROW := 150.0
const GRID_ROW_H := 24.0

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
var base_scale := 4.0
var zoom_index := DEFAULT_ZOOM
var map_scale := 16.0 # base_scale * ZOOM_STEPS[zoom_index]
var pan := Vector2.ZERO # the chart's top-left inside the frame's inner area (<= 0)
var zoom_in_btn: Button
var zoom_out_btn: Button
var places_grid: GridContainer # the phone's place buttons (two columns, no scroll)
var _narrow := false
var _marker_tex: Texture2D
var _marker_selected_tex: Texture2D
var _here_tex: Texture2D
var _rumour_tex: Texture2D
var _dragging := false
var _centre_on_open := true

func _ready() -> void:
	travel_btn.pressed.connect(_on_travel_pressed)
	_marker_tex = _circle_texture(10, Color(0.95, 0.78, 0.35), Color(0.25, 0.15, 0.05))
	_marker_selected_tex = _circle_texture(13, Color(1.0, 0.9, 0.55), Color(1, 1, 1))
	_here_tex = _circle_texture(8, Color(0.9, 0.2, 0.2), Color(1, 1, 1))
	_rumour_tex = _circle_texture(10, Color(0.95, 0.78, 0.35, 0.22), Color(0.95, 0.78, 0.35))
	map_frame.clip_contents = true
	map_frame.gui_input.connect(_on_frame_input)
	zoom_in_btn = _zoom_button("ZoomIn", "+")
	zoom_out_btn = _zoom_button("ZoomOut", "-")
	zoom_in_btn.pressed.connect(func() -> void: zoom_to(zoom_index + 1))
	zoom_out_btn.pressed.connect(func() -> void: zoom_to(zoom_index - 1))
	places_grid = GridContainer.new()
	places_grid.name = "PlacesGrid"
	places_grid.columns = 2
	places_grid.add_theme_constant_override("h_separation", 4)
	places_grid.add_theme_constant_override("v_separation", 4)
	places_grid.visible = false
	detail_pane.add_child(places_grid)
	hint_label.text = "Drag to look around, + / - to zoom. Tap a marker or a name to see the place. Fast Travel lands you at its entrance."

func _zoom_button(node_name: String, label: String) -> Button:
	var btn := Button.new()
	btn.name = node_name
	btn.text = label
	btn.size = Vector2(ZOOM_BTN, ZOOM_BTN)
	btn.add_theme_font_size_override("font_size", 20)
	btn.tooltip_text = "Zoom in" if label == "+" else "Zoom out"
	map_frame.add_child(btn)
	return btn

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
		base_scale = 4.0
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
		# Integer scale keeps the one-pixel-per-tile chart crisp under NEAREST
		# (3px on a 400-wide phone: 3/6/12 through the zoom steps).
		base_scale = maxf(1.0, floorf((iw - 48.0) / MAP_REGION.size.x))
		var frame_w: float = iw - 40.0
		var frame_h: float = clampf(view_size.y - 40.0 - 16.0 - PANE_MIN_NARROW - 4.0, FRAME_MIN_NARROW, frame_w)
		_place(map_frame, Vector2(20, 40), Vector2(frame_w, frame_h))
		var pane_y: float = 40.0 + frame_h + 8.0 + 8.0
		pane_h = maxf(PANE_MIN_NARROW, view_size.y - pane_y - 4.0)
		_place(detail_pane, Vector2(20, pane_y), Vector2(iw - 40.0, pane_h))
		hint_label.visible = false
	var inner: float = map_frame.size.x - 2.0 * FRAME_PAD
	zoom_in_btn.position = Vector2(FRAME_PAD + inner - ZOOM_BTN - 4.0, FRAME_PAD + 4.0)
	zoom_out_btn.position = Vector2(FRAME_PAD + inner - ZOOM_BTN - 4.0, FRAME_PAD + 4.0 + ZOOM_BTN + 4.0)
	_centre_on_open = true
	_apply_view()
	var pw: float = detail_pane.size.x
	_narrow = narrow
	places_title.visible = not narrow
	places_scroll.visible = not narrow
	places_grid.visible = narrow
	if not narrow:
		_place(poi_name, Vector2(12, 10), Vector2(pw - 24.0, 44))
		poi_where.position = Vector2(12, 56)
		_place(poi_desc, Vector2(12, 76), Vector2(pw - 24.0, 62))
		poi_status.position = Vector2(12, 140)
		_place(travel_btn, Vector2(12, 164), Vector2(pw - 24.0, 40))
		places_title.position = Vector2(12, 216)
		_place(places_scroll, Vector2(12, 238), Vector2(pw - 24.0, maxf(40.0, pane_h - 238.0 - 12.0)))
	else:
		# Compact rows: one-line name, three lines of description, a 36px
		# button, then the two-column grid of places from y=174 (five grid
		# rows of 24px hold all nine places inside PANE_MIN_NARROW).
		_place(poi_name, Vector2(12, 8), Vector2(pw - 24.0, 24))
		poi_where.position = Vector2(12, 34)
		_place(poi_desc, Vector2(12, 54), Vector2(pw - 24.0, 52))
		poi_status.position = Vector2(12, 108)
		_place(travel_btn, Vector2(12, 130), Vector2(pw - 24.0, 36))
		_place(places_grid, Vector2(12, 174), Vector2(pw - 24.0, pane_h - 174.0 - 6.0))

# --- zoom + pan ---

# The frame's inner (chart-showing) size in pixels.
func _inner() -> Vector2:
	return map_frame.size - Vector2(2.0 * FRAME_PAD, 2.0 * FRAME_PAD)

func _map_px() -> Vector2:
	return Vector2(MAP_REGION.size) * map_scale

# Keep the chart covering the frame: pan is never positive, never so
# negative that the chart's far edge comes inside the frame - and when the
# chart is smaller than the frame in an axis (whole valley in a wide phone
# frame) it sits centred there instead.
func _clamp_pan() -> void:
	var lo: Vector2 = _inner() - _map_px()
	pan.x = lo.x / 2.0 if lo.x > 0.0 else clampf(pan.x, lo.x, 0.0)
	pan.y = lo.y / 2.0 if lo.y > 0.0 else clampf(pan.y, lo.y, 0.0)
	pan = pan.round()

func _apply_view() -> void:
	map_scale = base_scale * ZOOM_STEPS[zoom_index]
	_clamp_pan()
	_place(map_rect, Vector2(FRAME_PAD, FRAME_PAD) + pan, _map_px())
	_place(markers, Vector2(FRAME_PAD, FRAME_PAD) + pan, _map_px())
	zoom_in_btn.disabled = zoom_index >= ZOOM_STEPS.size() - 1
	zoom_out_btn.disabled = zoom_index <= 0

# Put a tile at the middle of the frame (used on open and from the list).
func centre_on(tile: Vector2i) -> void:
	map_scale = base_scale * ZOOM_STEPS[zoom_index]
	pan = _inner() / 2.0 - (Vector2(tile - MAP_REGION.position) + Vector2(0.5, 0.5)) * map_scale
	_apply_view()

# Change the zoom step keeping the chart point under `anchor` (inner-frame
# pixels; the centre when omitted) where it is.
func zoom_to(index: int, anchor: Vector2 = Vector2(-1, -1)) -> void:
	index = clampi(index, 0, ZOOM_STEPS.size() - 1)
	if index == zoom_index:
		return
	if anchor.x < 0.0:
		anchor = _inner() / 2.0
	var old_scale: float = map_scale
	var chart_point: Vector2 = (anchor - pan) / old_scale # in tiles
	zoom_index = index
	map_scale = base_scale * ZOOM_STEPS[zoom_index]
	pan = anchor - chart_point * map_scale
	_apply_view()

func pan_by(delta: Vector2) -> void:
	pan += delta
	_apply_view()

# Drag anywhere on the chart to pan (the marker buttons and the zoom
# buttons keep their own clicks); wheel zooms about the cursor.
func _on_frame_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			map_frame.accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_to(zoom_index + 1, mb.position - Vector2(FRAME_PAD, FRAME_PAD))
			map_frame.accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_to(zoom_index - 1, mb.position - Vector2(FRAME_PAD, FRAME_PAD))
			map_frame.accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var mm: InputEventMouseMotion = event
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT == 0:
			_dragging = false
			return
		pan_by(mm.relative)
		map_frame.accept_event()

# --- selection ---

# Start on the place the player is at (if known), else the village; the
# view opens at the closest zoom, centred on Oliver.
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
	zoom_index = DEFAULT_ZOOM
	_centre_on_open = true

# `recentre`: the list rows pass true (find the place); a marker tap leaves
# the view where it is (the marker is already in sight).
func select_poi(poi_id: String, recentre: bool = false) -> void:
	selected_poi = poi_id
	if recentre and WorldMap.is_shown(poi_id):
		centre_on(WorldMap.poi_tile(poi_id))
	refresh()

# --- refresh ---

# Tile -> pixels inside the markers layer (which pans with the chart).
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
	map_rect.texture = WorldMap.render_map(MAP_REGION, true)
	var known: int = WorldMap.discovered_count()
	var here: Vector2i = WorldMap.here_tile()
	var location: String = WorldMap.current_location_name()
	var explored: int = WorldMap.explored_percent(MAP_REGION)
	if here == Vector2i(-1, -1):
		subtitle_label.text = "You are in %s - this map shows the Valley  -  %d of %d places known  -  %d%% explored" % [location, known, WorldMap.POI_NAMES.size(), explored]
	else:
		subtitle_label.text = "You are in %s  -  %d of %d places known  -  %d%% explored" % [location, known, WorldMap.POI_NAMES.size(), explored]
	if _centre_on_open:
		_centre_on_open = false
		var focus: Vector2i = here
		if focus == Vector2i(-1, -1):
			focus = WorldMap.poi_tile(selected_poi) if selected_poi != "" and WorldMap.is_shown(selected_poi) else WorldMap.poi_tile("village")
		centre_on(focus)
	else:
		_apply_view()

	# Markers: one button per shown place, then the you-are-here dot on
	# top (it's not a button; the place under it is still tappable).
	_clear(markers)
	_clear(places_list)
	_clear(places_grid)
	var rows_parent: Container = places_grid if _narrow else places_list
	var grid_w: float = (detail_pane.size.x - 24.0 - 4.0) / 2.0
	for poi_id in WorldMap.POI_NAMES:
		if not WorldMap.is_shown(poi_id):
			continue
		var selected: bool = poi_id == selected_poi
		# Hollow marker only for a place known by hearsay; one Oliver has
		# walked past (seen) or into (discovered) gets the gold disc.
		var rumoured: bool = not WorldMap.is_discovered(poi_id) and not WorldMap.is_seen(poi_id)
		var btn := Button.new()
		btn.name = poi_id.to_pascal_case() + "Marker"
		btn.flat = true
		btn.icon = _rumour_tex if rumoured else (_marker_selected_tex if selected else _marker_tex)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.tooltip_text = WorldMap.POI_NAMES[poi_id] + (" (rumoured)" if rumoured else "")
		for state in ["normal", "hover", "pressed", "focus"]:
			btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		btn.size = Vector2(MARKER_SIZE, MARKER_SIZE)
		btn.position = _map_pos(WorldMap.poi_tile(poi_id)) - Vector2(MARKER_SIZE, MARKER_SIZE) / 2.0
		btn.pressed.connect(select_poi.bind(poi_id, false))
		markers.add_child(btn)
		var row := Button.new()
		row.name = poi_id.to_pascal_case() + "Row"
		row.theme_type_variation = &"TabButtonActive" if selected else &"TabButton"
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.mouse_filter = Control.MOUSE_FILTER_PASS # touch drag-scroll through the list
		row.pressed.connect(select_poi.bind(poi_id, true))
		if _narrow:
			# Half-width cells: a "?" stands in for "(rumoured)", long names trim.
			row.text = ("? " if rumoured else " ") + WorldMap.POI_NAMES[poi_id]
			row.add_theme_font_size_override("font_size", 11)
			row.custom_minimum_size = Vector2(grid_w, GRID_ROW_H)
			row.clip_text = true
			row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			row.tooltip_text = WorldMap.POI_NAMES[poi_id]
		else:
			row.text = "  " + WorldMap.POI_NAMES[poi_id] + (" (rumoured)" if rumoured else "")
			row.add_theme_font_size_override("font_size", 12)
			row.custom_minimum_size = Vector2(places_scroll.size.x, 28)
		rows_parent.add_child(row)
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
	if selected_poi == "" or not WorldMap.is_shown(selected_poi):
		poi_name.text = "Nowhere selected"
		poi_where.text = ""
		poi_desc.text = ""
		poi_status.text = ""
		travel_btn.visible = false
		return
	poi_name.text = WorldMap.POI_NAMES[selected_poi]
	poi_where.text = WorldMap.poi_where(selected_poi)
	poi_desc.text = WorldMap.POI_DESCRIPTIONS.get(selected_poi, "")
	if not WorldMap.is_discovered(selected_poi):
		# Walked past but never in, or only named by a hunt: no Fast Travel yet.
		poi_status.text = "Found - step inside to unlock Fast Travel." if WorldMap.is_seen(selected_poi) else "Rumoured - find it on foot."
		travel_btn.visible = false
		return
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
