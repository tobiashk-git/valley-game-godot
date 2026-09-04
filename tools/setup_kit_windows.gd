extends SceneTree
# Builds ShopPanel.tscn and StoragePanel.tscn (UI redesign Phase 3) - the two
# contextual item windows on the character sheet's kit. One skeleton, two
# scenes: dim, window, title row (title + subtitle + X), two tab buttons,
# count label, slot grid in a scroll, detail pane (icon / name / type / desc
# / value / two action buttons), hint. Positions are placeholders - the
# KitWindow base script (scripts/kit_window.gd) lays everything out at
# runtime for the wide and the phone layouts. Run via:
# godot --headless --script res://tools/setup_kit_windows.gd
# (then godot --headless --import once for any new script's .uid).

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

func _build(layer_name: String, script_path: String, title: String, tab_a_text: String, tab_b_text: String, scene_path: String) -> void:
	var layer := CanvasLayer.new()
	layer.name = layer_name
	layer.set_script(load(script_path))

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

	_label(window, "TitleLabel", title, Vector2(20, 12), 20, &"PanelTitle")
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

	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.position = Vector2(20, 52)
	tabs.add_theme_constant_override("separation", 6)
	window.add_child(tabs)
	for entry in [["TabA", tab_a_text], ["TabB", tab_b_text]]:
		var b := Button.new()
		b.name = entry[0]
		b.text = entry[1]
		b.custom_minimum_size = Vector2(118, 32)
		b.theme_type_variation = &"TabButton"
		b.add_theme_font_size_override("font_size", 14)
		tabs.add_child(b)

	var count := _label(window, "CountLabel", "", Vector2(300, 60), 11, &"DimLabel")
	count.size = Vector2(144, 16)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var scroll := ScrollContainer.new()
	scroll.name = "GridScroll"
	scroll.position = Vector2(20, 96)
	scroll.size = Vector2(424, 394)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	window.add_child(scroll)
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)

	var pane := Panel.new()
	pane.name = "DetailPane"
	pane.position = Vector2(452, 96)
	pane.size = Vector2(248, 394)
	pane.theme_type_variation = &"DetailPanel"
	window.add_child(pane)
	var icon := TextureRect.new()
	icon.name = "DetailIcon"
	icon.position = Vector2(12, 12)
	icon.size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pane.add_child(icon)
	_label(pane, "DetailName", "", Vector2(68, 10), 17, &"PanelTitle")
	var dtype := _label(pane, "DetailType", "", Vector2(68, 34), 12, &"DimLabel")
	dtype.size = Vector2(170, 32)
	dtype.autowrap_mode = TextServer.AUTOWRAP_WORD
	var desc := _label(pane, "DetailDesc", "", Vector2(12, 72), 13)
	desc.size = Vector2(224, 80)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	var value := _label(pane, "DetailValue", "", Vector2(12, 158), 12, &"DimLabel")
	value.size = Vector2(224, 40)
	value.autowrap_mode = TextServer.AUTOWRAP_WORD
	var actions := VBoxContainer.new()
	actions.name = "Actions"
	actions.position = Vector2(12, 206)
	actions.size = Vector2(224, 88)
	actions.add_theme_constant_override("separation", 8)
	pane.add_child(actions)
	for entry in [["PrimaryAction", &"PrimaryButton"], ["SecondaryAction", &"SecondaryButton"]]:
		var b := Button.new()
		b.name = entry[0]
		b.custom_minimum_size = Vector2(224, 40)
		b.theme_type_variation = entry[1]
		b.add_theme_font_size_override("font_size", 15)
		b.visible = false
		actions.add_child(b)
	_label(window, "HintLabel", "", Vector2(20, 500), 12, &"DimLabel")

	_own(layer, layer)
	var packed := PackedScene.new()
	packed.pack(layer)
	print("%s saved: %s" % [scene_path, ResourceSaver.save(packed, scene_path)])

func _initialize() -> void:
	print("=== Kit windows setup starting ===")
	_build("ShopPanel", "res://scripts/shop_panel.gd", "Village Trader", "Buy", "Sell", "res://scenes/ShopPanel.tscn")
	_build("StoragePanel", "res://scripts/storage_panel.gd", "Storage Chest", "Chest", "Backpack", "res://scenes/StoragePanel.tscn")
	print("=== Setup complete ===")
	quit()
