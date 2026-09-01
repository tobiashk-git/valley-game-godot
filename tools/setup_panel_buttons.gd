extends SceneTree
# Builds PanelButtons.tscn — a persistent top-right row of icon buttons
# (Inventory/Character/Crafting/Journal/Map), same icons as the JS
# reference's touch-only equivalent. Run via:
# godot --headless --script res://tools/setup_panel_buttons.gd

func _build_panel_buttons() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PanelButtons"
	layer.set_script(load("res://scripts/panel_buttons.gd"))

	var hbox := HBoxContainer.new()
	hbox.name = "HBox"
	hbox.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hbox.position = Vector2(-252, 12)
	hbox.add_theme_constant_override("separation", 8)
	layer.add_child(hbox)
	hbox.owner = layer

	for entry in [["InventoryBtn", "🎒"], ["CharacterBtn", "👤"], ["CraftingBtn", "🔨"], ["QuestBtn", "📜"], ["MapBtn", "🗺️"]]:
		var btn := Button.new()
		btn.name = entry[0]
		btn.text = entry[1]
		btn.custom_minimum_size = Vector2(40, 40)
		btn.add_theme_font_size_override("font_size", 18)
		hbox.add_child(btn)
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
