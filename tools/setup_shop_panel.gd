extends SceneTree
# Builds ShopPanel.tscn (opened by a shop:true npc.gd, closed with E).
# Panel background/title/tab-button styling come from the shared
# res://resources/ui_theme.tres (project default theme) - see
# tools/setup_theme.gd. Run via:
# godot --headless --script res://tools/setup_shop_panel.gd

func _build_shop_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ShopPanel"
	layer.set_script(load("res://scripts/shop_panel.gd"))

	var panel := Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-190, -150)
	panel.size = Vector2(380, 300)
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
	title.text = "Village Trader"
	title.theme_type_variation = &"PanelTitle"
	vbox.add_child(title)
	title.owner = layer

	var gold_label := Label.new()
	gold_label.name = "GoldLabel"
	gold_label.theme_type_variation = &"DimLabel"
	gold_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(gold_label)
	gold_label.owner = layer

	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation", 8)
	vbox.add_child(tabs)
	tabs.owner = layer

	var buy_tab_btn := Button.new()
	buy_tab_btn.name = "BuyTabBtn"
	buy_tab_btn.text = "Buy"
	tabs.add_child(buy_tab_btn)
	buy_tab_btn.owner = layer

	var sell_tab_btn := Button.new()
	sell_tab_btn.name = "SellTabBtn"
	sell_tab_btn.text = "Sell"
	tabs.add_child(sell_tab_btn)
	sell_tab_btn.owner = layer

	var list := VBoxContainer.new()
	list.name = "List"
	list.add_theme_constant_override("separation", 6)
	vbox.add_child(list)
	list.owner = layer

	var packed := PackedScene.new()
	packed.pack(layer)
	var err := ResourceSaver.save(packed, "res://scenes/ShopPanel.tscn")
	print("ShopPanel.tscn saved: ", err)

func _initialize() -> void:
	print("=== Shop panel setup starting ===")
	_build_shop_panel()
	print("=== Setup complete ===")
	quit()
