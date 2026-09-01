extends CanvasLayer
# Autoload — full-screen battle UI. Visibility mirrors Combat.in_combat.
# Commands/Submenu toggle based on Combat.active_submenu (Magic/Item open a
# dynamically-built row list with a Back button, replacing the command row).
# Shows up to 3 enemy slots; when Combat.selecting_target is set, alive
# slots get a warm highlight and become clickable, calling
# Combat.select_target(index) via each slot's own gui_input.

const MAX_ENEMY_SLOTS := 3
const TARGETABLE_TINT := Color(1.3, 1.1, 0.6)
const NORMAL_TINT := Color(1, 1, 1)

@onready var panel: Panel = $Panel
@onready var enemy_slots: Array = []
@onready var player_hp_bar: ProgressBar = $Panel/Margin/VBox/PlayerRow/PlayerHPBar
@onready var player_hp_label: Label = $Panel/Margin/VBox/PlayerRow/PlayerHPBar/PlayerHPLabel
@onready var player_mp_bar: ProgressBar = $Panel/Margin/VBox/PlayerRow/PlayerMPBar
@onready var player_mp_label: Label = $Panel/Margin/VBox/PlayerRow/PlayerMPBar/PlayerMPLabel
@onready var status_row: HBoxContainer = $Panel/Margin/VBox/PlayerRow/StatusRow
@onready var log_label: Label = $Panel/Margin/VBox/LogPanel/LogLabel
@onready var commands: HBoxContainer = $Panel/Margin/VBox/Commands
@onready var attack_btn: Button = $Panel/Margin/VBox/Commands/AttackBtn
@onready var magic_btn: Button = $Panel/Margin/VBox/Commands/MagicBtn
@onready var item_btn: Button = $Panel/Margin/VBox/Commands/ItemBtn
@onready var defend_btn: Button = $Panel/Margin/VBox/Commands/DefendBtn
@onready var run_btn: Button = $Panel/Margin/VBox/Commands/RunBtn
@onready var submenu: VBoxContainer = $Panel/Margin/VBox/Submenu

func _ready() -> void:
	panel.visible = false
	var enemies_row: HBoxContainer = $Panel/Margin/VBox/EnemiesRow
	for i in range(MAX_ENEMY_SLOTS):
		var slot: Control = enemies_row.get_node("EnemySlot%d" % i)
		slot.gui_input.connect(_on_slot_gui_input.bind(i))
		enemy_slots.append(slot)

	Combat.changed.connect(_refresh)
	Character.changed.connect(_refresh)
	attack_btn.pressed.connect(Combat.player_attack)
	magic_btn.pressed.connect(Combat.open_magic_menu)
	item_btn.pressed.connect(Combat.open_item_menu)
	defend_btn.pressed.connect(Combat.player_defend)
	run_btn.pressed.connect(Combat.player_run)

func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Combat.select_target(index)

func _refresh() -> void:
	panel.visible = Combat.in_combat
	if not Combat.in_combat:
		return

	var targeting: bool = Combat.selecting_target != ""
	for i in range(MAX_ENEMY_SLOTS):
		var slot: Control = enemy_slots[i]
		var enemy = Combat.current_enemies[i] if i < Combat.current_enemies.size() else null
		slot.visible = enemy != null
		if enemy == null:
			continue
		slot.modulate = TARGETABLE_TINT if targeting else NORMAL_TINT
		var sprite: TextureRect = slot.get_node("Sprite")
		sprite.texture = load(enemy.sprite)
		sprite.modulate = enemy.get("tint", Color(1, 1, 1, 1))
		var name_label: Label = slot.get_node("NameLabel")
		name_label.text = enemy.name
		var hp_bar: ProgressBar = slot.get_node("HPBar")
		hp_bar.max_value = enemy.max_hp
		hp_bar.value = enemy.hp
		var hp_label: Label = hp_bar.get_node("HPLabel")
		hp_label.text = "%d / %d" % [enemy.hp, enemy.max_hp]

	var stats: Dictionary = Character.stats
	player_hp_bar.max_value = stats.max_hp
	player_hp_bar.value = stats.hp
	player_hp_label.text = "HP: %d / %d" % [stats.hp, stats.max_hp]
	player_mp_bar.max_value = stats.max_mp
	player_mp_bar.value = stats.mp
	player_mp_label.text = "MP: %d / %d" % [stats.mp, stats.max_mp]
	_refresh_status_row()

	var text := ""
	for i in range(Combat.battle_log.size()):
		if i > 0:
			text += "\n"
		text += Combat.battle_log[i]
	log_label.text = text

	_refresh_submenu()

func _refresh_status_row() -> void:
	for child in status_row.get_children():
		child.queue_free()
	for status_id in Combat.player_status.keys():
		var def: Dictionary = Statuses.STATUSES[status_id]
		var turns_left: int = Combat.player_status[status_id].turns_left
		var badge := Label.new()
		badge.text = "%s (%d)" % [def.name, turns_left]
		badge.theme_type_variation = &"DimLabel"
		badge.add_theme_font_size_override("font_size", 12)
		status_row.add_child(badge)

func _clear_submenu() -> void:
	for child in submenu.get_children():
		child.queue_free()

func _add_submenu_row(text: String, disabled: bool, on_pick: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.disabled = disabled
	btn.pressed.connect(on_pick)
	submenu.add_child(btn)

func _refresh_submenu() -> void:
	# Commands (and the ability to open a submenu) are unavailable while a
	# target is being chosen - only clicking an enemy slot does anything then.
	var targeting: bool = Combat.selecting_target != ""
	var open: bool = Combat.active_submenu != "" and not targeting
	commands.visible = not open and not targeting
	submenu.visible = open
	if not open:
		return

	_clear_submenu()
	if Combat.active_submenu == "magic":
		for spell_id in Spells.SPELLS.keys():
			var spell: Dictionary = Spells.SPELLS[spell_id]
			var label := "%s (%d MP)" % [spell.name, spell.mp_cost]
			_add_submenu_row(label, Character.stats.mp < spell.mp_cost, Combat.cast_spell.bind(spell_id))
	elif Combat.active_submenu == "item":
		var usable := false
		for item_id in Inventory.backpack.keys():
			if Items.is_usable(item_id) and Inventory.backpack[item_id] > 0:
				usable = true
				var label := "%s x%d" % [Items.get_item_name(item_id), Inventory.backpack[item_id]]
				_add_submenu_row(label, false, Combat.use_item.bind(item_id))
		if not usable:
			var empty_label := Label.new()
			empty_label.text = "No usable items."
			empty_label.theme_type_variation = &"DimLabel"
			submenu.add_child(empty_label)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.pressed.connect(Combat.close_submenu)
	submenu.add_child(back_btn)
