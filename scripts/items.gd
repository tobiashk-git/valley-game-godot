extends Node
# Autoload — minimal item registry, port of the start of items.js. Just
# enough items to prove the inventory/gathering pipeline end to end; the
# full item roster (potions, gear, etc.) is a later increment.

const ITEMS := {
	"wood": {"name": "Wood"},
	"stone": {"name": "Stone"},
	"gold": {"name": "Gold"},
	"wooden_pickaxe": {"name": "Wooden Pickaxe"},
}

func get_item_name(item_id: String) -> String:
	if ITEMS.has(item_id):
		return ITEMS[item_id].name
	return item_id
