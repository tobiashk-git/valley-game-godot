extends SceneTree
# Builds QuestPanel.tscn (toggled with Q). Run via:
# godot --headless --script res://tools/setup_quest_panel.gd

func _build_quest_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "QuestPanel"
	layer.set_script(load("res://scripts/quest_panel.gd"))

	var panel := Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-160, -110)
	panel.size = Vector2(320, 220)
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
	title.text = "Journal"
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
	var err := ResourceSaver.save(packed, "res://scenes/QuestPanel.tscn")
	print("QuestPanel.tscn saved: ", err)

func _initialize() -> void:
	print("=== Quest panel setup starting ===")
	_build_quest_panel()
	print("=== Setup complete ===")
	quit()
