extends CanvasLayer
# Autoload — always-visible top-left HUD: resource counters (port of the JS
# HUD's wood/stone counters, plus gold) with the player's current location
# (biome name on the overworld, e.g. "Frostpeak Ridge", wrapping onto a
# second line when long; a fixed name inside interiors) beside them, then -
# stacked underneath as a left-hand column - the HP bar, MP bar and an
# active-effects line. Those three used to live only on the battle screen
# (moved here per user feedback so they're always in view, including
# mid-fight: the battle panel starts at y=148 and this panel ends above it,
# see setup_hud_inventory.gd / setup_battle_panel.gd). The panel's height
# tracks its content each frame so there's no dead space under the bars.

@onready var panel: Panel = $Panel
@onready var margin: MarginContainer = $Panel/Margin
@onready var wood_label: Label = $Panel/Margin/VBox/HBox/WoodLabel
@onready var stone_label: Label = $Panel/Margin/VBox/HBox/StoneLabel
@onready var gold_label: Label = $Panel/Margin/VBox/HBox/GoldLabel
@onready var location_label: Label = $Panel/Margin/VBox/HBox/LocationLabel
@onready var hp_bar: ProgressBar = $Panel/Margin/VBox/HPBar
@onready var hp_label: Label = $Panel/Margin/VBox/HPBar/HPLabel
@onready var mp_bar: ProgressBar = $Panel/Margin/VBox/MPBar
@onready var mp_label: Label = $Panel/Margin/VBox/MPBar/MPLabel
@onready var status_label: Label = $Panel/Margin/VBox/StatusLabel

# Scenes that read the biome under the player's feet; everything else is
# an interior and shows a fixed name (unlisted scenes fall back to the
# scene name itself).
const BIOME_SCENES := {"Overworld": true, "Overworld2": true}
const SCENE_LOCATIONS := {
	"Dungeon": "Dungeon",
	"Castle": "Castle",
	"FinalBoss": "Hidden Maze",
	"House": "Village",
	"ElderHouse": "Village",
	"TraderHouse": "Village",
	"EmptyHouse": "Village",
	"FrostpeakInterior": "Frostpeak Ridge",
	"VerdantwoodInterior": "Verdantwood Forest",
	"BadlandsInterior": "Emberfall Badlands",
	"GloomfenInterior": "Gloomfen Marsh",
	"GoldenPlainsInterior": "Golden Plains",
}

var _last_location := ""

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

func location_name() -> String:
	var current: Node = get_tree().current_scene
	if current == null:
		return ""
	if BIOME_SCENES.has(current.name):
		var player: Node2D = current.get_node_or_null("YSort/Player")
		if player == null:
			return ""
		var tx: int = floori(player.position.x / 32.0)
		var ty: int = floori(player.position.y / 32.0)
		return World.ZONE_NAMES.get(World.biome_at(tx, ty).zone, "")
	return SCENE_LOCATIONS.get(current.name, current.name)

func _process(_delta: float) -> void:
	var location: String = location_name()
	if location != _last_location:
		_last_location = location
		location_label.text = location
	# Fit the panel to its content (the location label can wrap to 1 or 2
	# lines) - the panel is a plain Panel, so nothing sizes it for us.
	var wanted_height: float = margin.get_combined_minimum_size().y
	if not is_equal_approx(panel.size.y, wanted_height):
		panel.size.y = wanted_height
