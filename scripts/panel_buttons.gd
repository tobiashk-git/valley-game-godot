extends CanvasLayer
# Autoload — a persistent top-right row of clickable icon buttons, one per
# toggleable screen (Inventory/Character/Crafting/Journal/Map). A mouse/touch
# alternative to the I/C/R/Q/M keyboard shortcuts - the JS reference's version
# of this row is touch-only (gated behind a `pointer: coarse` media query,
# confirmed via its style.css), but a clickable toolbar is worth having on
# desktop too.
#
# Every screen is a TAB of the CharacterSheet window (UI redesign Phases
# 1-3c); QuestPanel/WorldMapPanel are aliases onto its tabs.

const PANEL_AUTOLOADS: Array[String] = [
	"CharacterSheet", "QuestPanel", "WorldMapPanel",
]

@onready var inventory_btn: Button = $HBox/InventoryBtn
@onready var character_btn: Button = $HBox/CharacterBtn
@onready var crafting_btn: Button = $HBox/CraftingBtn
@onready var quest_btn: Button = $HBox/QuestBtn
@onready var map_btn: Button = $HBox/MapBtn
@onready var hbox: HBoxContainer = $HBox
# Phone-width screens (Layout.is_narrow()) show this single button instead
# of the five-letter row, which wouldn't fit beside the HUD; it opens the
# character sheet, whose tab strip reaches all five screens.
@onready var menu_btn: Button = $MenuBtn

func _ready() -> void:
	inventory_btn.pressed.connect(_on_sheet_pressed.bind("inventory"))
	character_btn.pressed.connect(_on_sheet_pressed.bind("character"))
	crafting_btn.pressed.connect(_on_sheet_pressed.bind("crafting"))
	quest_btn.pressed.connect(_on_sheet_pressed.bind("journal"))
	map_btn.pressed.connect(_on_sheet_pressed.bind("map"))
	menu_btn.pressed.connect(_on_menu_pressed)
	Layout.changed.connect(_apply_layout)
	_apply_layout()

func _apply_layout() -> void:
	hbox.visible = not Layout.is_narrow()
	menu_btn.visible = Layout.is_narrow()

# Menu: anything open -> close it all; nothing open -> the sheet on its
# last tab.
func _on_menu_pressed() -> void:
	if Combat.in_combat:
		return
	var any_open := false
	for autoload_name in PANEL_AUTOLOADS:
		if get_node("/root/%s" % autoload_name).is_open():
			any_open = true
	_close_all()
	if not any_open:
		get_node("/root/CharacterSheet").open()

func _close_all() -> void:
	for autoload_name in PANEL_AUTOLOADS:
		get_node("/root/%s" % autoload_name).close()

# Only one of these screens is meant to be on screen at a time - switching
# between them via the toolbar closes whatever else is open first, rather
# than stacking (clicking the already-open one just closes it).
func _on_pressed(panel_autoload_name: String) -> void:
	if Combat.in_combat:
		return
	var target: Node = get_node("/root/%s" % panel_autoload_name)
	var was_open: bool = target.is_open()
	_close_all()
	if not was_open:
		target.open()

# The sheet's I/C buttons: same rule per TAB - the open tab's button closes
# the window, the other tab's button switches to it.
func _on_sheet_pressed(tab: String) -> void:
	if Combat.in_combat:
		return
	var sheet: Node = get_node("/root/CharacterSheet")
	var was_open: bool = sheet.is_open() and sheet.current_tab == tab
	_close_all()
	if not was_open:
		sheet.open(tab)
