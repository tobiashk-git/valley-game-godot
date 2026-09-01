extends Node
# Autoload — buy/sell logic, port of shop.js. Scoped to the backpack only
# (Inventory, not pooled Storage) - a shop transaction needs physically
# carried goods, and equipped gear already lives outside the backpack in
# Character.equipment so it naturally never appears to sell.

# Deliberately excludes raw materials (meant to be gathered, not bought) and
# bone_greatsword (boss-exclusive) - both still have a "value" and remain
# sellable, just never buyable here.
const SHOP_STOCK := ["healing_potion", "mana_potion", "antidote", "leather_armor", "charm_of_warding"]

signal changed

func buy_price(item_id: String) -> int:
	return Items.ITEMS.get(item_id, {}).get("value", 0)

func sell_price(item_id: String) -> int:
	return max(1, int(floor(buy_price(item_id) * 0.5)))

func buy_item(item_id: String) -> bool:
	var price := buy_price(item_id)
	if price <= 0 or Inventory.get_count("gold") < price:
		return false
	Inventory.remove_item("gold", price)
	Inventory.add_item(item_id, 1)
	changed.emit()
	return true

func sell_item(item_id: String) -> bool:
	if Inventory.get_count(item_id) <= 0:
		return false
	Inventory.remove_item(item_id, 1)
	Inventory.add_item("gold", sell_price(item_id))
	changed.emit()
	return true
