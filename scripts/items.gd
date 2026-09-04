extends Node
# Autoload — item registry, port of items.js through its shop phase.
# Materials/consumables/gear all share one flat dict; gear carries a "slot"
# field (weapon/armor/accessory) so it can be equipped generically, and
# anything with a "value" field is sellable to the Trader (Shop.SHOP_STOCK
# curates what's also buyable - see shop.gd). Every entry has an "icon" (a
# single emoji) which is NOT used for display directly anymore - Godot's Web
# export can't render it (no access to the browser's/OS's color-emoji font
# the way a desktop build gets via native font fallback). Display now goes
# through get_item_icon()/get_item_name_bbcode() (real generated textures,
# res://assets/icons/ - see tools/setup_item_icons.gd), which work
# identically on every platform; get_item_name() is now plain text only.

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
	# First resource drop from the overworld's static farmable wild monsters
	# (see wild_monster.gd) - a placeholder single resource type for now, more
	# variety and crafting uses planned later. Sellable at the same basic-
	# material tier as wood/stone.
	"monster_fur": {"name": "Monster Fur", "icon": "🧶", "value": 4},
}

func is_usable(item_id: String) -> bool:
	return ITEMS.has(item_id) and ITEMS[item_id].has("effect")

# Applies a usable item's effect to the player WITHOUT touching the
# inventory - the caller decides whether the item is consumed (Combat always
# spends it, the turn is used either way; the out-of-combat QuickBar only
# spends it when something actually happened). Shared so a potion heals the
# same amount and prints the same line whether tapped mid-fight or in the
# field. Returns {"message": String, "applied": bool}.
func apply_effect(item_id: String) -> Dictionary:
	var def: Dictionary = ITEMS.get(item_id, {})
	var effect: Dictionary = def.get("effect", {})
	if effect.is_empty():
		return {"message": "", "applied": false}
	if effect.kind == "heal":
		var healed: int = min(effect.amount, Character.stats.max_hp - Character.stats.hp)
		Character.stats.hp += healed
		return {"message": "Oliver uses %s and recovers %d HP!" % [def.name, healed], "applied": healed > 0}
	if effect.kind == "restore_mp":
		var restored: int = min(effect.amount, Character.stats.max_mp - Character.stats.mp)
		Character.stats.mp += restored
		return {"message": "Oliver uses %s and recovers %d MP!" % [def.name, restored], "applied": restored > 0}
	if effect.kind == "cure":
		if Combat.player_status.has(effect.status):
			var status_name: String = Statuses.STATUSES[effect.status].name
			Combat.player_status.erase(effect.status)
			return {"message": "Oliver uses %s and cures %s!" % [def.name, status_name], "applied": true}
		return {"message": "Oliver uses %s, but wasn't affected." % def.name, "applied": false}
	return {"message": "", "applied": false}

func is_equippable(item_id: String) -> bool:
	return ITEMS.has(item_id) and ITEMS[item_id].has("slot")

# A small generated placeholder icon (res://assets/icons/, see
# tools/setup_item_icons.gd) - not the LPC pixel-art pipeline's polish, just
# a real, distinct, cross-platform-renderable texture standing in for the
# emoji that couldn't render on Web export.
func get_item_icon(item_id: String) -> Texture2D:
	if ITEMS.has(item_id):
		return load("res://assets/icons/%s.png" % item_id)
	return null

# Same idea as get_item_name(), but for RichTextLabel/BBCode contexts
# (bbcode_enabled = true) that can embed the icon inline within otherwise-
# plain text - used where a single Label needs to show more than one item's
# name+icon in the same line (e.g. Crafting's "Axe (3 Wood, 2 Stone)").
func get_item_name_bbcode(item_id: String) -> String:
	if ITEMS.has(item_id):
		return "[img=18x18]res://assets/icons/%s.png[/img] %s" % [item_id, ITEMS[item_id].name]
	return item_id

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
