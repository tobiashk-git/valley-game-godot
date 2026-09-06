extends SceneTree
# Builds PanelButtons.tscn — the system bar at the top-right of the game
# screen: Menu / Save / Settings / Quit. One BoxContainer that
# panel_buttons.gd lays out as a row (800 wide) or a column (phone). Run via:
# godot --headless --script res://tools/setup_panel_buttons.gd

func _build_panel_buttons() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PanelButtons"
	layer.set_script(load("res://scripts/panel_buttons.gd"))

	# Anchored to the top-right corner and growing leftwards / downwards, so
	# a wider label ("Saved!") never pushes a button off the screen.
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

	# Plain words, not emoji - Godot's Web export renders text through its
	# own rasterizer with no access to the browser's colour-emoji fonts, so
	# emoji-only labels rendered blank on a real phone.
	for entry in [["MenuBtn", "Menu", &"PrimaryButton"], ["SaveBtn", "Save", &"SecondaryButton"], ["SettingsBtn", "Settings", &"SecondaryButton"], ["QuitBtn", "Quit", &"SecondaryButton"]]:
		var btn := Button.new()
		btn.name = entry[0]
		btn.text = entry[1]
		btn.theme_type_variation = entry[2]
		btn.custom_minimum_size = Vector2(68, 40)
		btn.add_theme_font_size_override("font_size", 15)
		bar.add_child(btn)
		btn.owner = layer

	var packed := PackedScene.new()
	packed.pack(layer)
	var err := ResourceSaver.save(packed, "res://scenes/PanelButtons.tscn")
	print("PanelButtons.tscn saved: ", err)

func _initialize() -> void:
	print("=== Panel buttons setup starting ===")
	_build_panel_buttons()
	print("=== Setup complete ===")
	quit()
