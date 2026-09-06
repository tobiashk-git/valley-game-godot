extends SceneTree
# Builds SettingsPanel.tscn - the Settings window opened from the system
# bar (see scripts/settings_panel.gd): a dim over the world, a kit panel
# with a title and X, then rows - Music slider, Sounds slider, the audio
# engine's status line, the last save's age and Load last save. Positions
# are placeholders; the script lays out wide/phone at runtime.
# Run via: godot --headless --script res://tools/setup_settings_panel.gd

func _slider_row(parent: Node, prefix: String, label_text: String) -> void:
	var row := HBoxContainer.new()
	row.name = prefix + "Row"
	row.add_theme_constant_override("separation", 10)
	var l := Label.new()
	l.name = prefix + "Label"
	l.text = label_text
	l.add_theme_font_size_override("font_size", 15)
	l.custom_minimum_size = Vector2(70, 0)
	row.add_child(l)
	var slider := HSlider.new()
	slider.name = prefix + "Slider"
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(0, 32)
	row.add_child(slider)
	var value := Label.new()
	value.name = prefix + "Value"
	value.text = "100"
	value.add_theme_font_size_override("font_size", 13)
	value.custom_minimum_size = Vector2(34, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.theme_type_variation = &"DimLabel"
	row.add_child(value)
	parent.add_child(row)

func _initialize() -> void:
	print("=== Settings panel setup starting ===")
	var layer := CanvasLayer.new()
	layer.name = "SettingsPanel"
	layer.set_script(load("res://scripts/settings_panel.gd"))

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)

	var window := Panel.new()
	window.name = "Window"
	window.position = Vector2(220, 130)
	window.size = Vector2(360, 330)
	layer.add_child(window)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "Settings"
	title.theme_type_variation = &"PanelTitle"
	title.add_theme_font_size_override("font_size", 20)
	title.position = Vector2(20, 14)
	title.size = Vector2(200, 30)
	window.add_child(title)

	var close_btn := Button.new()
	close_btn.name = "CloseBtn"
	close_btn.text = "X"
	close_btn.theme_type_variation = &"SecondaryButton"
	close_btn.add_theme_font_size_override("font_size", 15)
	close_btn.position = Vector2(316, 10)
	close_btn.size = Vector2(32, 32)
	window.add_child(close_btn)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.position = Vector2(20, 58)
	rows.size = Vector2(320, 250)
	rows.add_theme_constant_override("separation", 8)
	window.add_child(rows)

	_slider_row(rows, "Music", "Music")
	_slider_row(rows, "Sfx", "Sounds")

	var audio_line := Label.new()
	audio_line.name = "AudioLine"
	audio_line.theme_type_variation = &"DimLabel"
	audio_line.add_theme_font_size_override("font_size", 11)
	audio_line.autowrap_mode = TextServer.AUTOWRAP_WORD
	rows.add_child(audio_line)

	var sep := ColorRect.new()
	sep.name = "Separator"
	sep.color = Color(0.7, 0.55, 0.2, 0.5)
	sep.custom_minimum_size = Vector2(0, 1)
	rows.add_child(sep)

	var save_title := Label.new()
	save_title.name = "SaveTitle"
	save_title.text = "Game"
	save_title.theme_type_variation = &"PanelTitle"
	save_title.add_theme_font_size_override("font_size", 15)
	rows.add_child(save_title)

	var save_line := Label.new()
	save_line.name = "SaveLine"
	save_line.theme_type_variation = &"DimLabel"
	save_line.add_theme_font_size_override("font_size", 13)
	rows.add_child(save_line)

	var load_btn := Button.new()
	load_btn.name = "LoadBtn"
	load_btn.text = "Load last save"
	load_btn.theme_type_variation = &"SecondaryButton"
	load_btn.add_theme_font_size_override("font_size", 14)
	load_btn.custom_minimum_size = Vector2(0, 38)
	rows.add_child(load_btn)

	var own := func(node: Node, f: Callable) -> void:
		for child in node.get_children():
			child.owner = layer
			f.call(child, f)
	own.call(layer, own)
	var packed := PackedScene.new()
	packed.pack(layer)
	print("SettingsPanel.tscn saved: ", ResourceSaver.save(packed, "res://scenes/SettingsPanel.tscn"))
	print("=== Setup complete ===")
	quit()
