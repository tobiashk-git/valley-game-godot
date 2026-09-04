extends SceneTree
# Builds HUD.tscn (always-visible top-left counters) and InventoryPanel.tscn
# (toggled with I). Panel background + title styling come from the shared
# res://resources/ui_theme.tres (project default theme) - see
# tools/setup_theme.gd. Run via:
# godot --headless --script res://tools/setup_hud_inventory.gd

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	layer.set_script(load("res://scripts/hud.gd"))

	var panel := Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(12, 12)
	# Bigger than before (was 340x40 with 18px icons/14px font) - read as too
	# small specifically on a high-DPI phone screen: window/stretch/aspect=
	# "keep_width" keeps the game's *logical* width fixed at 800 units
	# regardless of the device's pixel density, so on a high-DPR phone each
	# unit maps to fewer physical on-screen pixels than the same 800 units
	# would on a standard-DPI desktop - everything at a fixed size in game
	# units ends up physically smaller the higher the screen's DPI.
	# Taller again (was 440x56) for the HP/MP bars + effects line stacked
	# underneath the counters as a left-hand column - kept ABOVE y=140 on
	# purpose: BattlePanel's 480x400 panel sits at y=140..540 in the 800x600
	# base viewport (pushed down from the centred y=100 specifically to make
	# room for this column) and draws above this layer (later autoload, same
	# CanvasLayer.layer), so the column stays fully visible mid-fight only as
	# long as this panel ends above it. See setup_battle_panel.gd.
	panel.size = Vector2(440, 124)
	layer.add_child(panel)
	panel.owner = layer

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 8)
	panel.add_child(margin)
	margin.owner = layer

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	vbox.owner = layer

	var hbox := HBoxContainer.new()
	hbox.name = "HBox"
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)
	hbox.owner = layer

	for entry in [["wood", "WoodLabel"], ["stone", "StoneLabel"], ["gold", "GoldLabel"]]:
		var item_id: String = entry[0]
		var label_name: String = entry[1]

		var icon := TextureRect.new()
		icon.name = label_name.replace("Label", "Icon")
		icon.texture = load("res://assets/icons/%s.png" % item_id)
		icon.custom_minimum_size = Vector2(28, 28) # was 18x18
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(icon)
		icon.owner = layer

		var label := Label.new()
		label.name = label_name
		label.add_theme_font_size_override("font_size", 20) # was 14
		hbox.add_child(label)
		label.owner = layer

	var world_label := Label.new()
	world_label.name = "WorldLabel"
	world_label.theme_type_variation = &"DimLabel"
	world_label.add_theme_font_size_override("font_size", 20) # was 14
	hbox.add_child(world_label)
	world_label.owner = layer

	# HP bar over MP bar, left-aligned (SHRINK_BEGIN, fixed width) so they
	# read as a column running down the left side under the counters, plus
	# an effects line beneath (active statuses, e.g. "Poison (3)") - all
	# always visible, so the battle screen no longer needs its own copies
	# (see setup_battle_panel.gd). Same HPBar/MPBar theme variations +
	# centred-label-in-bar shape the Character panel and enemy slots use.
	for entry in [["HP", &"HPBar"], ["MP", &"MPBar"]]:
		var prefix: String = entry[0]
		var bar := ProgressBar.new()
		bar.name = prefix + "Bar"
		bar.custom_minimum_size = Vector2(300, 20)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		bar.show_percentage = false
		bar.theme_type_variation = entry[1]
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(bar)
		bar.owner = layer

		var bar_label := Label.new()
		bar_label.name = prefix + "Label"
		bar_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bar_label.add_theme_font_size_override("font_size", 13)
		bar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(bar_label)
		bar_label.owner = layer

	# Effects line - text/variation set at runtime by hud.gd ("No effects"
	# dimmed, or the active statuses with turns left).
	var status_label := Label.new()
	status_label.name = "StatusLabel"
	status_label.theme_type_variation = &"DimLabel"
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(status_label)
	status_label.owner = layer

	var packed := PackedScene.new()
	packed.pack(layer)
	var err := ResourceSaver.save(packed, "res://scenes/HUD.tscn")
	print("HUD.tscn saved: ", err)

func _build_inventory_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "InventoryPanel"
	layer.set_script(load("res://scripts/inventory_panel.gd"))

	var panel := Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	# Near-fullscreen (720x500 of the 800x600 viewport) - this is a key
	# interaction area (managing gear/crafting/etc.), not a small corner
	# popup. Top margin (60px vs. 40 on the other 3 sides) clears the
	# always-visible PanelButtons toolbar row (y 12-52) so it never overlaps
	# panel content and stays clickable to switch/close panels.
	panel.position = Vector2(-360, -240)
	panel.size = Vector2(720, 500)
	layer.add_child(panel)
	panel.owner = layer

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	# A plain Panel (unlike PanelContainer) doesn't auto-inset children by
	# its StyleBox's content_margin, so the FULL_RECT MarginContainer sat
	# flush against the panel's border with no breathing room - text looked
	# clipped on the left edge. Explicit margins fix it directly.
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 20)
	panel.add_child(margin)
	margin.owner = layer

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	margin.add_child(vbox)
	vbox.owner = layer

	var title := Label.new()
	title.name = "Title"
	title.text = "Inventory"
	title.theme_type_variation = &"PanelTitle"
	vbox.add_child(title)
	title.owner = layer

	var list := VBoxContainer.new()
	list.name = "List"
	vbox.add_child(list)
	list.owner = layer

	var packed := PackedScene.new()
	packed.pack(layer)
	var err := ResourceSaver.save(packed, "res://scenes/InventoryPanel.tscn")
	print("InventoryPanel.tscn saved: ", err)

func _initialize() -> void:
	print("=== HUD + Inventory panel setup starting ===")
	_build_hud()
	_build_inventory_panel()
	print("=== Setup complete ===")
	quit()
