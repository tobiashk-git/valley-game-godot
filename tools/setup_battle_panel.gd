extends SceneTree
# Builds BattlePanel.tscn — full-screen battle UI (Combat Phase 1-4: Attack/
# Magic/Item/Defend/Run, up to 3 targetable enemy slots). Panel background/
# title/bar styling come from the shared res://resources/ui_theme.tres
# (project default theme) - see tools/setup_theme.gd. Run via:
# godot --headless --script res://tools/setup_battle_panel.gd

const MAX_ENEMY_SLOTS := 3

func _bar_with_label(name_prefix: String, variation: StringName) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = name_prefix + "Bar"
	bar.custom_minimum_size = Vector2(0, 22)
	bar.show_percentage = false
	bar.theme_type_variation = variation
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.name = name_prefix + "Label"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(label)
	return bar

# A clickable per-enemy slot: sprite + name + HP bar. Children are set to
# MOUSE_FILTER_IGNORE so clicks pass through to the slot's own gui_input
# (connected in battle_panel.gd), which calls Combat.select_target(index).
func _build_enemy_slot(index: int) -> VBoxContainer:
	var slot := VBoxContainer.new()
	slot.name = "EnemySlot%d" % index
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.add_theme_constant_override("separation", 4)

	var sprite := TextureRect.new()
	sprite.name = "Sprite"
	sprite.custom_minimum_size = Vector2(48, 48)
	sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(sprite)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(name_label)

	var hp_bar := _bar_with_label("HP", &"HPBar")
	hp_bar.custom_minimum_size = Vector2(0, 16)
	slot.add_child(hp_bar)

	return slot

func _own(node: Node, layer: Node) -> void:
	for child in node.get_children():
		child.owner = layer
		_own(child, layer)

func _build_battle_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "BattlePanel"
	layer.set_script(load("res://scripts/battle_panel.gd"))

	var panel := Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	# Was centred (y offset -200 -> y=100..500 in the 800x600 base viewport);
	# pushed down 40px so the top-left HUD column (counters + HP/MP bars +
	# effects line, ends at y=136 - see setup_hud_inventory.gd) stays fully
	# uncovered mid-fight. On a phone (keep_width, much taller viewport) the
	# panel is far lower still, so only the desktop layout was ever tight.
	panel.position = Vector2(-240, -160)
	panel.size = Vector2(480, 400)
	layer.add_child(panel)
	panel.owner = layer

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Up to 3 enemy slots, side by side - shown/hidden and made targetable
	# by battle_panel.gd based on Combat.current_enemies/selecting_target.
	var enemies_row := HBoxContainer.new()
	enemies_row.name = "EnemiesRow"
	enemies_row.add_theme_constant_override("separation", 10)
	vbox.add_child(enemies_row)

	for i in range(MAX_ENEMY_SLOTS):
		enemies_row.add_child(_build_enemy_slot(i))

	# No player row any more: the player's HP/MP bars and the active-status
	# badges (poison/paralysis/sleep/confusion/silence) used to sit here
	# between the enemies and the log, but now live in the always-visible
	# HUD (top-left column, see setup_hud_inventory.gd/hud.gd) which stays
	# uncovered while this panel is up - duplicating them here was redundant
	# (user feedback).

	# Battle log.
	var log_panel := PanelContainer.new()
	log_panel.name = "LogPanel"
	log_panel.custom_minimum_size = Vector2(0, 110)
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(log_panel)

	var log_label := Label.new()
	log_label.name = "LogLabel"
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	log_label.add_theme_font_size_override("font_size", 14)
	log_panel.add_child(log_label)

	# Commands.
	var commands := HBoxContainer.new()
	commands.name = "Commands"
	commands.add_theme_constant_override("separation", 8)
	vbox.add_child(commands)

	for entry in [["AttackBtn", "Attack"], ["MagicBtn", "Magic"], ["ItemBtn", "Item"], ["DefendBtn", "Defend"], ["RunBtn", "Run"]]:
		var btn := Button.new()
		btn.name = entry[0]
		btn.text = entry[1]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		commands.add_child(btn)

	# Submenu (Magic/Item row list + Back), built dynamically by
	# battle_panel.gd - hidden and empty at build time.
	var submenu := VBoxContainer.new()
	submenu.name = "Submenu"
	submenu.add_theme_constant_override("separation", 4)
	submenu.visible = false
	vbox.add_child(submenu)

	_own(panel, layer)

	var packed := PackedScene.new()
	packed.pack(layer)
	var err := ResourceSaver.save(packed, "res://scenes/BattlePanel.tscn")
	print("BattlePanel.tscn saved: ", err)

func _initialize() -> void:
	print("=== Battle panel setup starting ===")
	_build_battle_panel()
	print("=== Setup complete ===")
	quit()
