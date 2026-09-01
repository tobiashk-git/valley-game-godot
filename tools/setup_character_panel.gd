extends SceneTree
# Builds CharacterPanel.tscn (toggled with C). Run via:
# godot --headless --script res://tools/setup_character_panel.gd

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.06, 0.85)
	style.border_color = Color(0.7, 0.55, 0.2, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	return style

func _bar_style(fg: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.75, 0.15, 0.15, 1.0) if fg else Color(0.2, 0.05, 0.05, 1.0)
	style.set_corner_radius_all(3)
	return style

func _build_character_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CharacterPanel"
	layer.set_script(load("res://scripts/character_panel.gd"))

	var panel := Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-130, -110)
	panel.size = Vector2(260, 220)
	panel.add_theme_stylebox_override("panel", _panel_style())
	layer.add_child(panel)
	panel.owner = layer

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.35))
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	title.owner = layer

	# HP bar
	var hp_bar := ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.custom_minimum_size = Vector2(0, 20)
	hp_bar.show_percentage = false
	hp_bar.add_theme_stylebox_override("fill", _bar_style(true))
	hp_bar.add_theme_stylebox_override("background", _bar_style(false))
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
	var mp_fg := _bar_style(true)
	mp_fg.bg_color = Color(0.15, 0.35, 0.75, 1.0)
	var mp_bg := _bar_style(false)
	mp_bg.bg_color = Color(0.05, 0.1, 0.2, 1.0)
	mp_bar.add_theme_stylebox_override("fill", mp_fg)
	mp_bar.add_theme_stylebox_override("background", mp_bg)
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
	equip_title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.35))
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
