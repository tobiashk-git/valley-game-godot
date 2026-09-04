extends CanvasLayer
# Autoload — always-visible top-left resource counters, port of the JS
# HUD's wood/stone counters (plus gold, which the JS HUD doesn't show but
# is useful to see here while there's no full inventory UI yet), plus a
# small "World N" indicator once World 2 exists to distinguish from, and -
# stacked underneath as a left-hand column - the player's HP bar, MP bar and
# an active-effects line. Those three used to live only on the battle
# screen (moved here per user feedback so they're always in view, including
# mid-fight: the battle panel starts at y=140 and this panel ends above it,
# see setup_hud_inventory.gd / setup_battle_panel.gd).

@onready var wood_label: Label = $Panel/Margin/VBox/HBox/WoodLabel
@onready var stone_label: Label = $Panel/Margin/VBox/HBox/StoneLabel
@onready var gold_label: Label = $Panel/Margin/VBox/HBox/GoldLabel
@onready var world_label: Label = $Panel/Margin/VBox/HBox/WorldLabel
@onready var hp_bar: ProgressBar = $Panel/Margin/VBox/HPBar
@onready var hp_label: Label = $Panel/Margin/VBox/HPBar/HPLabel
@onready var mp_bar: ProgressBar = $Panel/Margin/VBox/MPBar
@onready var mp_label: Label = $Panel/Margin/VBox/MPBar/MPLabel
@onready var status_label: Label = $Panel/Margin/VBox/StatusLabel

# Every World-1 scene (Overworld and all its interiors) maps to "World 1";
# only Overworld2 (and, in the future, its own interiors) is "World 2".
const WORLD_2_SCENES := {"Overworld2": true}

var _last_scene_name := ""

func _ready() -> void:
	Inventory.changed.connect(_refresh)
	_refresh()
	# HUD is an earlier autoload than Character/Combat (see project.godot),
	# so they don't exist yet during this _ready() - deferring to the end of
	# the frame lands after every autoload has been added.
	_connect_stats.call_deferred()

func _connect_stats() -> void:
	Character.changed.connect(_refresh_stats)
	# In-fight damage/healing/status changes mutate Character.stats and
	# Combat.player_status and announce it via Combat.changed (that's what
	# the battle panel refreshes on), so listen to both.
	Combat.changed.connect(_refresh_stats)
	_refresh_stats()

func _refresh() -> void:
	# Icon now carries identity (see setup_hud_inventory.gd's WoodIcon etc.),
	# so the label just needs the count - the old "Wood: 3" text duplicated
	# what the icon already shows.
	wood_label.text = str(Inventory.get_count("wood"))
	stone_label.text = str(Inventory.get_count("stone"))
	gold_label.text = str(Inventory.get_count("gold"))

func _refresh_stats() -> void:
	var stats: Dictionary = Character.stats
	hp_bar.max_value = stats.max_hp
	hp_bar.value = stats.hp
	hp_label.text = "HP %d / %d" % [stats.hp, stats.max_hp]
	mp_bar.max_value = stats.max_mp
	mp_bar.value = stats.mp
	mp_label.text = "MP %d / %d" % [stats.mp, stats.max_mp]

	# Same "<Name> (<turns left>)" wording the battle screen's badges used.
	var effects: Array = []
	for status_id in Combat.player_status.keys():
		var def: Dictionary = Statuses.STATUSES[status_id]
		effects.append("%s (%d)" % [def.name, Combat.player_status[status_id].turns_left])
	if effects.is_empty():
		status_label.text = "No effects"
		status_label.theme_type_variation = &"DimLabel"
	else:
		status_label.text = ", ".join(effects)
		status_label.theme_type_variation = &""

func _process(_delta: float) -> void:
	var current: Node = get_tree().current_scene
	var scene_name: String = current.name if current else ""
	if scene_name == _last_scene_name:
		return
	_last_scene_name = scene_name
	world_label.text = "World 2" if WORLD_2_SCENES.get(scene_name, false) else "World 1"
