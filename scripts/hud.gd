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
@onready var vbox: VBoxContainer = $Panel/Margin/VBox
@onready var hbox: HBoxContainer = $Panel/Margin/VBox/HBox
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
var _last_hp := -1

# Panel width at 800 wide; on a phone (Layout.is_narrow()) it shrinks to
# leave room for the toolbar's single Menu button (68px + 12px edge + 12px
# gap) on the same row, and the location label moves onto its own line
# under the counters (beside them it would have ~50px and split
# "Verdantwood" mid-word).
const WIDE_WIDTH := 320.0
const NARROW_RESERVE := 92.0

func _ready() -> void:
	Inventory.changed.connect(_refresh)
	_refresh()
	Layout.changed.connect(_apply_layout)
	_apply_layout()
	# HUD is an earlier autoload than Character/Combat (see project.godot),
	# so they don't exist yet during this _ready() - deferring to the end of
	# the frame lands after every autoload has been added.
	_connect_stats.call_deferred()

func _apply_layout() -> void:
	if Layout.is_narrow():
		panel.size.x = minf(WIDE_WIDTH, Layout.width - 24.0 - NARROW_RESERVE)
		if location_label.get_parent() != vbox:
			location_label.reparent(vbox, false)
			vbox.move_child(location_label, 1)
	else:
		panel.size.x = WIDE_WIDTH
		if location_label.get_parent() != hbox:
			location_label.reparent(hbox, false)

func _connect_stats() -> void:
	Character.changed.connect(_refresh_stats)
	Character.levelled_up.connect(func(level: int) -> void: _spawn_text_popup("Level %d!" % level, Color(1.0, 0.85, 0.3)))
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
	# Mid-fight HP changes float up over the bar as numbers (the battle
	# screen does the same over the enemy hit).
	if Combat.in_combat and _last_hp >= 0 and stats.hp != _last_hp:
		_spawn_popup(stats.hp - _last_hp)
	_last_hp = stats.hp if Combat.in_combat else -1
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

func _spawn_popup(delta: int) -> void:
	_spawn_text_popup(("+%d" if delta > 0 else "%d") % delta, Color(0.55, 0.95, 0.5) if delta > 0 else Color(1.0, 0.35, 0.3))

# A line of text floating up from beside the HP bar (damage/heal numbers,
# "Level 3!").
func _spawn_text_popup(text: String, color: Color) -> void:
	var label := Label.new()
	label.name = "HpPopup"
	label.set_meta("popup", true) # siblings get auto-renamed, so tag rather than trust the name
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 10
	var rect: Rect2 = hp_bar.get_global_rect()
	# Popups that spawn together (a level-up's full heal + "Level 3!")
	# stack upwards instead of landing on top of each other: a new one goes
	# a line above the highest popup still floating.
	var y: float = rect.position.y - 6.0
	for child in get_children():
		if child is Control and child.has_meta("popup"):
			y = minf(y, child.global_position.y - 24.0)
	label.global_position = Vector2(rect.end.x + 8.0, y)
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 36.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.tween_callback(label.queue_free)

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
	visible = GameState.is_gameplay()
	if not visible:
		return
	var location: String = location_name()
	if location != _last_location:
		_last_location = location
		location_label.text = location
	# Fit the panel to its content (the location label can wrap to 1 or 2
	# lines) - the panel is a plain Panel, so nothing sizes it for us.
	var wanted_height: float = margin.get_combined_minimum_size().y
	if not is_equal_approx(panel.size.y, wanted_height):
		panel.size.y = wanted_height
