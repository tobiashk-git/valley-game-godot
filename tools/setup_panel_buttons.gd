extends SceneTree
# Builds PanelButtons.tscn — the system bar at the top-right of the game
# screen: Menu (the character sheet) and a cog (the Settings window, which
# holds Save / Load / Quit and the volume sliders). One BoxContainer that
# panel_buttons.gd lays out as a row (800 wide) or a column (phone). Run via:
# godot --headless --script res://tools/setup_panel_buttons.gd

func _build_panel_buttons() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PanelButtons"
	layer.set_script(load("res://scripts/panel_buttons.gd"))

	# Anchored to the top-right corner and growing leftwards / downwards.
	var bar := BoxContainer.new()
	bar.name = "Bar"
	bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar.grow_vertical = Control.GROW_DIRECTION_END
	bar.offset_left = -12
	bar.offset_right = -12
	bar.offset_top = 12
	bar.offset_bottom = 12
	bar.add_theme_constant_override("separation", 8)
	layer.add_child(bar)
	bar.owner = layer

	# A plain word, not emoji - Godot's Web export renders text through its
	# own rasterizer with no access to the browser's colour-emoji fonts, so
	# emoji-only labels rendered blank on a real phone. The cog is a PNG.
	var menu_btn := Button.new()
	menu_btn.name = "MenuBtn"
	menu_btn.text = "Menu"
	menu_btn.theme_type_variation = &"PrimaryButton"
	menu_btn.custom_minimum_size = Vector2(68, 40)
	menu_btn.add_theme_font_size_override("font_size", 15)
	bar.add_child(menu_btn)
	menu_btn.owner = layer

	var settings_btn := Button.new()
	settings_btn.name = "SettingsBtn"
	settings_btn.icon = load("res://assets/ui/cog.png")
	settings_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_btn.add_theme_constant_override("icon_max_width", 22)
	settings_btn.theme_type_variation = &"SecondaryButton"
	settings_btn.custom_minimum_size = Vector2(44, 40)
	settings_btn.tooltip_text = "Settings, save and quit"
	bar.add_child(settings_btn)
	settings_btn.owner = layer

	var packed := PackedScene.new()
	packed.pack(layer)
	var err := ResourceSaver.save(packed, "res://scenes/PanelButtons.tscn")
	print("PanelButtons.tscn saved: ", err)

func _initialize() -> void:
	print("=== Panel buttons setup starting ===")
	_build_panel_buttons()
	print("=== Setup complete ===")
	quit()
