extends SceneTree
# Builds StoragePanel.tscn (two-column chest/backpack transfer UI, opened
# by chest.gd). Panel background + title styling come from the shared
# res://resources/ui_theme.tres (project default theme) - see
# tools/setup_theme.gd. Run via:
# godot --headless --script res://tools/setup_storage_panel.gd

func _build_column(parent: HBoxContainer, layer: Node, col_name: String, title_text: String) -> void:
	var col := VBoxContainer.new()
	col.name = col_name
	col.custom_minimum_size = Vector2(180, 0)
	parent.add_child(col)
	col.owner = layer

	var title := Label.new()
	title.name = col_name.replace("Column", "Title")
	title.text = title_text
	title.theme_type_variation = &"PanelTitle"
	title.add_theme_font_size_override("font_size", 16)
	col.add_child(title)
	title.owner = layer

	var list := VBoxContainer.new()
	list.name = col_name.replace("Column", "List")
	list.add_theme_constant_override("separation", 4)
	col.add_child(list)
	list.owner = layer

func _build_storage_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "StoragePanel"
	layer.set_script(load("res://scripts/storage_panel.gd"))

	var panel := Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-200, -140)
	panel.size = Vector2(400, 280)
	layer.add_child(panel)
	panel.owner = layer

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)
	margin.owner = layer

	var hbox := HBoxContainer.new()
	hbox.name = "HBox"
	hbox.add_theme_constant_override("separation", 20)
	margin.add_child(hbox)
	hbox.owner = layer

	_build_column(hbox, layer, "ChestColumn", "Chest")
	_build_column(hbox, layer, "BackpackColumn", "Backpack")

	var packed := PackedScene.new()
	packed.pack(layer)
	var err := ResourceSaver.save(packed, "res://scenes/StoragePanel.tscn")
	print("StoragePanel.tscn saved: ", err)

func _initialize() -> void:
	print("=== Storage panel setup starting ===")
	_build_storage_panel()
	print("=== Setup complete ===")
	quit()
