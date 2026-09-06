extends CanvasLayer
# Autoload — the system bar at the top-right of the game screen: Menu (the
# character sheet, whose tab strip reaches every screen) and a cog that
# opens the Settings window (SettingsPanel: Save / Load / Quit and the
# volume sliders). One design for every width (user feedback: the old
# five-letter row on desktop/iPad just opened the same window the phone's
# Menu did, and Save / Settings / Quit as three more buttons was too much -
# "maybe we just need a cog icon"): a row beside the HUD at 800 wide, a
# column on a phone (the HUD leaves 68px + margins for it, hud.gd
# NARROW_RESERVE). Hidden during a fight and while a dialogue box is up.
# The title screen shows the same cog (title.gd).

const PANEL_AUTOLOADS: Array[String] = [
	"CharacterSheet", "QuestPanel", "WorldMapPanel", "SettingsPanel",
]

@onready var bar: BoxContainer = $Bar
@onready var menu_btn: Button = $Bar/MenuBtn
@onready var settings_btn: Button = $Bar/SettingsBtn

func _ready() -> void:
	menu_btn.pressed.connect(_on_menu_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	# The bar's size follows its content: collapsed to nothing at the corner,
	# it grows left/down to its minimum (a container never shrinks back on
	# its own, and set_size would keep the LEFT edge, not the right).
	bar.minimum_size_changed.connect(_fit)
	Layout.changed.connect(_apply_layout)
	_apply_layout()

func _apply_layout() -> void:
	var narrow: bool = Layout.is_narrow()
	bar.vertical = narrow
	bar.add_theme_constant_override("separation", 6 if narrow else 8)
	menu_btn.custom_minimum_size = Vector2(68, 44 if narrow else 40)
	settings_btn.custom_minimum_size = Vector2(68 if narrow else 44, 40)
	_fit()

func _fit() -> void:
	bar.offset_left = -12
	bar.offset_right = -12
	bar.offset_top = 12
	bar.offset_bottom = 12

# Hidden in a fight and while a dialogue box is up (on a phone the box
# spans the width, right over the column).
func _process(_delta: float) -> void:
	visible = GameState.is_gameplay() and not Combat.in_combat and not DialogueUI.is_open()

# Menu: anything open -> close it all; nothing open -> the sheet on its
# last tab.
func _on_menu_pressed() -> void:
	if Combat.in_combat:
		return
	var any_open: bool = _any_open()
	_close_all()
	if not any_open:
		get_node("/root/CharacterSheet").open()

func _on_settings_pressed() -> void:
	if Combat.in_combat:
		return
	var settings: Node = get_node("/root/SettingsPanel")
	var was_open: bool = settings.is_open()
	_close_all()
	if not was_open:
		settings.open()

func _any_open() -> bool:
	for autoload_name in PANEL_AUTOLOADS:
		if get_node("/root/%s" % autoload_name).is_open():
			return true
	return false

func _close_all() -> void:
	for autoload_name in PANEL_AUTOLOADS:
		get_node("/root/%s" % autoload_name).close()
