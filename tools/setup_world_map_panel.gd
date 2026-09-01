extends SceneTree
# Builds WorldMapPanel.tscn (toggled with M). Panel background/title
# styling come from the shared res://resources/ui_theme.tres (project
# default theme) - see tools/setup_theme.gd. Run via:
# godot --headless --script res://tools/setup_world_map_panel.gd

func _build_world_map_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "WorldMapPanel"
	layer.set_script(load("res://scripts/world_map_panel.gd"))

	var panel := Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-170, -120)
	panel.size = Vector2(340, 240)
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
	title.text = "World Map"
	title.theme_type_variation = &"PanelTitle"
	vbox.add_child(title)
	title.owner = layer

	var status_label := Label.new()
	status_label.name = "StatusLabel"
	status_label.theme_type_variation = &"DimLabel"
	status_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(status_label)
	status_label.owner = layer

	var list := VBoxContainer.new()
	list.name = "List"
	list.add_theme_constant_override("separation", 6)
	vbox.add_child(list)
	list.owner = layer

	var packed := PackedScene.new()
	packed.pack(layer)
	var err := ResourceSaver.save(packed, "res://scenes/WorldMapPanel.tscn")
	print("WorldMapPanel.tscn saved: ", err)

func _initialize() -> void:
	print("=== World map panel setup starting ===")
	_build_world_map_panel()
	print("=== Setup complete ===")
	quit()
