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

func add_item(item_id: String, amount: int = 1) -> void:
	if Items.is_equippable(item_id):
		for i in range(amount):
			gear.append(new_instance(item_id))
	else:
		backpack[item_id] = backpack.get(item_id, 0) + amount
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
