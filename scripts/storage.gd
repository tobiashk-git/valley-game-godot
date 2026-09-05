extends Node
# Autoload — named storage containers (chests), port of storage.js. Each
# storage holds stackables as an item_id -> count Dictionary (same shape as
# Inventory's backpack) plus, since gear became instances (UI redesign
# Phase 2), a parallel list of gear instances so an enhanced piece survives
# a chest round-trip intact.

signal changed

var storages: Dictionary = {
	"house_chest": {},
}
var gear_storages: Dictionary = {} # storage_id -> Array of gear instances

func get_storage(storage_id: String) -> Dictionary:
	if not storages.has(storage_id):
		storages[storage_id] = {}
	return storages[storage_id]

func get_gear(storage_id: String) -> Array:
	if not gear_storages.has(storage_id):
		gear_storages[storage_id] = []
	return gear_storages[storage_id]

func add_item(storage_id: String, item_id: String, amount: int) -> void:
	if Items.is_equippable(item_id):
		for i in range(amount):
			get_gear(storage_id).append(Inventory.new_instance(item_id))
		changed.emit()
		return
	var storage: Dictionary = get_storage(storage_id)
	storage[item_id] = storage.get(item_id, 0) + amount
	changed.emit()

func remove_item(storage_id: String, item_id: String, amount: int) -> bool:
	if Items.is_equippable(item_id):
		var stored: Array = get_gear(storage_id)
		var candidates: Array = stored.filter(func(inst): return inst.base == item_id)
		if candidates.size() < amount:
			return false
		for i in range(amount):
			stored.erase(candidates[i])
		changed.emit()
		return true
	var storage: Dictionary = get_storage(storage_id)
	if storage.get(item_id, 0) < amount:
		return false
	storage[item_id] -= amount
	if storage[item_id] <= 0:
		storage.erase(item_id)
	changed.emit()
	return true

func get_count(storage_id: String, item_id: String) -> int:
	if Items.is_equippable(item_id):
		return get_gear(storage_id).filter(func(inst): return inst.base == item_id).size()
	return get_storage(storage_id).get(item_id, 0)

func add_gear(storage_id: String, inst: Dictionary) -> void:
	get_gear(storage_id).append(inst)
	changed.emit()

func take_gear(storage_id: String, uid: int) -> Dictionary:
	for inst in get_gear(storage_id):
		if inst.uid == uid:
			get_gear(storage_id).erase(inst)
			changed.emit()
			return inst
	return {}

func reset() -> void:
	storages = {"house_chest": {}}
	gear_storages = {}
	changed.emit()
