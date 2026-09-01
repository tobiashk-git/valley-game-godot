extends SceneTree
# Builds DialogueUI.tscn — a simple bottom-anchored dialogue box.
# Run via: godot --headless --script res://tools/setup_dialogue_ui.gd

func _initialize() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DialogueUI"
	layer.set_script(load("res://scripts/dialogue_ui.gd"))

	var panel := Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -140
	panel.offset_bottom = -20
	panel.offset_left = 40
	panel.offset_right = -40
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.06, 0.92)
	style.border_color = Color(0.7, 0.55, 0.2, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	panel.owner = layer

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	panel.add_child(margin)
	margin.owner = layer

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	margin.add_child(vbox)
	vbox.owner = layer

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.35))
	name_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(name_label)
	name_label.owner = layer

	var text_label := Label.new()
	text_label.name = "TextLabel"
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(text_label)
	text_label.owner = layer

	var hint_label := Label.new()
	hint_label.name = "HintLabel"
	hint_label.text = "Press E to close"
	hint_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hint_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(hint_label)
	hint_label.owner = layer

	var packed := PackedScene.new()
	packed.pack(layer)
	var err := ResourceSaver.save(packed, "res://scenes/DialogueUI.tscn")
	print("DialogueUI.tscn saved: ", err)
	quit()
