extends SceneTree
# Builds WorldMapPanel.tscn (toggled with M) - UI redesign Phase 3b: a real
# rendered map on the character sheet's kit. Skeleton only: dim, window,
# title row, a framed map (TextureRect + a Markers layer that
# world_map_panel.gd fills with one button per discovered place and a you-
# are-here dot), a detail pane (name / where / description / status / Fast
# Travel / list of known places) and a hint. Positions are placeholders -
# the script lays out the wide and phone arrangements at runtime. Run via:
# godot --headless --script res://tools/setup_world_map_panel.gd

func _label(parent: Node, name: String, text: String, pos: Vector2, size_px: int, variation: StringName = &"") -> Label:
	var l := Label.new()
	l.name = name
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size_px)
	if variation != &"":
		l.theme_type_variation = variation
	parent.add_child(l)
	return l

func _own(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_own(child, owner)

func _build_world_map_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "WorldMapPanel"
	layer.set_script(load("res://scripts/world_map_panel.gd"))

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)

	var window := Panel.new()
	window.name = "Window"
	window.position = Vector2(40, 56)
	window.size = Vector2(720, 530)
	layer.add_child(window)

	_label(window, "TitleLabel", "World Map", Vector2(20, 12), 20, &"PanelTitle")
	var subtitle := _label(window, "SubtitleLabel", "", Vector2(360, 18), 13, &"DimLabel")
	subtitle.size = Vector2(300, 18)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var close_btn := Button.new()
	close_btn.name = "CloseBtn"
	close_btn.text = "X"
	close_btn.position = Vector2(676, 10)
	close_btn.size = Vector2(32, 32)
	close_btn.theme_type_variation = &"SecondaryButton"
	close_btn.add_theme_font_size_override("font_size", 15)
	window.add_child(close_btn)

	# The map: a framed TextureRect (one pixel per tile, scaled with NEAREST
	# so it stays crisp) with the marker layer over it.
	var frame := Panel.new()
	frame.name = "MapFrame"
	frame.position = Vector2(20, 52)
	frame.size = Vector2(408, 408)
	frame.theme_type_variation = &"DetailPanel"
	window.add_child(frame)
	var map_rect := TextureRect.new()
	map_rect.name = "MapRect"
	map_rect.position = Vector2(4, 4)
	map_rect.size = Vector2(400, 400)
	map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_rect.stretch_mode = TextureRect.STRETCH_SCALE
	map_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(map_rect)
	var markers := Control.new()
	markers.name = "Markers"
	markers.position = Vector2(4, 4)
	markers.size = Vector2(400, 400)
	markers.mouse_filter = Control.MOUSE_FILTER_PASS
	frame.add_child(markers)

	var pane := Panel.new()
	pane.name = "DetailPane"
	pane.position = Vector2(452, 52)
	pane.size = Vector2(248, 408)
	pane.theme_type_variation = &"DetailPanel"
	window.add_child(pane)
	var poi_name := _label(pane, "PoiName", "", Vector2(12, 10), 17, &"PanelTitle")
	poi_name.size = Vector2(224, 44)
	poi_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label(pane, "PoiWhere", "", Vector2(12, 56), 12, &"DimLabel")
	var desc := _label(pane, "PoiDesc", "", Vector2(12, 76), 13)
	desc.size = Vector2(224, 62)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label(pane, "PoiStatus", "", Vector2(12, 140), 12, &"DimLabel")
	var travel := Button.new()
	travel.name = "TravelBtn"
	travel.text = "Fast Travel"
	travel.position = Vector2(12, 164)
	travel.size = Vector2(224, 40)
	travel.theme_type_variation = &"PrimaryButton"
	travel.add_theme_font_size_override("font_size", 15)
	pane.add_child(travel)
	_label(pane, "PlacesTitle", "Known places", Vector2(12, 216), 13, &"PanelTitle")
	var places_scroll := ScrollContainer.new()
	places_scroll.name = "PlacesScroll"
	places_scroll.position = Vector2(12, 238)
	places_scroll.size = Vector2(224, 158)
	places_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pane.add_child(places_scroll)
	var places := VBoxContainer.new()
	places.name = "PlacesList"
	places.add_theme_constant_override("separation", 4)
	places_scroll.add_child(places)

	_label(window, "HintLabel", "Tap a marker or a name to see the place. Fast Travel lands you at its entrance.", Vector2(20, 470), 12, &"DimLabel")

	_own(layer, layer)
	var packed := PackedScene.new()
	packed.pack(layer)
	var err := ResourceSaver.save(packed, "res://scenes/WorldMapPanel.tscn")
	print("WorldMapPanel.tscn saved: ", err)

func _initialize() -> void:
	print("=== World map panel setup starting ===")
	_build_world_map_panel()
	print("=== Setup complete ===")
	quit()
