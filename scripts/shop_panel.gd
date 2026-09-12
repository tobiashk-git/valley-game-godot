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
	# The gold line is what you shop by: bigger and in gold (user, 2026-09-08).
	subtitle_label.add_theme_font_size_override("font_size", 17)
	subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.3))
	subtitle_label.add_theme_color_override("font_outline_color", Color(0.25, 0.15, 0.02))
	subtitle_label.add_theme_constant_override("outline_size", 4)

# `keeper`: whose shop - the Trader (potions, accessories, resources) or
# the Blacksmith (armour and weapons). See Shop.STOCKS.
func open(keeper: String = "village_trader") -> void:
	Shop.keeper = keeper
	title_label.text = "Blacksmith's Forge" if keeper == "village_blacksmith" else "Trader's Shop"
	tab = 0
	_open_window()

# Resources not on sale yet show as blueprint-tinted teasers.
const TEASER_TINT := Color(0.55, 0.7, 1.0, 1.0)

func _locked(item_id: String) -> bool:
	return tab == 0 and Shop.is_resource(item_id) and not Shop.resource_available(item_id)

func _decorate_slot(btn: Button, entry: Dictionary) -> void:
	if _locked(entry.id):
		for key in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
			btn.add_theme_color_override(key, TEASER_TINT)
		btn.modulate.a = 0.6

func _subtitle() -> String:
	var banked: int = Storage.get_count(Inventory.BANK_CHEST, "gold")
	return "Gold on hand: %d" % Inventory.get_count("gold") + ("  -  banked: %d" % banked if banked > 0 else "")

func _hint() -> String:
	if tab == 0:
		return "Tap an item to see it. Prices are per item; resources cost far more than gathering them. Faded ones come later." if Shop.keeper == "village_trader" else "Tap a piece to see it. Prices are per item; the biome tiers are forged at the bench."
	return "Tap what you want to sell. Enhanced gear sells for its base price."

func _badge(entry: Dictionary) -> String:
	if tab != 0:
		return ""
	return "?" if _locked(entry.id) else "%dg" % Shop.buy_price(entry.id)

func _entries() -> Array:
	if tab == 0:
		var out: Array = []
		for item_id in Shop.stock_for(Shop.keeper):
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
		if _locked(entry.id):
			detail_value.text = Shop.locked_text(entry.id)
			return
		var price: int = Shop.buy_price(entry.id)
		var full: bool = not Inventory.can_add(entry.id)
		detail_value.text = "Costs %d gold  -  you have %d%s" % [price, owned, "  (can't carry more)" if full else ""]
		primary_action.visible = true
		primary_action.text = "Buy"
		primary_action.disabled = Inventory.gold_available() < price or full
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
