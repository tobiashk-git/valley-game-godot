extends KitWindow
# Autoload — the Trader's shop on the character sheet's kit (UI redesign
# Phase 3). Opened by npc.gd via open() (a shop:true NPC), closed with X /
# Esc / another E press (see kit_window.gd). Buy tab: Shop.SHOP_STOCK as
# slots badged with their price -> Buy. Sell tab: everything carried
# (stackables, and gear one slot per INSTANCE so you pick exactly which
# piece goes - enhanced pieces still fetch base price) -> Sell / Sell all.
# Gold and unsellable items (no "value") never list.

@onready var buy_tab_btn: Button = $Window/Tabs/TabA
@onready var sell_tab_btn: Button = $Window/Tabs/TabB

func _ready() -> void:
	super()
	Inventory.changed.connect(_refresh)
	Shop.changed.connect(_refresh)

func open() -> void:
	tab = 0
	_open_window()

func _subtitle() -> String:
	return "Gold on hand: %d" % Inventory.get_count("gold")

func _hint() -> String:
	return "Tap an item to see it. Prices on the Buy tab are per item." if tab == 0 else "Tap what you want to sell. Enhanced gear sells for its base price."

func _badge(entry: Dictionary) -> String:
	return "%dg" % Shop.buy_price(entry.id) if tab == 0 else ""

func _entries() -> Array:
	if tab == 0:
		var out: Array = []
		for item_id in Shop.SHOP_STOCK:
			out.append({"id": item_id, "count": 1, "inst": {}})
		return out
	var unsellable: Array = ["gold"]
	for item_id in Inventory.backpack.keys():
		if not Items.ITEMS.get(item_id, {}).has("value"):
			unsellable.append(item_id)
	return KitWindow.backpack_entries(unsellable)

func _detail_actions(entry: Dictionary) -> void:
	var owned: int = Inventory.get_count(entry.id)
	if tab == 0:
		var price: int = Shop.buy_price(entry.id)
		detail_value.text = "Costs %d gold  -  you have %d" % [price, owned]
		primary_action.visible = true
		primary_action.text = "Buy"
		primary_action.disabled = Inventory.get_count("gold") < price
		return
	var price: int = Shop.sell_price(entry.id)
	detail_value.text = "Sells for %d gold  -  you have %d" % [price, owned]
	primary_action.visible = true
	primary_action.text = "Sell"
	if entry.inst.is_empty() and entry.count > 1:
		secondary_action.visible = true
		secondary_action.text = "Sell all (%d) for %d gold" % [entry.count, price * entry.count]

func _on_primary() -> void:
	if selected_item == "":
		return
	if tab == 0:
		Shop.buy_item(selected_item)
	elif selected_uid != 0:
		Shop.sell_gear(selected_uid)
	else:
		Shop.sell_item(selected_item)

func _on_secondary() -> void:
	if tab == 1 and selected_item != "" and selected_uid == 0:
		Shop.sell_item(selected_item, Inventory.get_count(selected_item))
