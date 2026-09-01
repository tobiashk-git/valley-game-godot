extends CanvasLayer
# Autoload — opened by chest.gd via storage_panel.open_storage(id), closed
# with another E press. One-frame "just opened" guard mirrors dialogue_ui.gd
# so the same E-press that opens it doesn't also immediately close it.

@onready var panel: Panel = $Panel
@onready var chest_list: VBoxContainer = $Panel/Margin/HBox/ChestColumn/ChestList
@onready var backpack_list: VBoxContainer = $Panel/Margin/HBox/BackpackColumn/BackpackList

var _current_storage_id := ""
var _ignore_close_this_frame := false

func _ready() -> void:
	panel.visible = false
	Storage.changed.connect(_refresh)
	Inventory.changed.connect(_refresh)
	# Process after interactables (chest.gd etc, default priority 0) so a
	# close-press is seen by them as "still open" this frame and they don't
	# immediately reopen what this same press just closed.
	process_priority = 10

func is_open() -> bool:
	return panel.visible

func open_storage(storage_id: String) -> void:
	_current_storage_id = storage_id
	panel.visible = true
	_ignore_close_this_frame = true
	_refresh()

func close() -> void:
	panel.visible = false
	_current_storage_id = ""

func _build_column(list: VBoxContainer, items: Dictionary, on_pick: Callable) -> void:
	for child in list.get_children():
		child.queue_free()
	if items.is_empty():
		var empty_label := Label.new()
		empty_label.text = "(empty)"
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		list.add_child(empty_label)
		return
	for item_id in items.keys():
		var btn := Button.new()
		btn.text = "%s x%d" % [Items.get_item_name(item_id), items[item_id]]
		btn.pressed.connect(on_pick.bind(item_id))
		list.add_child(btn)

func _refresh() -> void:
	if not panel.visible:
		return
	_build_column(chest_list, Storage.get_storage(_current_storage_id), _on_withdraw)
	_build_column(backpack_list, Inventory.backpack, _on_deposit)

func _on_withdraw(item_id: String) -> void:
	if Storage.remove_item(_current_storage_id, item_id, 1):
		Inventory.add_item(item_id, 1)

func _on_deposit(item_id: String) -> void:
	if Inventory.remove_item(item_id, 1):
		Storage.add_item(_current_storage_id, item_id, 1)

func _process(_delta: float) -> void:
	if not panel.visible:
		return
	if _ignore_close_this_frame:
		_ignore_close_this_frame = false
		return
	if Input.is_action_just_pressed("interact"):
		close()
