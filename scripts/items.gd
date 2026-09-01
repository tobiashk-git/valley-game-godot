extends Node
# Autoload — item registry, port of items.js through its Phase 5 (equipment
# stats). Materials/consumables/gear all share one flat dict; gear carries a
# "slot" field (weapon/armor/accessory) so it can be equipped generically.

const ITEMS := {
	"wood": {"name": "Wood"},
	"stone": {"name": "Stone"},
	"gold": {"name": "Gold"},
	"wooden_pickaxe": {"name": "Wooden Pickaxe", "slot": "weapon", "attack": 2},
	"leather_armor": {"name": "Leather Armor", "slot": "armor", "defense": 3},
	"charm_of_warding": {"name": "Charm of Warding", "slot": "accessory", "bonus": {"status_resistance": 0.5}},
	"healing_potion": {"name": "Healing Potion", "effect": {"kind": "heal", "amount": 15}},
	"mana_potion": {"name": "Mana Potion", "effect": {"kind": "restore_mp", "amount": 8}},
	"antidote": {"name": "Antidote", "effect": {"kind": "cure", "status": "poison"}},
}

func is_usable(item_id: String) -> bool:
	return ITEMS.has(item_id) and ITEMS[item_id].has("effect")

func is_equippable(item_id: String) -> bool:
	return ITEMS.has(item_id) and ITEMS[item_id].has("slot")

func get_item_name(item_id: String) -> String:
	if ITEMS.has(item_id):
		return ITEMS[item_id].name
	return item_id

# One-line gear stat suffix for UI rows, e.g. "Attack +2", "Defense +3",
# "Status Resistance +50%". Empty string for non-gear.
func describe_stats(item_id: String) -> String:
	var def: Dictionary = ITEMS.get(item_id, {})
	if def.has("attack"):
		return "Attack +%d" % def.attack
	if def.has("defense"):
		return "Defense +%d" % def.defense
	if def.has("bonus"):
		var parts: Array = []
		for key in def.bonus.keys():
			parts.append("%s +%d%%" % [key.capitalize(), int(round(def.bonus[key] * 100))])
		var text := ""
		for i in range(parts.size()):
			if i > 0:
				text += ", "
			text += parts[i]
		return text
	return ""
