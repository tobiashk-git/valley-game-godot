extends Node
# Autoload — minimal item registry, port of the start of items.js. Just
# enough items to prove the inventory/gathering pipeline end to end; the
# full item roster (potions, gear, etc.) is a later increment.

const ITEMS := {
	"wood": {"name": "Wood"},
	"stone": {"name": "Stone"},
	"gold": {"name": "Gold"},
	"wooden_pickaxe": {"name": "Wooden Pickaxe", "attack": 2},
	"healing_potion": {"name": "Healing Potion", "effect": {"kind": "heal", "amount": 15}},
	"mana_potion": {"name": "Mana Potion", "effect": {"kind": "restore_mp", "amount": 8}},
	"antidote": {"name": "Antidote", "effect": {"kind": "cure", "status": "poison"}},
}

func is_usable(item_id: String) -> bool:
	return ITEMS.has(item_id) and ITEMS[item_id].has("effect")

func get_item_name(item_id: String) -> String:
	if ITEMS.has(item_id):
		return ITEMS[item_id].name
	return item_id
