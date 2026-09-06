extends Node
# Autoload — buy/sell logic, port of shop.js. Scoped to the backpack only
# (Inventory, not pooled Storage) - a shop transaction needs physically
# carried goods, and equipped gear already lives outside the backpack in
# Character.equipment so it naturally never appears to sell.

# Deliberately excludes raw materials (meant to be gathered, not bought) and
# bone_greatsword (boss-exclusive) - both still have a "value" and remain
# sellable, just never buyable here.
const SHOP_STOCK := ["healing_potion", "mana_potion", "antidote", "angel_feather", "leather_armor", "charm_of_warding"]

signal changed

func buy_price(item_id: String) -> int:
	return Items.ITEMS.get(item_id, {}).get("value", 0)

func sell_price(item_id: String) -> int:
	return max(1, int(floor(buy_price(item_id) * 0.5)))

func buy_item(item_id: String) -> bool:
	var price := buy_price(item_id)
	if price <= 0 or Inventory.gold_available() < price or not Inventory.can_add(item_id):
		return false
	Inventory.spend_gold(price)
	Inventory.add_item(item_id, 1)
	Audio.play_sfx("coin")
	changed.emit()
	return true

# By base id: for gear this sells a plain (unenhanced) copy first - see
# Inventory.remove_item(). `amount` for the shop window's "Sell all".
func sell_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or Inventory.get_count(item_id) < amount:
		return false
	Inventory.remove_item(item_id, amount)
	Inventory.add_item("gold", sell_price(item_id) * amount)
	Audio.play_sfx("coin")
	changed.emit()
	return true

# A specific carried gear instance (the shop window lists gear per piece).
# Enhanced pieces fetch the same base price.
func sell_gear(uid: int) -> bool:
	var inst: Dictionary = Inventory.take_gear(uid)
	if inst.is_empty():
		return false
	Inventory.add_item("gold", sell_price(inst.base))
	Audio.play_sfx("coin")
	changed.emit()
	return true
