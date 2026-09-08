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
	if tab == 0:
		return "Tap something in the chest to take it out." + ("" if _is_bank() else " Or take all the loot at once.")
	return "Tap something you carry to put it in the chest." + (" Or put every resource in at once." if _is_bank() else "")

func _is_bank() -> bool:
	return storage_id == Inventory.BANK_CHEST

# Carried RESOURCES: stackables that are neither gear, nor consumables, nor
# gold, nor a quest item - what a dungeon run brings home for the bank.
func _carried_resources() -> Array:
	var out: Array = []
	for item_id in Inventory.backpack.keys():
		if Inventory.backpack[item_id] > 0 and not Items.is_equippable(item_id) and not Items.is_usable(item_id) and item_id != "gold" and item_id != "magic_crystal":
			out.append(item_id)
	return out

# The bank's backpack tab: put every resource in at once (consumables, gold
# and gear stay carried). A treasure chest's chest tab: take all the loot.
func _bulk_label() -> String:
	if tab == 1 and _is_bank():
		var n := 0
		for item_id in _carried_resources():
			n += Inventory.backpack[item_id]
		return "Deposit all resources (%d)" % n if n > 0 else ""
	if tab == 0 and not _is_bank():
		var n := 0
		for item_id in _chest_items().keys():
			n += _chest_items()[item_id]
		n += _chest_gear().size()
		return "Take all loot (%d)" % n if n > 0 else ""
	return ""

func _on_bulk() -> void:
	if tab == 1 and _is_bank():
		for item_id in _carried_resources():
			_on_deposit(item_id, Inventory.get_count(item_id))
	elif tab == 0 and not _is_bank():
		var items: Dictionary = _chest_items().duplicate()
		for item_id in items.keys():
			var take: int = items[item_id]
			while take > 0 and not Inventory.can_add(item_id, take):
				take -= 1 # as much as the pack holds
			if take > 0:
				_on_withdraw(item_id, take)
		for inst in _chest_gear().duplicate():
			_on_withdraw_gear(inst.uid)

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
