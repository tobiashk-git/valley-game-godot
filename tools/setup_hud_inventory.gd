extends SceneTree
# Builds HUD.tscn (always-visible top-left counters). (Used to also build
# InventoryPanel.tscn - retired by the CharacterSheet, UI redesign Phase 2.) Panel background + title styling come from the shared
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
	# Bigger than before (was 340x40 with 18px icons/14px font) - read as too
	# small specifically on a high-DPI phone screen: window/stretch/aspect=
	# "keep_width" keeps the game's *logical* width fixed at 800 units
	# regardless of the device's pixel density, so on a high-DPR phone each
	# unit maps to fewer physical on-screen pixels than the same 800 units
	# would on a standard-DPI desktop - everything at a fixed size in game
	# units ends up physically smaller the higher the screen's DPI.
	# Narrower than the original 440 (user feedback: too much empty space)
	# - just wide enough for the three counters plus a biome name that wraps
	# onto a second line. Height here is only a starting value: hud.gd
	# re-fits it to the content every frame. Whatever it works out to has to
	# stay ABOVE y=148: BattlePanel's 480x400 panel sits at y=148..548 in the
	# 800x600 base viewport (pushed down from the centred y=100 specifically
	# to make room for this column) and draws above this layer (later
	# autoload, same CanvasLayer.layer), so the column stays fully visible
	# mid-fight only as long as this panel ends above it - verified by
	# tools/verify_hud_bars.gd with the longest biome name.
	panel.size = Vector2(320, 120)
	layer.add_child(panel)
	panel.owner = layer

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 8)
	panel.add_child(margin)
	margin.owner = layer

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)
	vbox.owner = layer

	var hbox := HBoxContainer.new()
	hbox.name = "HBox"
	hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(hbox)
	hbox.owner = layer

	# No resource counters any more (wood/stone, then gold, went 2026-09-06 -
	# "just keep location": the backpack lists every material and the gold).
	# Current location (replaced the old "World N" indicator, per user
	# feedback): the biome under the player on the overworld, a fixed name
	# inside interiors - set by hud.gd. Takes whatever width the counters
	# leave and word-wraps, so "Emberfall Badlands" becomes two lines rather
	# than forcing the panel wider.
	var location_label := Label.new()
	location_label.name = "LocationLabel"
	location_label.theme_type_variation = &"DimLabel"
	location_label.add_theme_font_size_override("font_size", 16)
	location_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	location_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	location_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(location_label)
	location_label.owner = layer

	# HP bar over MP bar, spanning the (now narrow) panel so they read as a
	# column running down the left side under the counters, plus an effects
	# line beneath (active statuses, e.g. "Poison (3)") - all always
	# visible, so the battle screen no longer needs its own copies (see
	# setup_battle_panel.gd). Same HPBar/MPBar theme variations +
	# centred-label-in-bar shape the Character panel and enemy slots use.
	# The XP bar (gold, slimmer, "Level 2  4 / 60 XP") sits under the MP bar;
	# the battle panel starts at y=164 to leave it room with a two-line
	# biome name.
	for entry in [["HP", &"HPBar", 18, 13], ["MP", &"MPBar", 18, 13], ["XP", &"XPBar", 14, 11]]:
		var prefix: String = entry[0]
		var bar := ProgressBar.new()
		bar.name = prefix + "Bar"
		bar.custom_minimum_size = Vector2(0, entry[2])
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.show_percentage = false
		bar.theme_type_variation = entry[1]
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(bar)
		bar.owner = layer

		var bar_label := Label.new()
		bar_label.name = prefix + "Label"
		bar_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bar_label.add_theme_font_size_override("font_size", entry[3])
		bar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(bar_label)
		bar_label.owner = layer

	# Effects line - text/variation set at runtime by hud.gd ("No effects"
	# dimmed, or the active statuses with turns left).
	var status_label := Label.new()
	status_label.name = "StatusLabel"
	status_label.theme_type_variation = &"DimLabel"
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(status_label)
	status_label.owner = layer

	var packed := PackedScene.new()
	packed.pack(layer)
	var err := ResourceSaver.save(packed, "res://scenes/HUD.tscn")
	print("HUD.tscn saved: ", err)

func _initialize() -> void:
	print("=== HUD setup starting ===")
	_build_hud()
	print("=== Setup complete ===")
	quit()
