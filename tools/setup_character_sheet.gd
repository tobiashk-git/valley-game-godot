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
	# Save & Quit beside the X on the wide layout (the tabs shrink to 108 to
	# make room); on a phone the Hero tab's Game block carries it instead.
	var quit_btn := Button.new()
	quit_btn.name = "QuitBtn"
	quit_btn.text = "Save & Quit"
	quit_btn.position = Vector2(576, 10)
	quit_btn.size = Vector2(92, 32)
	quit_btn.theme_type_variation = &"SecondaryButton"
	quit_btn.add_theme_font_size_override("font_size", 13)
	window.add_child(quit_btn)

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
	# Trimmed with an ellipsis: "ATK +4 (Ember-forged Wooden Pickaxe)" would
	# otherwise run under the equipment slots' labels.
	var bonus := _label(header, "BonusLabel", "", Vector2(350, 64), 12, &"DimLabel")
	bonus.size = Vector2(165, 16)
	bonus.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	# One header slot per Character.SLOTS entry, right-aligned to x=712 so a
	# new slot grows the row leftwards (six fit before it meets the bars).
	var slots: Dictionary = root.get_node("Character").SLOTS
	var x := 712.0 - slots.size() * 64.0
	for slot_id in slots:
		var node_name: String = slot_id.to_pascal_case() + "Slot"
		var slot := Button.new()
		slot.name = node_name
		slot.position = Vector2(x, 0)
		slot.size = Vector2(56, 56)
		slot.theme_type_variation = &"SlotButton"
		slot.expand_icon = true
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_child(slot)
		var l := _label(header, node_name + "Label", slots[slot_id].label, Vector2(x, 60), 11, &"DimLabel")
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

	# --- Character view: paper doll. Stats column | Oliver with the three
	# fitting slots around him (weapon by the hand, armour at the torso,
	# accessory at the neck) | the tapped slot's worn item + carried
	# alternatives. Modelled on the user's two reference screens. ---
	# Wrapped in a ScrollContainer: on a phone-width screen (Layout.is_narrow())
	# character_sheet.gd stacks the doll, the slot pane and the stats column
	# vertically and lets the view scroll; at 800 wide the view fits and the
	# scroll never engages. Paths are Window/CharacterScroll/CharacterView/...
	var chr_scroll := ScrollContainer.new()
	chr_scroll.name = "CharacterScroll"
	chr_scroll.position = Vector2(0, 158)
	chr_scroll.size = Vector2(720, 360)
	chr_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chr_scroll.visible = false
	window.add_child(chr_scroll)
	var chr := Control.new()
	chr.name = "CharacterView"
	chr.custom_minimum_size = Vector2(720, 360)
	chr_scroll.add_child(chr)
	var stats := VBoxContainer.new()
	stats.name = "StatsList"
	stats.position = Vector2(20, 0)
	stats.size = Vector2(200, 340)
	stats.add_theme_constant_override("separation", 4)
	chr.add_child(stats)
	for entry in [["Divider1", 236.0], ["Divider2", 582.0]]:
		var div := ColorRect.new()
		div.name = entry[0]
		div.position = Vector2(entry[1], 0)
		div.size = Vector2(1, 342)
		div.color = Color(0.7, 0.55, 0.2, 0.35)
		chr.add_child(div)
	var eq_title := _label(chr, "EquipmentTitle", "Equipment", Vector2(250, 0), 14, &"PanelTitle")
	eq_title.size = Vector2(300, 20)
	eq_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The figure: character_sheet.gd fills it with assets/oliver_portrait.png
	# if that exists (a keyed illustration, Leonardo track), else the player
	# sprite's idle frame at 3x.
	# Tall box between the two slot columns: a full-body illustration is
	# roughly 1:3, so height is what buys it size.
	var figure := TextureRect.new()
	figure.name = "Figure"
	figure.position = Vector2(300, 22)
	figure.size = Vector2(204, 230)
	figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	figure.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	chr.add_child(figure)
	var shadow := ColorRect.new()
	shadow.name = "FigureShadow"
	shadow.position = Vector2(352, 248)
	shadow.size = Vector2(100, 8)
	shadow.color = Color(0, 0, 0, 0.35)
	chr.add_child(shadow)
	# One doll slot (+ label + connector line to the figure) per
	# Character.SLOTS entry, at the table's `doll` position; the line leaves
	# the slot's inner edge (right edge for the left column, left edge for
	# the right column) and ends at the table's `line_to`. Both columns keep
	# the same 14px gap from their divider (236 | 250..314 ... 504..568 | 582).
	for slot_id in slots:
		var def: Dictionary = slots[slot_id]
		var pos: Vector2 = def.doll
		var pascal: String = slot_id.to_pascal_case()
		var line := Line2D.new()
		line.name = pascal + "Line"
		var from: Vector2 = pos + (Vector2(66, 32) if pos.x < 400.0 else Vector2(-4, 32))
		line.points = PackedVector2Array([from, def.line_to])
		line.width = 2.0
		line.default_color = Color(0.7, 0.55, 0.2, 0.45)
		chr.add_child(line)
		var slot := Button.new()
		slot.name = "Doll" + pascal + "Slot"
		slot.position = pos
		slot.size = Vector2(64, 64)
		slot.theme_type_variation = &"SlotButton"
		slot.expand_icon = true
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chr.add_child(slot)
		var l := _label(chr, "Doll" + pascal + "SlotLabel", def.label, pos + Vector2(0, 66), 11, &"DimLabel")
		l.size = Vector2(64, 14)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := _label(chr, "DollHint", "Tap a slot to see what fits", Vector2(250, 262), 12, &"DimLabel")
	hint.size = Vector2(300, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var slot_pane := Panel.new()
	slot_pane.name = "SlotPane"
	slot_pane.position = Vector2(594, 0)
	slot_pane.size = Vector2(106, 342)
	slot_pane.theme_type_variation = &"DetailPanel"
	chr.add_child(slot_pane)
	var pane_title := _label(slot_pane, "SlotPaneTitle", "", Vector2(0, 6), 14, &"PanelTitle")
	pane_title.size = Vector2(106, 20)
	pane_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var slot_scroll := ScrollContainer.new()
	slot_scroll.name = "SlotScroll"
	slot_scroll.position = Vector2(6, 30)
	slot_scroll.size = Vector2(94, 306)
	slot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	slot_pane.add_child(slot_scroll)
	# A plain BoxContainer (a VBoxContainer refuses to change orientation):
	# vertical here, flipped sideways by character_sheet.gd on a phone.
	var slot_list := BoxContainer.new()
	slot_list.vertical = true
	slot_list.name = "SlotList"
	slot_list.add_theme_constant_override("separation", 4)
	slot_scroll.add_child(slot_list)

	# --- Crafting view (UI redesign Phase 2): two modes sharing one grid +
	# detail pane. Craft = recipe grid -> ingredient checklist -> Craft.
	# Enhance = carried/worn gear grid -> the enhancements that fit it ->
	# Enhance. Rows inside the pane are built at runtime. ---
	var crf := Control.new()
	crf.name = "CraftingView"
	crf.position = Vector2(0, 158)
	crf.size = Vector2(720, 360)
	crf.visible = false
	window.add_child(crf)
	var modes := HBoxContainer.new()
	modes.name = "Modes"
	modes.position = Vector2(20, 0)
	modes.add_theme_constant_override("separation", 6)
	crf.add_child(modes)
	for entry in [["CraftMode", "Craft"], ["EnhanceMode", "Enhance"]]:
		var b := Button.new()
		b.name = entry[0]
		b.text = entry[1]
		b.custom_minimum_size = Vector2(100, 28)
		b.theme_type_variation = &"TabButton"
		b.add_theme_font_size_override("font_size", 13)
		modes.add_child(b)
	var craft_count := _label(crf, "CraftCountLabel", "", Vector2(300, 8), 11, &"DimLabel")
	craft_count.size = Vector2(140, 16)
	craft_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var craft_scroll := ScrollContainer.new()
	craft_scroll.name = "CraftScroll"
	craft_scroll.position = Vector2(20, 36)
	craft_scroll.size = Vector2(424, 284)
	craft_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	crf.add_child(craft_scroll)
	# Sections (a title + a grid each, built at runtime by character_sheet.gd's
	# _craft_section()): Craft mode groups recipes as Potions & Food /
	# Equipment / Materials, Enhance mode groups gear by slot (user request:
	# "some kind of logical grouping").
	var craft_groups := VBoxContainer.new()
	craft_groups.name = "CraftGroups"
	craft_groups.add_theme_constant_override("separation", 8)
	craft_scroll.add_child(craft_groups)
	var craft_pane := Panel.new()
	craft_pane.name = "CraftPane"
	craft_pane.position = Vector2(452, 0)
	craft_pane.size = Vector2(248, 320)
	craft_pane.theme_type_variation = &"DetailPanel"
	crf.add_child(craft_pane)
	var craft_icon := TextureRect.new()
	craft_icon.name = "CraftIcon"
	craft_icon.position = Vector2(12, 12)
	craft_icon.size = Vector2(48, 48)
	craft_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	craft_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	craft_pane.add_child(craft_icon)
	# Enhanced names run to two lines ("Ember-forged Wooden Pickaxe"), so the
	# name, type and description each get their own band.
	var craft_name := _label(craft_pane, "CraftName", "", Vector2(68, 8), 15, &"PanelTitle")
	craft_name.size = Vector2(170, 42)
	craft_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	var craft_type := _label(craft_pane, "CraftType", "", Vector2(68, 52), 11, &"DimLabel")
	craft_type.size = Vector2(170, 30)
	craft_type.autowrap_mode = TextServer.AUTOWRAP_WORD
	var craft_desc := _label(craft_pane, "CraftDesc", "", Vector2(12, 88), 12)
	craft_desc.size = Vector2(224, 44)
	craft_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	var craft_scroll2 := ScrollContainer.new()
	craft_scroll2.name = "CraftRowsScroll"
	craft_scroll2.position = Vector2(12, 136)
	craft_scroll2.size = Vector2(224, 126)
	craft_scroll2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	craft_pane.add_child(craft_scroll2)
	var craft_rows := VBoxContainer.new()
	craft_rows.name = "CraftRows"
	craft_rows.add_theme_constant_override("separation", 4)
	craft_scroll2.add_child(craft_rows)
	var craft_action := Button.new()
	craft_action.name = "CraftAction"
	craft_action.position = Vector2(12, 268)
	craft_action.size = Vector2(224, 40)
	craft_action.theme_type_variation = &"PrimaryButton"
	craft_action.add_theme_font_size_override("font_size", 15)
	craft_pane.add_child(craft_action)
	_label(crf, "CraftHint", "", Vector2(20, 330), 12, &"DimLabel")

	# --- Map view (UI redesign Phase 3b; moved in from a standalone window
	# so the tab strip stays available). Logic in scripts/map_view.gd: a
	# framed rendered map (TextureRect + Markers layer) and a detail pane
	# (name / where / description / status / Fast Travel / known places).
	# The sheet hides its header on this tab, so the view starts at y=66. ---
	var mapv := Control.new()
	mapv.name = "MapView"
	mapv.set_script(load("res://scripts/map_view.gd"))
	mapv.position = Vector2(0, 66)
	mapv.size = Vector2(720, 452)
	mapv.visible = false
	window.add_child(mapv)
	var map_subtitle := _label(mapv, "SubtitleLabel", "", Vector2(20, 0), 13, &"DimLabel")
	map_subtitle.size = Vector2(680, 18)
	var map_frame := Panel.new()
	map_frame.name = "MapFrame"
	map_frame.position = Vector2(20, 22)
	map_frame.size = Vector2(408, 408)
	map_frame.theme_type_variation = &"DetailPanel"
	mapv.add_child(map_frame)
	var map_rect := TextureRect.new()
	map_rect.name = "MapRect"
	map_rect.position = Vector2(4, 4)
	map_rect.size = Vector2(400, 400)
	map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_rect.stretch_mode = TextureRect.STRETCH_SCALE
	map_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_frame.add_child(map_rect)
	var map_markers := Control.new()
	map_markers.name = "Markers"
	map_markers.position = Vector2(4, 4)
	map_markers.size = Vector2(400, 400)
	map_markers.mouse_filter = Control.MOUSE_FILTER_PASS
	map_frame.add_child(map_markers)
	var map_pane := Panel.new()
	map_pane.name = "DetailPane"
	map_pane.position = Vector2(452, 22)
	map_pane.size = Vector2(248, 408)
	map_pane.theme_type_variation = &"DetailPanel"
	mapv.add_child(map_pane)
	var poi_name := _label(map_pane, "PoiName", "", Vector2(12, 10), 17, &"PanelTitle")
	poi_name.size = Vector2(224, 44)
	poi_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label(map_pane, "PoiWhere", "", Vector2(12, 56), 12, &"DimLabel")
	var poi_desc := _label(map_pane, "PoiDesc", "", Vector2(12, 76), 13)
	poi_desc.size = Vector2(224, 62)
	poi_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label(map_pane, "PoiStatus", "", Vector2(12, 140), 12, &"DimLabel")
	var travel := Button.new()
	travel.name = "TravelBtn"
	travel.text = "Fast Travel"
	travel.position = Vector2(12, 164)
	travel.size = Vector2(224, 40)
	travel.theme_type_variation = &"PrimaryButton"
	travel.add_theme_font_size_override("font_size", 15)
	map_pane.add_child(travel)
	_label(map_pane, "PlacesTitle", "Known places", Vector2(12, 216), 13, &"PanelTitle")
	var places_scroll := ScrollContainer.new()
	places_scroll.name = "PlacesScroll"
	places_scroll.position = Vector2(12, 238)
	places_scroll.size = Vector2(224, 158)
	places_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	map_pane.add_child(places_scroll)
	var places := VBoxContainer.new()
	places.name = "PlacesList"
	places.add_theme_constant_override("separation", 4)
	places_scroll.add_child(places)
	_label(mapv, "HintLabel", "Tap a marker or a name to see the place. Fast Travel lands you at its entrance.", Vector2(20, 436), 12, &"DimLabel")

	# --- Journal view (UI redesign Phase 3c; the old QuestPanel moved in).
	# Logic in scripts/journal_view.gd: quest rows under Active / Completed
	# headers on the left, the selected quest's giver / goal / progress /
	# reward / Track button on the right. Header hidden on this tab too. ---
	var jrn := Control.new()
	jrn.name = "JournalView"
	jrn.set_script(load("res://scripts/journal_view.gd"))
	jrn.position = Vector2(0, 66)
	jrn.size = Vector2(720, 452)
	jrn.visible = false
	window.add_child(jrn)
	var list_scroll := ScrollContainer.new()
	list_scroll.name = "ListScroll"
	list_scroll.position = Vector2(20, 0)
	list_scroll.size = Vector2(424, 430)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	jrn.add_child(list_scroll)
	var quest_list := VBoxContainer.new()
	quest_list.name = "QuestList"
	quest_list.add_theme_constant_override("separation", 4)
	list_scroll.add_child(quest_list)
	var jpane := Panel.new()
	jpane.name = "DetailPane"
	jpane.position = Vector2(452, 0)
	jpane.size = Vector2(248, 430)
	jpane.theme_type_variation = &"DetailPanel"
	jrn.add_child(jpane)
	var qname := _label(jpane, "QuestName", "", Vector2(12, 10), 17, &"PanelTitle")
	qname.size = Vector2(224, 44)
	qname.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label(jpane, "QuestGiver", "", Vector2(12, 56), 12, &"DimLabel")
	for entry in [["QuestGoal", Vector2(12, 76), Vector2(224, 60), 13], ["QuestProgress", Vector2(12, 140), Vector2(224, 40), 13]]:
		var rtl := RichTextLabel.new()
		rtl.name = entry[0]
		rtl.bbcode_enabled = true
		rtl.scroll_active = false
		rtl.position = entry[1]
		rtl.size = entry[2]
		rtl.add_theme_font_size_override("normal_font_size", entry[3])
		jpane.add_child(rtl)
	var qreward := _label(jpane, "QuestReward", "", Vector2(12, 184), 12, &"DimLabel")
	qreward.size = Vector2(224, 36)
	qreward.autowrap_mode = TextServer.AUTOWRAP_WORD
	var track := Button.new()
	track.name = "TrackBtn"
	track.text = "Track on screen"
	track.position = Vector2(12, 228)
	track.size = Vector2(224, 40)
	track.theme_type_variation = &"PrimaryButton"
	track.add_theme_font_size_override("font_size", 15)
	jpane.add_child(track)
	_label(jrn, "HintLabel", "Tap a quest to see it. Tracked quests show at the top right of the screen (up to 2).", Vector2(20, 436), 12, &"DimLabel")

	_own(layer, layer)
	var packed := PackedScene.new()
	packed.pack(layer)
	print("CharacterSheet.tscn saved: ", ResourceSaver.save(packed, "res://scenes/CharacterSheet.tscn"))

func _initialize() -> void:
	print("=== Character sheet setup starting ===")
	_build()
	print("=== Setup complete ===")
	quit()
