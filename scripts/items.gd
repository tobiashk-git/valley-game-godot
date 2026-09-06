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

# "desc": one line of flavour + function for the character sheet's detail
# pane (UI redesign Phase 1). Keep them short - the pane wraps at ~220px.
const ITEMS := {
	"wood": {"name": "Wood", "icon": "🪵", "value": 1, "desc": "Split valley timber. The basis of most things worth crafting."},
	"stone": {"name": "Stone", "icon": "🪨", "value": 1, "desc": "Rough grey fieldstone, chipped from the outcrops around the village."},
	"gold": {"name": "Gold", "icon": "💰", "desc": "Coin of the realm. The Trader takes nothing else."},
	"wooden_pickaxe": {"name": "Wooden Pickaxe", "icon": "⛏️", "slot": "weapon", "attack": 2, "value": 15, "desc": "Crude but hefty. Better than bare fists, and handy for prying at rock."},
	"leather_armor": {"name": "Leather Armor", "icon": "🧥", "slot": "armor", "layer": "res://assets/armour_layers/leather_armor.png", "defense": 3, "value": 20, "desc": "Stiff boiled hide over a padded jerkin. Turns a claw or two."},
	"charm_of_warding": {"name": "Charm of Warding", "icon": "💍", "slot": "accessory", "bonus": {"status_resistance": 0.5}, "value": 25, "desc": "A ring of braided copper and bone. Poison and curses bite less often."},
	"healing_potion": {"name": "Healing Potion", "icon": "🧪", "effect": {"kind": "heal", "amount": 8}, "value": 20, "desc": "A bitter red draught brewed from valley herbs. Restores 8 HP. You can carry five."},
	"mana_potion": {"name": "Mana Potion", "icon": "🔮", "effect": {"kind": "restore_mp", "amount": 8}, "value": 12, "desc": "Cold blue and faintly humming. Restores 8 MP."},
	"antidote": {"name": "Antidote", "icon": "🌿", "effect": {"kind": "cure", "status": "poison"}, "value": 10, "desc": "Crushed marsh-leaf in spirit. Cures poison."},
	# The way home. Fast travel only leaves from Oliver's house, so a trip
	# ends either back on foot, by feather, or with a nap that costs the
	# pack. Sold by the Trader; a rare drop from any wild monster.
	"angel_feather": {"name": "Angel Feather", "icon": "🪶", "effect": {"kind": "escape"}, "value": 25, "desc": "A single white feather, warm to the touch. Use it anywhere - even mid-fight - and you're home by your bed in a heartbeat."},
	# Boss-exclusive - no recipe in crafting.gd, only obtainable as a drop.
	# Sellable for a nice payout (like the plan's boss-drop pricing), but
	# never appears in Shop.SHOP_STOCK to buy.
	"bone_greatsword": {"name": "Bone Greatsword", "icon": "🗡️", "slot": "weapon", "attack": 6, "value": 100, "desc": "Hewn from the Bone Lord's own femur. Unnervingly light for its size."},
	"royal_plate": {"name": "Royal Plate", "icon": "🛡️", "slot": "armor", "layer": "res://assets/armour_layers/royal_plate.png", "defense": 8, "value": 130, "desc": "The Royal Wraith's ceremonial plate, still faintly cold to the touch."},
	# Quest item for the altar/world-advance loop - deliberately no "value"
	# (not sellable), no "slot"/"effect" (not equippable or usable).
	"magic_crystal": {"name": "Magic Crystal", "icon": "💎", "desc": "It hums against your palm. The village altar wants these."},
	# First resource drop from the overworld's static farmable wild monsters
	# (see wild_monster.gd) - a placeholder single resource type for now, more
	# variety and crafting uses planned later. Sellable at the same basic-
	# material tier as wood/stone.
	"monster_fur": {"name": "Monster Fur", "icon": "🧶", "value": 4, "desc": "Coarse pelt from the wilds beyond the river. Lines armour well - see Crafting."},
	# --- Gear tiers per biome (item progression). Each outer biome's
	# monsters drop a material (chance drop, see enemies.gd) that crafts
	# that biome's weapon and armour; tiers climb Frostpeak -> Verdantwood
	# -> Badlands (ember cores, shared with the Ember-forged enhancement) ->
	# Gloomfen. "tier" orders them in the Crafting tab. Icons are drawn
	# placeholders until painted ones replace them. ---
	"frost_shard": {"name": "Frost Shard", "icon": "❄️", "value": 6, "desc": "A sliver of never-melting ice from Frostpeak's creatures. Cold enough to work like steel."},
	"ironwood": {"name": "Ironwood", "icon": "🪵", "value": 8, "desc": "Heartwood from Verdantwood's corrupted growth. Dense as metal and just as hard to cut."},
	"bog_iron": {"name": "Bog Iron", "icon": "⚙️", "value": 10, "desc": "Lumps of rust-black iron dredged from Gloomfen's things. Smelts dark and heavy."},
	"frost_pick": {"name": "Frost Pick", "icon": "⛏️", "slot": "weapon", "attack": 4, "tier": 1, "value": 40, "desc": "A pick headed with frost shard. Bites deep and numbs what it hits."},
	"frostweave_coat": {"name": "Frostweave Coat", "icon": "🧥", "slot": "armor", "layer": "res://assets/armour_layers/frostweave_coat.png", "defense": 5, "tier": 1, "value": 45, "desc": "Fur coat stitched through with frost shard thread. Stiff, warm, and hard to claw."},
	"ironwood_blade": {"name": "Ironwood Blade", "icon": "🗡️", "slot": "weapon", "attack": 6, "tier": 2, "value": 60, "desc": "A sword carved from a single ironwood bough and honed on stone."},
	"ironwood_mail": {"name": "Ironwood Mail", "icon": "🛡️", "slot": "armor", "layer": "res://assets/armour_layers/ironwood_mail.png", "defense": 7, "tier": 2, "value": 65, "desc": "Ironwood scales sewn over fur. Lighter than it looks."},
	"ember_blade": {"name": "Ember Blade", "icon": "🔥", "slot": "weapon", "attack": 8, "tier": 3, "value": 85, "desc": "Ironwood forged around two ember cores. The edge never quite cools."},
	"ember_plate": {"name": "Ember Plate", "icon": "🛡️", "slot": "armor", "layer": "res://assets/armour_layers/ember_plate.png", "defense": 9, "tier": 3, "value": 90, "desc": "Fur-backed plate quenched in ember core. Warm to wear, worse to bite."},
	"bogiron_cleaver": {"name": "Bog-iron Cleaver", "icon": "🪓", "slot": "weapon", "attack": 10, "tier": 4, "value": 110, "desc": "A brutal cleaver of Gloomfen bog iron, ember-tempered. Nothing in the valley shrugs it off."},
	"bogiron_harness": {"name": "Bog-iron Harness", "icon": "🛡️", "slot": "armor", "layer": "res://assets/armour_layers/bogiron_harness.png", "defense": 11, "tier": 4, "value": 120, "desc": "Bog iron plates on a fur harness. Heavy, dark, and the best the valley makes."},

	# --- Armour sets: head / legs / feet per tier (helm, greaves, boots),
	# starter cap and boots at the Trader. Each carries an LPC walk layer.
	"leather_cap": {"name": "Leather Cap", "icon": "🛡️", "slot": "head", "layer": "res://assets/armour_layers/leather_cap.png", "defense": 1, "value": 15, "desc": "A stiff hide cap. Better than hair."},
	"leather_boots": {"name": "Leather Boots", "icon": "🛡️", "slot": "feet", "layer": "res://assets/armour_layers/leather_boots.png", "defense": 1, "value": 15, "desc": "Soft boots with a hard sole. Keeps the thorns out."},
	"frost_helm": {"name": "Frost Helm", "icon": "🛡️", "slot": "head", "layer": "res://assets/armour_layers/frost_helm.png", "defense": 2, "tier": 1, "value": 30, "desc": "A kettle helm rimmed with frost shard. Cold on the brow, colder on a claw."},
	"frost_greaves": {"name": "Frost Greaves", "icon": "🛡️", "slot": "legs", "layer": "res://assets/armour_layers/frost_greaves.png", "defense": 2, "tier": 1, "value": 30, "desc": "Fur leggings stiffened with frost shard plates."},
	"frost_boots": {"name": "Frost Boots", "icon": "🛡️", "slot": "feet", "layer": "res://assets/armour_layers/frost_boots.png", "defense": 1, "tier": 1, "value": 20, "desc": "Fur boots with frost shard toes. Sure-footed on ice."},
	"ironwood_helm": {"name": "Ironwood Helm", "icon": "🛡️", "slot": "head", "layer": "res://assets/armour_layers/ironwood_helm.png", "defense": 3, "tier": 2, "value": 45, "desc": "A close helm carved from ironwood. Light as a hat, hard as iron."},
	"ironwood_greaves": {"name": "Ironwood Greaves", "icon": "🛡️", "slot": "legs", "layer": "res://assets/armour_layers/ironwood_greaves.png", "defense": 2, "tier": 2, "value": 45, "desc": "Ironwood scales over fur leggings."},
	"ironwood_boots": {"name": "Ironwood Boots", "icon": "🛡️", "slot": "feet", "layer": "res://assets/armour_layers/ironwood_boots.png", "defense": 2, "tier": 2, "value": 35, "desc": "Ironwood-shod boots. The bark never wears through."},
	"ember_helm": {"name": "Ember Helm", "icon": "🛡️", "slot": "head", "layer": "res://assets/armour_layers/ember_helm.png", "defense": 3, "tier": 3, "value": 60, "desc": "A dark helm with ember seams that never cool."},
	"ember_greaves": {"name": "Ember Greaves", "icon": "🛡️", "slot": "legs", "layer": "res://assets/armour_layers/ember_greaves.png", "defense": 3, "tier": 3, "value": 60, "desc": "Ember-quenched plates over fur. Warm to wear."},
	"ember_boots": {"name": "Ember Boots", "icon": "🛡️", "slot": "feet", "layer": "res://assets/armour_layers/ember_boots.png", "defense": 2, "tier": 3, "value": 50, "desc": "Plate boots quenched in ember core. Leave faint scorch marks."},
	"bogiron_helm": {"name": "Bog-iron Helm", "icon": "🛡️", "slot": "head", "layer": "res://assets/armour_layers/bogiron_helm.png", "defense": 4, "tier": 4, "value": 80, "desc": "A rust-black helm of Gloomfen iron. Nothing gets through."},
	"bogiron_greaves": {"name": "Bog-iron Greaves", "icon": "🛡️", "slot": "legs", "layer": "res://assets/armour_layers/bogiron_greaves.png", "defense": 4, "tier": 4, "value": 80, "desc": "Bog iron plates strapped over fur. Heavy and dark."},
	"bogiron_boots": {"name": "Bog-iron Boots", "icon": "🛡️", "slot": "feet", "layer": "res://assets/armour_layers/bogiron_boots.png", "defense": 3, "tier": 4, "value": 70, "desc": "Bog iron boots. The best the valley makes."},
	# Enhancement ingredient (Crafting.ENHANCEMENTS): a chance drop from the
	# three Badlands species, so hunting a specific monster has a point.
	"ember_core": {"name": "Ember Core", "icon": "🔥", "value": 15, "desc": "Still warm. Cut from the heart of a Badlands beast - temper a blade in it."},
}

# --- Gear instances (see inventory.gd): a piece of gear is {"uid", "base",
# "mods"}; mods are enhancement entries {id, label, kind, value} that add to
# the base item's stats. ---

# "Fur-lined Leather Armor" - enhancement labels prefix the base name.
func instance_name(inst: Dictionary) -> String:
	var name: String = get_item_name(inst.base)
	for mod in inst.get("mods", []):
		name = "%s %s" % [mod.label, name]
	return name

# Base stat + every mod of that kind.
func instance_stat(inst: Dictionary, field: String) -> int:
	var total: int = int(ITEMS.get(inst.base, {}).get(field, 0))
	for mod in inst.get("mods", []):
		if mod.kind == field:
			total += int(mod.value)
	return total

# "Defense +3, Fur-lined +1" - base stat line plus each mod.
func describe_instance(inst: Dictionary) -> String:
	var text: String = describe_stats(inst.base)
	for mod in inst.get("mods", []):
		var part := "%s +%d" % [mod.label, mod.value]
		text = part if text == "" else "%s, %s" % [text, part]
	return text

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
	if effect.kind == "escape":
		if GameState.is_home():
			return {"message": "You're already home.", "applied": false}
		GameState.escape_home.call_deferred()
		return {"message": "A rush of wings - Oliver is carried home!", "applied": true}
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
