extends Node
# Autoload — named storage containers (chests), port of storage.js. Each
# storage is a plain item_id -> count Dictionary, same shape as Inventory's
# backpack.

signal changed

var storages: Dictionary = {
	"house_chest": {},
}

func get_storage(storage_id: String) -> Dictionary:
	if not storages.has(storage_id):
		storages[storage_id] = {}
	return storages[storage_id]

func add_item(storage_id: String, item_id: String, amount: int) -> void:
	var storage: Dictionary = get_storage(storage_id)
	storage[item_id] = storage.get(item_id, 0) + amount
	changed.emit()

func remove_item(storage_id: String, item_id: String, amount: int) -> bool:
	var storage: Dictionary = get_storage(storage_id)
	if storage.get(item_id, 0) < amount:
		return false
	storage[item_id] -= amount
	if storage[item_id] <= 0:
		storage.erase(item_id)
	changed.emit()
	return true

func get_count(storage_id: String, item_id: String) -> int:
	return get_storage(storage_id).get(item_id, 0)
