extends Node
# Autoload — buy/sell logic, port of shop.js. Scoped to the backpack only
# (Inventory, not pooled Storage) - a shop transaction needs physically
# carried goods, and equipped gear already lives outside the backpack in
# Character.equipment so it naturally never appears to sell.

# One shopkeeper (2026-09-12, the user's tidy-up): the TRADER sells potions,
# accessories and resources. No armour or weapon is for sale anywhere - the
# leather set and every tier are forged at the Blacksmith's bench (he is a
# quest giver and a workbench, not a shop). Resources cost RESOURCE_MARKUP x
# their value so gathering is
# always the better deal - the shop is a one-off plug for a crafting gap -
# and a biome's resource is only sold once that biome's ford is open;
# before that it shows as a locked teaser (see shop_panel.gd).
const STOCKS := {
	"village_trader": ["healing_potion", "mana_potion", "antidote", "angel_feather", "charm_of_warding", "wood", "stone", "monster_fur", "frost_shard", "ironwood", "ember_core", "bog_iron"],
}
const SHOP_STOCK := STOCKS.village_trader # (older callers)
const RESOURCE_MARKUP := 5
# The ford a resource waits for ("" = always on the shelf).
const RESOURCE_BIOME := {"monster_fur": "frostpeak", "frost_shard": "frostpeak", "ironwood": "verdantwood", "ember_core": "badlands", "bog_iron": "gloomfen"} # fur waits for the first biome too (user, 2026-09-12)
const BIOME_LABEL := {"frostpeak": "the northern ford, on Frostpeak Ridge", "verdantwood": "the eastern ford, in Verdantwood Forest", "badlands": "the southern ford, in the Emberfall Badlands", "gloomfen": "the western ford, in the Gloomfen Marsh"}
var keeper := "village_trader" # whose shop is open

signal changed

func stock_for(npc_id: String) -> Array:
	return STOCKS.get(npc_id, [])

func is_resource(item_id: String) -> bool:
	return Items.ITEMS.has(item_id) and not Items.is_equippable(item_id) and not Items.is_usable(item_id) and item_id != "gold" and item_id != "magic_crystal"

# A resource is on sale once its biome's ford is open.
func resource_available(item_id: String) -> bool:
	var biome: String = RESOURCE_BIOME.get(item_id, "")
	return biome == "" or bool(GameState.biome_paths_open.get(biome, false))

func locked_text(item_id: String) -> String:
	var biome: String = RESOURCE_BIOME.get(item_id, "")
	return "Not on the shelf yet - found beyond %s. The Trader will stock it once that ford is open." % BIOME_LABEL.get(biome, "the valley")

func buy_price(item_id: String) -> int:
	var value: int = Items.ITEMS.get(item_id, {}).get("value", 0)
	return value * RESOURCE_MARKUP if is_resource(item_id) else value

# Selling pays half the item's VALUE (not the marked-up shop price), so a
# resource sells for a tenth of what the Trader charges for it.
func sell_price(item_id: String) -> int:
	return max(1, int(floor(int(Items.ITEMS.get(item_id, {}).get("value", 0)) * 0.5)))

func buy_item(item_id: String) -> bool:
	var price := buy_price(item_id)
	if price <= 0 or Inventory.gold_available() < price or not Inventory.can_add(item_id) or not resource_available(item_id):
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
