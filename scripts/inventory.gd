extends Node
# Autoload — the player's backpack. Port of the getResourceCount()/addItem()
# pattern used throughout items.js/game.js.
#
# Two kinds of thing live here (UI redesign Phase 2):
#   - stackables (materials, consumables, gold): `backpack` item_id -> count
#   - gear (anything Items.is_equippable): individual INSTANCES in `gear`,
#     {"uid": int, "base": item_id, "mods": [ {id, label, kind, value} ]} -
#     so an enhancement (Crafting.enhance()) has somewhere to live.
# add_item()/remove_item()/get_count() keep working for gear BY BASE ID
# (create an instance / remove one - unmodified first / count instances), so
# recipes, drops, the shop, quests and every existing caller are unchanged.

signal changed

var backpack: Dictionary = {} # item_id -> count (stackables only)
var gear: Array = [] # gear instances
var _next_uid := 1

func new_instance(base: String) -> Dictionary:
	var inst := {"uid": _next_uid, "base": base, "mods": []}
	_next_uid += 1
	return inst

# Consumables (anything with an "effect": potions, antidotes) stack to a
# cap - the balance pass made potions a small buffer, not the fight's
# engine. Materials and gold are uncapped.
const CONSUMABLE_CAP := 5

# Gold banked in the house chest counts for purchases everywhere (the chest
# is a real bank: what you deposit after a run is safe from a nap and still
# spendable). Carried gold is spent first.
const BANK_CHEST := "house_chest"

func gold_available() -> int:
	return get_count("gold") + Storage.get_count(BANK_CHEST, "gold")

func spend_gold(amount: int) -> bool:
	if gold_available() < amount:
		return false
	var carried: int = mini(amount, get_count("gold"))
	if carried > 0:
		remove_item("gold", carried)
	if amount - carried > 0:
		Storage.remove_item(BANK_CHEST, "gold", amount - carried)
	return true

# A nap costs the pack: every carried gold piece and every stackable that
# has a value (materials, potions, feathers). Worn AND spare gear stays,
# and so does anything without a value (quest items). Returns what went,
# as {item_id: amount}, for the nap panel's story.
func drop_on_defeat() -> Dictionary:
	var lost: Dictionary = {}
	for item_id in backpack.keys():
		var count: int = backpack[item_id]
		if count > 0 and (item_id == "gold" or Items.ITEMS.get(item_id, {}).has("value")):
			lost[item_id] = count
	for item_id in lost.keys():
		backpack.erase(item_id)
	if not lost.is_empty():
		changed.emit()
	return lost

func stack_cap(item_id: String) -> int:
	return CONSUMABLE_CAP if Items.is_usable(item_id) else 0

func can_add(item_id: String, amount: int = 1) -> bool:
	var cap: int = stack_cap(item_id)
	return cap == 0 or backpack.get(item_id, 0) + amount <= cap

func add_item(item_id: String, amount: int = 1) -> void:
	if Items.is_equippable(item_id):
		for i in range(amount):
			gear.append(new_instance(item_id))
	else:
		var total: int = backpack.get(item_id, 0) + amount
		var cap: int = stack_cap(item_id)
		backpack[item_id] = mini(total, cap) if cap > 0 else total
	changed.emit()

func add_gear_instance(inst: Dictionary) -> void:
	gear.append(inst)
	changed.emit()

# Gear: removes `amount` instances of that base, unmodified ones first (a
# recipe/shop transaction by base id should never eat an enhanced piece
# while a plain one is available).
func remove_item(item_id: String, amount: int = 1) -> bool:
	if Items.is_equippable(item_id):
		var candidates: Array = gear_of(item_id)
		if candidates.size() < amount:
			return false
		candidates.sort_custom(func(a, b): return a.mods.size() < b.mods.size())
		for i in range(amount):
			gear.erase(candidates[i])
		changed.emit()
		return true
	var have: int = backpack.get(item_id, 0)
	if have < amount:
		return false
	if have == amount:
		backpack.erase(item_id)
	else:
		backpack[item_id] = have - amount
	changed.emit()
	return true

func get_count(item_id: String) -> int:
	if Items.is_equippable(item_id):
		return gear_of(item_id).size()
	return backpack.get(item_id, 0)

# Instances of one base id (carried only, not worn).
func gear_of(base: String) -> Array:
	var out: Array = []
	for inst in gear:
		if inst.base == base:
			out.append(inst)
	return out

func find_gear(uid: int) -> Dictionary:
	for inst in gear:
		if inst.uid == uid:
			return inst
	return {}

# Removes and returns the instance (empty dict if not carried).
func take_gear(uid: int) -> Dictionary:
	var inst: Dictionary = find_gear(uid)
	if not inst.is_empty():
		gear.erase(inst)
		changed.emit()
	return inst

# Every carried thing as item_id -> count (gear counted by base) - for UIs
# that list the backpack by type (shop sell list, quest progress).
func all_counts() -> Dictionary:
	var counts: Dictionary = backpack.duplicate()
	for inst in gear:
		counts[inst.base] = counts.get(inst.base, 0) + 1
	return counts

func reset() -> void:
	backpack = {}
	gear = []
	_next_uid = 1
	changed.emit()
