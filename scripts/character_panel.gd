extends CanvasLayer
# Autoload — toggled with the "toggle_character" action (C key). Shows
# Oliver's stats + equipment slots, port of the JS Character panel.

@onready var panel: Panel = $Panel
@onready var hp_bar: ProgressBar = $Panel/Margin/VBox/HPBar
@onready var hp_label: Label = $Panel/Margin/VBox/HPBar/HPLabel
@onready var mp_bar: ProgressBar = $Panel/Margin/VBox/MPBar
@onready var mp_label: Label = $Panel/Margin/VBox/MPBar/MPLabel
@onready var strength_label: Label = $Panel/Margin/VBox/StatsRow/StrengthLabel
@onready var agility_label: Label = $Panel/Margin/VBox/StatsRow/AgilityLabel
@onready var weapon_label: Label = $Panel/Margin/VBox/WeaponLabel
@onready var armor_label: Label = $Panel/Margin/VBox/ArmorLabel
@onready var accessory_label: Label = $Panel/Margin/VBox/AccessoryLabel

func _ready() -> void:
	panel.visible = false
	Character.changed.connect(_refresh)

func _refresh() -> void:
	var stats: Dictionary = Character.stats
	hp_bar.max_value = stats.max_hp
	hp_bar.value = stats.hp
	hp_label.text = "HP: %d / %d" % [stats.hp, stats.max_hp]
	mp_bar.max_value = stats.max_mp
	mp_bar.value = stats.mp
	mp_label.text = "MP: %d / %d" % [stats.mp, stats.max_mp]
	strength_label.text = "Strength: %d" % stats.strength
	agility_label.text = "Agility: %d" % stats.agility

	weapon_label.text = "Weapon: %s" % _slot_text("weapon")
	armor_label.text = "Armor: %s" % _slot_text("armor")
	accessory_label.text = "Accessory: %s" % _slot_text("accessory")

func _slot_text(slot: String) -> String:
	var item_id: String = Character.equipment[slot]
	if item_id == "":
		return "(empty)"
	var stats := Items.describe_stats(item_id)
	if stats == "":
		return Items.get_item_name(item_id)
	return "%s (%s)" % [Items.get_item_name(item_id), stats]

func toggle_open() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		_refresh()

func _process(_delta: float) -> void:
	if not Combat.in_combat and Input.is_action_just_pressed("toggle_character"):
		toggle_open()
