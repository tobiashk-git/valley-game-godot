extends SceneTree
# Builds CraftingPanel.tscn (toggled with R). Panel background + title
# styling come from the shared res://resources/ui_theme.tres (project
# default theme) - see tools/setup_theme.gd. Run via:
# godot --headless --script res://tools/setup_crafting_panel.gd

func _build_crafting_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CraftingPanel"
	layer.set_script(load("res://scripts/crafting_panel.gd"))

	var panel := Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-170, -110)
	panel.size = Vector2(340, 220)
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
	title.theme_type_variation = &"PanelTitle"
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
