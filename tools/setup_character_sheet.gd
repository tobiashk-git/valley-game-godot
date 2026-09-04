extends SceneTree
# Builds CharacterSheet.tscn - the tabbed character-sheet window (UI redesign
# Phase 1: Inventory + Character merged; the Crafting/Journal/Map tabs hand
# off to the existing panels for now). Only the static skeleton lives here;
# scripts/character_sheet.gd fills the backpack grid, detail pane and stats
# list at runtime. Styling comes from the theme's SlotButton/TabButton/
# DetailPanel/PrimaryButton variations (tools/setup_theme.gd). Run via:
# godot --headless --script res://tools/setup_character_sheet.gd
# (then godot --headless --import once for the new script's .uid).
#
# Layout (800x600 base viewport, everything top-anchored like the other
# overlays): window y=56..586 - starts below the PanelButtons toolbar
# (y 12-52) so the tab strip never sits under it.

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

func _bar(parent: Node, prefix: String, pos: Vector2, variation: StringName) -> void:
	var bar := ProgressBar.new()
	bar.name = prefix + "Bar"
	bar.position = pos
	bar.size = Vector2(220, 16)
	bar.show_percentage = false
	bar.theme_type_variation = variation
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.name = prefix + "Label"
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 12)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(l)
	parent.add_child(bar)

func _own(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_own(child, owner)

func _build() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CharacterSheet"
	layer.set_script(load("res://scripts/character_sheet.gd"))

	# Dims the world behind the window (the old popups didn't, and read as
	# floating over a busy scene).
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

	# --- Tab strip ---
	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.position = Vector2(12, 10)
	tabs.add_theme_constant_override("separation", 6)
	window.add_child(tabs)
	for entry in [["InventoryTab", "Inventory"], ["CharacterTab", "Character"], ["CraftingTab", "Crafting"], ["JournalTab", "Journal"], ["MapTab", "Map"]]:
		var b := Button.new()
		b.name = entry[0]
		b.text = entry[1]
		b.custom_minimum_size = Vector2(118, 32)
		b.theme_type_variation = &"TabButton"
		b.add_theme_font_size_override("font_size", 14)
		tabs.add_child(b)
	var close_btn := Button.new()
	close_btn.name = "CloseBtn"
	close_btn.text = "X"
	close_btn.position = Vector2(676, 10)
	close_btn.size = Vector2(32, 32)
	close_btn.theme_type_variation = &"SecondaryButton"
	close_btn.add_theme_font_size_override("font_size", 15)
	window.add_child(close_btn)

	# --- Header (shared by every tab) ---
	var header := Control.new()
	header.name = "Header"
	header.position = Vector2(0, 54)
	header.size = Vector2(720, 92)
	window.add_child(header)

	var frame := Panel.new()
	frame.name = "PortraitFrame"
	frame.position = Vector2(20, 0)
	frame.size = Vector2(80, 80)
	frame.theme_type_variation = &"DetailPanel"
	header.add_child(frame)
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.position = Vector2(4, 4)
	portrait.size = Vector2(72, 72)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(portrait)

	_label(header, "NameLabel", "Oliver", Vector2(112, -2), 20, &"PanelTitle")
	_label(header, "LocationLabel", "", Vector2(112, 22), 12, &"DimLabel")
	_bar(header, "HP", Vector2(112, 42), &"HPBar")
	_bar(header, "MP", Vector2(112, 62), &"MPBar")
	_label(header, "StatsLabel", "", Vector2(350, 45), 14)
	_label(header, "BonusLabel", "", Vector2(350, 64), 12, &"DimLabel")

	var x := 520.0
	for entry in [["WeaponSlot", "Weapon"], ["ArmorSlot", "Armor"], ["AccessorySlot", "Accessory"]]:
		var slot := Button.new()
		slot.name = entry[0]
		slot.position = Vector2(x, 0)
		slot.size = Vector2(56, 56)
		slot.theme_type_variation = &"SlotButton"
		slot.expand_icon = true
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_child(slot)
		var l := _label(header, entry[0] + "Label", entry[1], Vector2(x, 60), 11, &"DimLabel")
		l.size = Vector2(56, 14)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		x += 64

	var sep := ColorRect.new()
	sep.name = "Separator"
	sep.position = Vector2(20, 150)
	sep.size = Vector2(680, 1)
	sep.color = Color(0.7, 0.55, 0.2, 0.5)
	window.add_child(sep)

	# --- Inventory view ---
	var inv := Control.new()
	inv.name = "InventoryView"
	inv.position = Vector2(0, 158)
	inv.size = Vector2(720, 360)
	window.add_child(inv)
	_label(inv, "BackpackTitle", "Backpack", Vector2(20, 0), 14, &"PanelTitle")
	var count := _label(inv, "CountLabel", "", Vector2(300, 3), 11, &"DimLabel")
	count.size = Vector2(140, 16)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var scroll := ScrollContainer.new()
	scroll.name = "GridScroll"
	scroll.position = Vector2(20, 24)
	scroll.size = Vector2(424, 296)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inv.add_child(scroll)
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)

	var pane := Panel.new()
	pane.name = "DetailPane"
	pane.position = Vector2(452, 0)
	pane.size = Vector2(248, 320)
	pane.theme_type_variation = &"DetailPanel"
	inv.add_child(pane)
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
	desc.size = Vector2(224, 96)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label(pane, "DetailValue", "", Vector2(12, 174), 12, &"DimLabel")
	var actions := VBoxContainer.new()
	actions.name = "Actions"
	actions.position = Vector2(12, 220)
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
	_label(inv, "HintLabel", "Tap an item to see it. Gear shows Equip; potions show Use.", Vector2(20, 330), 12, &"DimLabel")

	# --- Character view ---
	var chr := Control.new()
	chr.name = "CharacterView"
	chr.position = Vector2(0, 158)
	chr.size = Vector2(720, 360)
	chr.visible = false
	window.add_child(chr)
	var stats := VBoxContainer.new()
	stats.name = "StatsList"
	stats.position = Vector2(20, 0)
	stats.size = Vector2(680, 340)
	stats.add_theme_constant_override("separation", 6)
	chr.add_child(stats)

	_own(layer, layer)
	var packed := PackedScene.new()
	packed.pack(layer)
	print("CharacterSheet.tscn saved: ", ResourceSaver.save(packed, "res://scenes/CharacterSheet.tscn"))

func _initialize() -> void:
	print("=== Character sheet setup starting ===")
	_build()
	print("=== Setup complete ===")
	quit()
