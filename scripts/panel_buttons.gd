extends CanvasLayer
# Autoload — a persistent top-right row of clickable icon buttons, one per
# toggleable screen (Inventory/Character/Crafting/Journal/Map). A mouse/touch
# alternative to the I/C/R/Q/M keyboard shortcuts - the JS reference's version
# of this row is touch-only (gated behind a `pointer: coarse` media query,
# confirmed via its style.css), but a clickable toolbar is worth having on
# desktop too.
#
# Inventory and Character are now two TABS of the CharacterSheet window (UI
# redesign Phase 1) rather than separate popups; Crafting/Journal/Map are
# still their own panels until later phases.

const PANEL_AUTOLOADS: Array[String] = [
	"CharacterSheet", "CraftingPanel", "QuestPanel", "WorldMapPanel",
]

@onready var inventory_btn: Button = $HBox/InventoryBtn
@onready var character_btn: Button = $HBox/CharacterBtn
@onready var crafting_btn: Button = $HBox/CraftingBtn
@onready var quest_btn: Button = $HBox/QuestBtn
@onready var map_btn: Button = $HBox/MapBtn

func _ready() -> void:
	inventory_btn.pressed.connect(_on_sheet_pressed.bind("inventory"))
	character_btn.pressed.connect(_on_sheet_pressed.bind("character"))
	crafting_btn.pressed.connect(_on_pressed.bind("CraftingPanel"))
	quest_btn.pressed.connect(_on_pressed.bind("QuestPanel"))
	map_btn.pressed.connect(_on_pressed.bind("WorldMapPanel"))

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
