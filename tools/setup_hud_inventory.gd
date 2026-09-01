extends SceneTree
# Builds HUD.tscn (always-visible top-left counters) and InventoryPanel.tscn
# (toggled with I). Panel background + title styling come from the shared
# res://resources/ui_theme.tres (project default theme) - see
# tools/setup_theme.gd. Run via:
# godot --headless --script res://tools/setup_hud_inventory.gd

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	layer.set_script(load("res://scripts/hud.gd"))

	var panel := Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(12, 12)
	panel.size = Vector2(260, 40)
	layer.add_child(panel)
	panel.owner = layer

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)
	margin.owner = layer

	var hbox := HBoxContainer.new()
	hbox.name = "HBox"
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)
	hbox.owner = layer

	for label_name in ["WoodLabel", "StoneLabel", "GoldLabel"]:
		var label := Label.new()
		label.name = label_name
		label.add_theme_font_size_override("font_size", 14)
		hbox.add_child(label)
		label.owner = layer

	var packed := PackedScene.new()
	packed.pack(layer)
	var err := ResourceSaver.save(packed, "res://scenes/HUD.tscn")
	print("HUD.tscn saved: ", err)

func _build_inventory_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "InventoryPanel"
	layer.set_script(load("res://scripts/inventory_panel.gd"))

	var panel := Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-260, 12)
	panel.size = Vector2(240, 220)
	layer.add_child(panel)
	panel.owner = layer

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)
	margin.owner = layer

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	margin.add_child(vbox)
	vbox.owner = layer

	var title := Label.new()
	title.name = "Title"
	title.text = "Inventory"
	title.theme_type_variation = &"PanelTitle"
	vbox.add_child(title)
	title.owner = layer

	var list := VBoxContainer.new()
	list.name = "List"
	vbox.add_child(list)
	list.owner = layer

	var packed := PackedScene.new()
	packed.pack(layer)
	var err := ResourceSaver.save(packed, "res://scenes/InventoryPanel.tscn")
	print("InventoryPanel.tscn saved: ", err)

func _initialize() -> void:
	print("=== HUD + Inventory panel setup starting ===")
	_build_hud()
	_build_inventory_panel()
	print("=== Setup complete ===")
	quit()
