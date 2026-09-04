extends KitWindow
# Autoload — a chest's contents on the character sheet's kit (UI redesign
# Phase 3). Opened by chest.gd via open_storage(id), closed with X / Esc /
# another E press (see kit_window.gd). Chest tab: what's stored -> Take out
# / Take all. Backpack tab: what's carried -> Put in chest / Put all. Gear
# is one slot per INSTANCE (moved by uid, so an enhanced piece goes into
# and out of the chest intact); stackables move one or all at a time.

var storage_id := ""

func _ready() -> void:
	super()
	Storage.changed.connect(_refresh)
	Inventory.changed.connect(_refresh)

func open_storage(id: String) -> void:
	storage_id = id
	tab = 0
	_open_window()

func close() -> void:
	super()
	storage_id = ""

func _chest_items() -> Dictionary:
	return Storage.get_storage(storage_id) if storage_id != "" else {}

func _chest_gear() -> Array:
	return Storage.get_gear(storage_id) if storage_id != "" else []

func _subtitle() -> String:
	var chest_n: int = _chest_items().size() + _chest_gear().size()
	var pack_n: int = KitWindow.backpack_entries().size()
	return "Chest: %d item%s  -  Backpack: %d item%s" % [chest_n, "" if chest_n == 1 else "s", pack_n, "" if pack_n == 1 else "s"]

func _hint() -> String:
	return "Tap something in the chest to take it out." if tab == 0 else "Tap something you carry to put it in the chest."

func _entries() -> Array:
	if tab == 1:
		return KitWindow.backpack_entries()
	var out: Array = []
	var items: Dictionary = _chest_items()
	for item_id in items.keys():
		if items[item_id] > 0:
			out.append({"id": item_id, "count": items[item_id], "inst": {}})
	for inst in _chest_gear():
		out.append({"id": inst.base, "count": 1, "inst": inst})
	return out

func _detail_actions(entry: Dictionary) -> void:
	var stack: bool = entry.inst.is_empty()
	if tab == 0:
		detail_value.text = "In the chest: %d" % entry.count if stack else "In the chest"
		primary_action.visible = true
		primary_action.text = "Take out"
		if stack and entry.count > 1:
			secondary_action.visible = true
			secondary_action.text = "Take all (%d)" % entry.count
	else:
		detail_value.text = "In your backpack: %d" % entry.count if stack else "In your backpack"
		primary_action.visible = true
		primary_action.text = "Put in chest"
		if stack and entry.count > 1:
			secondary_action.visible = true
			secondary_action.text = "Put all (%d)" % entry.count

func _on_primary() -> void:
	if selected_item == "":
		return
	if tab == 0:
		if selected_uid != 0:
			_on_withdraw_gear(selected_uid)
		else:
			_on_withdraw(selected_item)
	else:
		if selected_uid != 0:
			_on_deposit_gear(selected_uid)
		else:
			_on_deposit(selected_item)

func _on_secondary() -> void:
	if selected_item == "" or selected_uid != 0:
		return
	if tab == 0:
		_on_withdraw(selected_item, Storage.get_count(storage_id, selected_item))
	else:
		_on_deposit(selected_item, Inventory.get_count(selected_item))

func _on_withdraw(item_id: String, amount: int = 1) -> void:
	if Storage.remove_item(storage_id, item_id, amount):
		Inventory.add_item(item_id, amount)

func _on_deposit(item_id: String, amount: int = 1) -> void:
	if Inventory.remove_item(item_id, amount):
		Storage.add_item(storage_id, item_id, amount)

func _on_withdraw_gear(uid: int) -> void:
	var inst: Dictionary = Storage.take_gear(storage_id, uid)
	if not inst.is_empty():
		Inventory.add_gear_instance(inst)

func _on_deposit_gear(uid: int) -> void:
	var inst: Dictionary = Inventory.take_gear(uid)
	if not inst.is_empty():
		Storage.add_gear(storage_id, inst)
