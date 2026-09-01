extends SceneTree
# Builds CharacterPanel.tscn (toggled with C). Panel background, title
# color, and HP/MP bar colors come from the shared res://resources/
# ui_theme.tres (project default theme) - see tools/setup_theme.gd.
# Run via: godot --headless --script res://tools/setup_character_panel.gd

func _build_character_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CharacterPanel"
	layer.set_script(load("res://scripts/character_panel.gd"))

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
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	vbox.owner = layer

	var title := Label.new()
	title.name = "Title"
	title.text = "Character"
	title.theme_type_variation = &"PanelTitle"
	vbox.add_child(title)
	title.owner = layer

	# HP bar
	var hp_bar := ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.custom_minimum_size = Vector2(0, 20)
	hp_bar.show_percentage = false
	hp_bar.theme_type_variation = &"HPBar"
	vbox.add_child(hp_bar)
	hp_bar.owner = layer

	var hp_label := Label.new()
	hp_label.name = "HPLabel"
	hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 13)
	hp_bar.add_child(hp_label)
	hp_label.owner = layer

	# MP bar
	var mp_bar := ProgressBar.new()
	mp_bar.name = "MPBar"
	mp_bar.custom_minimum_size = Vector2(0, 20)
	mp_bar.show_percentage = false
	mp_bar.theme_type_variation = &"MPBar"
	vbox.add_child(mp_bar)
	mp_bar.owner = layer

	var mp_label := Label.new()
	mp_label.name = "MPLabel"
	mp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	mp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mp_label.add_theme_font_size_override("font_size", 13)
	mp_bar.add_child(mp_label)
	mp_label.owner = layer

	# Strength / Agility row
	var stats_row := HBoxContainer.new()
	stats_row.name = "StatsRow"
	stats_row.add_theme_constant_override("separation", 20)
	vbox.add_child(stats_row)
	stats_row.owner = layer

	var strength_label := Label.new()
	strength_label.name = "StrengthLabel"
	strength_label.add_theme_font_size_override("font_size", 14)
	stats_row.add_child(strength_label)
	strength_label.owner = layer

	var agility_label := Label.new()
	agility_label.name = "AgilityLabel"
	agility_label.add_theme_font_size_override("font_size", 14)
	stats_row.add_child(agility_label)
	agility_label.owner = layer

	var sep := HSeparator.new()
	sep.name = "Sep"
	vbox.add_child(sep)
	sep.owner = layer

	var equip_title := Label.new()
	equip_title.name = "EquipTitle"
	equip_title.text = "Equipment"
	equip_title.theme_type_variation = &"PanelTitle"
	equip_title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(equip_title)
	equip_title.owner = layer

	for entry in [["WeaponLabel", "Weapon"], ["ArmorLabel", "Armor"], ["AccessoryLabel", "Accessory"]]:
		var label := Label.new()
		label.name = entry[0]
		label.add_theme_font_size_override("font_size", 13)
		vbox.add_child(label)
		label.owner = layer

	var packed := PackedScene.new()
	packed.pack(layer)
	var err := ResourceSaver.save(packed, "res://scenes/CharacterPanel.tscn")
	print("CharacterPanel.tscn saved: ", err)

func _initialize() -> void:
	print("=== Character panel setup starting ===")
	_build_character_panel()
	print("=== Setup complete ===")
	quit()
