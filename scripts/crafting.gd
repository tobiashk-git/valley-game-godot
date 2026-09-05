extends Node
# Autoload — recipe registry + crafting logic, port of crafting.js. Recipes
# stick to existing materials (wood/stone/gold) since no herb-gathering
# exists yet.

signal changed # station entered/left

const RECIPES := {
	"wooden_pickaxe": {
		"result": "wooden_pickaxe",
		"amount": 1,
		"cost": {"wood": 3, "stone": 2},
	},
	"healing_potion": {
		"result": "healing_potion",
		"amount": 1,
		"cost": {"wood": 2, "stone": 1},
	},
	"mana_potion": {
		"result": "mana_potion",
		"amount": 1,
		"cost": {"wood": 1, "stone": 2},
	},
	"antidote": {
		"result": "antidote",
		"amount": 1,
		"cost": {"wood": 2, "stone": 2},
	},
	"leather_armor": {
		"result": "leather_armor",
		"amount": 1,
		"cost": {"wood": 4, "stone": 4},
	},
	"charm_of_warding": {
		"result": "charm_of_warding",
		"amount": 1,
		"cost": {"wood": 2, "stone": 2, "gold": 5},
	},
	# --- Biome gear tiers (see items.gd): each tier's material comes from
	# that biome's monsters. Listed in tier order - the Crafting tab keeps
	# this order within its Equipment section. ---
	"frost_pick": {"result": "frost_pick", "amount": 1, "cost": {"frost_shard": 3, "wood": 2}},
	"frostweave_coat": {"result": "frostweave_coat", "amount": 1, "cost": {"frost_shard": 3, "monster_fur": 2}},
	"ironwood_blade": {"result": "ironwood_blade", "amount": 1, "cost": {"ironwood": 3, "stone": 2}},
	"ironwood_mail": {"result": "ironwood_mail", "amount": 1, "cost": {"ironwood": 3, "monster_fur": 2}},
	"ember_blade": {"result": "ember_blade", "amount": 1, "cost": {"ember_core": 2, "ironwood": 2}},
	"ember_plate": {"result": "ember_plate", "amount": 1, "cost": {"ember_core": 2, "monster_fur": 3}},
	"bogiron_cleaver": {"result": "bogiron_cleaver", "amount": 1, "cost": {"bog_iron": 3, "ember_core": 1}},
	"bogiron_harness": {"result": "bogiron_harness", "amount": 1, "cost": {"bog_iron": 3, "monster_fur": 3}},
}

# --- Enhancements (UI redesign Phase 2): a special ingredient applied to an
# existing piece of gear adds a mod (see inventory.gd's instance shape).
# `slot` says what kind of gear it fits. One enhancement per item for now -
# applying another REPLACES it (nothing can be bricked, no stacking maths
# to balance yet). ---
const ENHANCEMENTS := {
	"fur_lined": {
		"name": "Fur-lined", "slot": "armor",
		"cost": {"monster_fur": 3},
		"mod": {"kind": "defense", "value": 1},
		"desc": "Line the armour with monster pelt. +1 Defense.",
	},
	"ember_forged": {
		"name": "Ember-forged", "slot": "weapon",
		"cost": {"ember_core": 1},
		"mod": {"kind": "attack", "value": 2},
		"desc": "Temper the edge in an ember core. +2 Attack, and it runs hot.",
	},
}

# Enhancement ids that fit this instance's slot.
func enhancements_for(inst: Dictionary) -> Array:
	var slot: String = Items.ITEMS.get(inst.base, {}).get("slot", "")
	var out: Array = []
	for enh_id in ENHANCEMENTS:
		if ENHANCEMENTS[enh_id].slot == slot:
			out.append(enh_id)
	return out

func has_ingredients(cost: Dictionary) -> bool:
	for item_id in cost.keys():
		if Inventory.get_count(item_id) < cost[item_id]:
			return false
	return true

func can_enhance(inst: Dictionary, enh_id: String) -> bool:
	return station_ok() and enh_id in enhancements_for(inst) and has_ingredients(ENHANCEMENTS[enh_id].cost)

# The instance may be carried (Inventory.gear) or worn (Character.equipment);
# both are edited in place. Returns false if it isn't found / can't be done.
func find_instance(uid: int) -> Dictionary:
	var inst: Dictionary = Inventory.find_gear(uid)
	if not inst.is_empty():
		return inst
	for slot in Character.SLOTS:
		var worn: Dictionary = Character.equipped(slot)
		if not worn.is_empty() and worn.uid == uid:
			return worn
	return {}

func enhance(uid: int, enh_id: String) -> bool:
	var inst: Dictionary = find_instance(uid)
	if inst.is_empty() or not can_enhance(inst, enh_id):
		return false
	var enh: Dictionary = ENHANCEMENTS[enh_id]
	for item_id in enh.cost.keys():
		Inventory.remove_item(item_id, enh.cost[item_id])
	inst.mods = [{"id": enh_id, "label": enh.name, "kind": enh.mod.kind, "value": enh.mod.value}]
	Inventory.changed.emit()
	Character.changed.emit()
	return true

# --- Workbench. Crafting, enhancing and salvaging happen at the
# Blacksmith's bench (workbench.gd keeps `at_station` current as the
# player walks up to or away from it). `require_station` is off under a
# verify script so the older verifies' direct craft() calls keep working;
# verify scripts that test the station turn it on. ---
var require_station := true
var at_station := false
var _stations_near := 0

func _ready() -> void:
	require_station = get_tree().get_script() == null

func station_entered() -> void:
	_stations_near += 1
	at_station = true
	changed.emit()

func station_left() -> void:
	_stations_near = max(0, _stations_near - 1)
	at_station = _stations_near > 0
	changed.emit()

func station_ok() -> bool:
	return at_station or not require_station

const STATION_HINT := "Craft at the Blacksmith's workbench - the smithy on the village square."

# --- Salvage: break a carried (not worn) piece of gear back into half of
# what its recipe cost, rounded down (at least one of the first
# ingredient). Gear without a recipe - boss drops - can't be broken down. ---
const SALVAGE_FRACTION := 0.5

func salvage_yield(base_id: String) -> Dictionary:
	if not RECIPES.has(base_id):
		return {}
	var out: Dictionary = {}
	var cost: Dictionary = RECIPES[base_id].cost
	for item_id in cost.keys():
		var n: int = int(floor(cost[item_id] * SALVAGE_FRACTION))
		if n > 0:
			out[item_id] = n
	if out.is_empty():
		out[cost.keys()[0]] = 1
	return out

func can_salvage(uid: int) -> bool:
	var inst: Dictionary = Inventory.find_gear(uid) # carried only
	return not inst.is_empty() and RECIPES.has(inst.base) and station_ok()

func salvage(uid: int) -> Dictionary:
	if not can_salvage(uid):
		return {}
	var inst: Dictionary = Inventory.take_gear(uid)
	var got: Dictionary = salvage_yield(inst.base)
	for item_id in got.keys():
		Inventory.add_item(item_id, got[item_id])
	Inventory.changed.emit()
	return got

func can_craft(recipe_id: String) -> bool:
	if not station_ok():
		return false
	var recipe: Dictionary = RECIPES[recipe_id]
	var cost: Dictionary = recipe.cost
	for item_id in cost.keys():
		if Inventory.get_count(item_id) < cost[item_id]:
			return false
	return true

func craft(recipe_id: String) -> bool:
	if not can_craft(recipe_id):
		return false
	var recipe: Dictionary = RECIPES[recipe_id]
	var cost: Dictionary = recipe.cost
	for item_id in cost.keys():
		Inventory.remove_item(item_id, cost[item_id])
	Inventory.add_item(recipe.result, recipe.amount)
	return true
