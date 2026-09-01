extends SceneTree
# Builds CraftingPanel.tscn (toggled with R). Run via:
# godot --headless --script res://tools/setup_crafting_panel.gd

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.06, 0.85)
	style.border_color = Color(0.7, 0.55, 0.2, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	return style

func _build_crafting_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CraftingPanel"
	layer.set_script(load("res://scripts/crafting_panel.gd"))

	var panel := Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-170, -110)
	panel.size = Vector2(340, 220)
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
	title.text = "Crafting"
	title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.35))
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	title.owner = layer

	var list := VBoxContainer.new()
	list.name = "List"
	list.add_theme_constant_override("separation", 6)
	vbox.add_child(list)
	list.owner = layer

	var packed := PackedScene.new()
	packed.pack(layer)
	var err := ResourceSaver.save(packed, "res://scenes/CraftingPanel.tscn")
	print("CraftingPanel.tscn saved: ", err)

func _initialize() -> void:
	print("=== Crafting panel setup starting ===")
	_build_crafting_panel()
	print("=== Setup complete ===")
	quit()
