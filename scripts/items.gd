extends Node
# Autoload — item registry, port of items.js through its shop phase.
# Materials/consumables/gear all share one flat dict; gear carries a "slot"
# field (weapon/armor/accessory) so it can be equipped generically, and
# anything with a "value" field is sellable to the Trader (Shop.SHOP_STOCK
# curates what's also buyable - see shop.gd). Every entry has an "icon"
# (a single emoji, matching the JS reference's own icon convention - Godot's
# default font renders color emoji fine, confirmed via a render test) that
# get_item_name() prepends, since every one of its ~13 call sites across the
# UI is a display context that wants one.

const ITEMS := {
	"wood": {"name": "Wood", "icon": "🪵", "value": 1},
	"stone": {"name": "Stone", "icon": "🪨", "value": 1},
	"gold": {"name": "Gold", "icon": "💰"},
	"wooden_pickaxe": {"name": "Wooden Pickaxe", "icon": "⛏️", "slot": "weapon", "attack": 2, "value": 15},
	"leather_armor": {"name": "Leather Armor", "icon": "🧥", "slot": "armor", "defense": 3, "value": 20},
	"charm_of_warding": {"name": "Charm of Warding", "icon": "💍", "slot": "accessory", "bonus": {"status_resistance": 0.5}, "value": 25},
	"healing_potion": {"name": "Healing Potion", "icon": "🧪", "effect": {"kind": "heal", "amount": 15}, "value": 12},
	"mana_potion": {"name": "Mana Potion", "icon": "🔮", "effect": {"kind": "restore_mp", "amount": 8}, "value": 12},
	"antidote": {"name": "Antidote", "icon": "🌿", "effect": {"kind": "cure", "status": "poison"}, "value": 10},
	# Boss-exclusive - no recipe in crafting.gd, only obtainable as a drop.
	# Sellable for a nice payout (like the plan's boss-drop pricing), but
	# never appears in Shop.SHOP_STOCK to buy.
	"bone_greatsword": {"name": "Bone Greatsword", "icon": "🗡️", "slot": "weapon", "attack": 6, "value": 100},
	"royal_plate": {"name": "Royal Plate", "icon": "🛡️", "slot": "armor", "defense": 8, "value": 130},
	# Quest item for the altar/world-advance loop - deliberately no "value"
	# (not sellable), no "slot"/"effect" (not equippable or usable).
	"magic_crystal": {"name": "Magic Crystal", "icon": "💎"},
}

func is_usable(item_id: String) -> bool:
	return ITEMS.has(item_id) and ITEMS[item_id].has("effect")

func is_equippable(item_id: String) -> bool:
	return ITEMS.has(item_id) and ITEMS[item_id].has("slot")

func get_item_name(item_id: String) -> String:
	if ITEMS.has(item_id):
		var def: Dictionary = ITEMS[item_id]
		# Web export renders text through Godot's own rasterizer, with no
		# access to the browser's/OS's color-emoji font the way a desktop
		# build gets via native font fallback - the icon prefix rendered as
		# a blank gap on a real phone (name still showed fine, since it's
		# plain text). Desktop keeps the icon; it's confirmed working there.
		if OS.has_feature("web"):
			return def.name
		return "%s %s" % [def.icon, def.name]
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
