extends SceneTree
# Builds DialogueUI.tscn — a simple bottom-anchored dialogue box. Panel
# background + label styling come from the shared res://resources/
# ui_theme.tres (project default theme) - see tools/setup_theme.gd.
# Run via: godot --headless --script res://tools/setup_dialogue_ui.gd

func _initialize() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DialogueUI"
	layer.set_script(load("res://scripts/dialogue_ui.gd"))

	var panel := Panel.new()
	panel.name = "Panel"
	# Top-anchored (was bottom-anchored) - a bottom sheet sat low enough to
	# crowd the touch joystick/interact button on a phone's much-taller
	# expanded viewport (window/stretch/aspect="keep_width"), and read as
	# "too low on the screen" even on desktop. 60px top margin clears the
	# always-visible PanelButtons toolbar row (y 12-52), matching every
	# other top-anchored overlay (QuestTracker, the 5 big panels). Then moved
	# down again to 152: the HUD grew its HP/MP/effects column and now ends
	# at y<=143 (tools/verify_hud_bars.gd), and being an earlier autoload it
	# drew over this box's name and first line of text ("the quest text box
	# is partially hidden by the health bar box" - user, phone/iPad test).
	# Same clearance the battle panel uses (setup_battle_panel.gd).
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_top = 152
	panel.offset_bottom = 372
	panel.offset_left = 40
	panel.offset_right = -40
	layer.add_child(panel)
	panel.owner = layer

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 12)
	panel.add_child(margin)
	margin.owner = layer

	# Portrait (bust of the speaker, dialogue_ui.gd's PORTRAITS by speaker
	# name) at the left of the text column; hidden when the speaker has no
	# portrait file so the text takes the full width.
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	row.owner = layer

	var frame := Panel.new()
	frame.name = "PortraitFrame"
	frame.theme_type_variation = &"DetailPanel"
	frame.custom_minimum_size = Vector2(96, 96)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(frame)
	frame.owner = layer

	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.offset_left = 4
	portrait.offset_top = 4
	portrait.offset_right = -4
	portrait.offset_bottom = -4
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	frame.add_child(portrait)
	portrait.owner = layer

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(vbox)
	vbox.owner = layer

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.theme_type_variation = &"PanelTitle"
	name_label.add_theme_font_size_override("font_size", 24) # was 20 - readability pass
	vbox.add_child(name_label)
	name_label.owner = layer

	# RichTextLabel (not Label) so quest-progress text ("3/5 [icon] Wood")
	# can embed an inline item icon via BBCode - see Quests.
	# objective_progress_text().
	var text_label := RichTextLabel.new()
	text_label.name = "TextLabel"
	text_label.bbcode_enabled = true
	text_label.fit_content = true
	text_label.scroll_active = false
	text_label.add_theme_font_size_override("normal_font_size", 20) # was 16
	vbox.add_child(text_label)
	text_label.owner = layer

	var hint_label := Label.new()
	hint_label.name = "HintLabel"
	hint_label.text = "Press E to close"
	hint_label.theme_type_variation = &"DimLabel"
	hint_label.add_theme_font_size_override("font_size", 15) # was 12
	vbox.add_child(hint_label)
	hint_label.owner = layer

	# Built dynamically by dialogue_ui.gd for quest offer/turn-in choices;
	# empty and hidden for a plain greeting (HintLabel shows instead).
	var actions_row := HBoxContainer.new()
	actions_row.name = "ActionsRow"
	actions_row.add_theme_constant_override("separation", 12)
	actions_row.custom_minimum_size = Vector2(0, 52)
	actions_row.visible = false
	vbox.add_child(actions_row)
	actions_row.owner = layer

	var packed := PackedScene.new()
	packed.pack(layer)
	var err := ResourceSaver.save(packed, "res://scenes/DialogueUI.tscn")
	print("DialogueUI.tscn saved: ", err)
	quit()
