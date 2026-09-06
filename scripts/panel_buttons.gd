extends CanvasLayer
# Autoload — the system bar at the top-right of the game screen: Menu (the
# character sheet, whose tab strip reaches every screen), Save, Settings and
# Quit. One design for every width (user feedback: the old five-letter row
# on desktop/iPad just opened the same window the phone's Menu did): a row
# beside the HUD at 800 wide, a column under Menu on a phone (the HUD leaves
# 68px + margins for it, hud.gd NARROW_RESERVE; the quest tracker starts
# below it, quest_tracker.gd). Hidden during a fight.
#
# Save writes the auto slot at once and says "Saved!" on the button for a
# moment; Quit asks "Sure?" first (a stray tap on a phone would otherwise
# drop you to the title), then saves and goes to the title; Settings opens
# the SettingsPanel (volume sliders, load).

const PANEL_AUTOLOADS: Array[String] = [
	"CharacterSheet", "QuestPanel", "WorldMapPanel", "SettingsPanel",
]
const FEEDBACK_SECONDS := 1.6
const CONFIRM_SECONDS := 3.0

@onready var bar: BoxContainer = $Bar
@onready var menu_btn: Button = $Bar/MenuBtn
@onready var save_btn: Button = $Bar/SaveBtn
@onready var settings_btn: Button = $Bar/SettingsBtn
@onready var quit_btn: Button = $Bar/QuitBtn

var confirm_quit := false
var _save_token := 0
var _quit_token := 0

func _ready() -> void:
	menu_btn.pressed.connect(_on_menu_pressed)
	save_btn.pressed.connect(_on_save_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
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
	for b in [save_btn, settings_btn, quit_btn]:
		b.custom_minimum_size = Vector2(68, 36 if narrow else 40)
		b.add_theme_font_size_override("font_size", 13 if narrow else 15)
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

func _on_save_pressed() -> void:
	if Combat.in_combat:
		return
	_flash_button(save_btn, "Saved!" if SaveSystem.save_game() else "Not now", "Save")

func _on_quit_pressed() -> void:
	if Combat.in_combat:
		return
	if not confirm_quit:
		confirm_quit = true
		_quit_token += 1
		var token: int = _quit_token
		quit_btn.text = "Sure?"
		quit_btn.theme_type_variation = &"PrimaryButton"
		get_tree().create_timer(CONFIRM_SECONDS).timeout.connect(func() -> void:
			if token == _quit_token:
				_reset_quit())
		return
	_reset_quit()
	_close_all()
	SaveSystem.quit_to_title()

func _reset_quit() -> void:
	confirm_quit = false
	quit_btn.text = "Quit"
	quit_btn.theme_type_variation = &"SecondaryButton"

# The button reports what happened for a moment, then reads as before.
func _flash_button(btn: Button, text: String, restore: String) -> void:
	_save_token += 1
	var token: int = _save_token
	btn.text = text
	btn.disabled = true
	get_tree().create_timer(FEEDBACK_SECONDS).timeout.connect(func() -> void:
		if token == _save_token:
			btn.text = restore
			btn.disabled = false)

func _any_open() -> bool:
	for autoload_name in PANEL_AUTOLOADS:
		if get_node("/root/%s" % autoload_name).is_open():
			return true
	return false

func _close_all() -> void:
	for autoload_name in PANEL_AUTOLOADS:
		get_node("/root/%s" % autoload_name).close()
