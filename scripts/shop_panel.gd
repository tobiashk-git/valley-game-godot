extends CanvasLayer
# Autoload — opened by npc.gd via shop_panel.open() (a shop:true NPC),
# closed with another E press. One-frame "just opened" guard + higher
# process_priority mirror storage_panel.gd's fix for the same close-then-
# reopen bug (an interactable's own E-press check must run before this
# panel's close-check each frame - see that file's comment for the story).

@onready var panel: Panel = $Panel
@onready var buy_tab_btn: Button = $Panel/Margin/VBox/Tabs/BuyTabBtn
@onready var sell_tab_btn: Button = $Panel/Margin/VBox/Tabs/SellTabBtn
@onready var gold_label: Label = $Panel/Margin/VBox/GoldLabel
@onready var list: VBoxContainer = $Panel/Margin/VBox/List

var _tab := "buy"
var _ignore_close_this_frame := false

func _ready() -> void:
	panel.visible = false
	process_priority = 10
	Inventory.changed.connect(_refresh)
	Shop.changed.connect(_refresh)
	buy_tab_btn.pressed.connect(_set_tab.bind("buy"))
	sell_tab_btn.pressed.connect(_set_tab.bind("sell"))

func is_open() -> bool:
	return panel.visible

func open() -> void:
	panel.visible = true
	_ignore_close_this_frame = true
	_tab = "buy"
	_refresh()

func close() -> void:
	panel.visible = false

func _set_tab(tab: String) -> void:
	_tab = tab
	_refresh()

func _add_row(label_text: String, btn_text: String, btn_disabled: bool, on_pick: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	list.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(240, 0)
	label.add_theme_font_size_override("font_size", 14)
	row.add_child(label)

	var btn := Button.new()
	btn.text = btn_text
	btn.disabled = btn_disabled
	btn.pressed.connect(on_pick)
	row.add_child(btn)

func _refresh() -> void:
	if not panel.visible:
		return
	gold_label.text = "Gold on hand: %d" % Inventory.get_count("gold")
	buy_tab_btn.disabled = _tab == "buy"
	sell_tab_btn.disabled = _tab == "sell"

	for child in list.get_children():
		child.queue_free()

	if _tab == "buy":
		for item_id in Shop.SHOP_STOCK:
			var price: int = Shop.buy_price(item_id)
			var label_text := "%s - %d gold" % [Items.get_item_name(item_id), price]
			_add_row(label_text, "Buy", Inventory.get_count("gold") < price, Shop.buy_item.bind(item_id))
	else:
		var any := false
		for item_id in Inventory.backpack.keys():
			if item_id == "gold" or not Items.ITEMS.get(item_id, {}).has("value"):
				continue
			any = true
			var price: int = Shop.sell_price(item_id)
			var label_text := "%s x%d - %d gold" % [Items.get_item_name(item_id), Inventory.backpack[item_id], price]
			_add_row(label_text, "Sell", false, Shop.sell_item.bind(item_id))
		if not any:
			var empty_label := Label.new()
			empty_label.text = "(nothing to sell)"
			empty_label.theme_type_variation = &"DimLabel"
			list.add_child(empty_label)

func _process(_delta: float) -> void:
	if not panel.visible:
		return
	if _ignore_close_this_frame:
		_ignore_close_this_frame = false
		return
	if Input.is_action_just_pressed("interact"):
		close()
