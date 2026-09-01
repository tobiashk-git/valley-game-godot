extends CanvasLayer
# Autoload — a persistent top-right row of clickable icon buttons, one per
# toggleable panel (Inventory/Character/Crafting/Journal/Map), each just
# calling that panel's own toggle_open(). A mouse-clickable alternative to
# the I/C/R/Q/M keyboard shortcuts - the JS reference's version of this row
# is touch-only (gated behind a `pointer: coarse` media query, confirmed via
# its style.css), but a clickable toolbar is worth having on desktop too,
# and this project has no touch-input layer yet to gate it behind anyway.

const PANEL_AUTOLOADS: Array[String] = [
	"InventoryPanel", "CharacterPanel", "CraftingPanel", "QuestPanel", "WorldMapPanel",
]

@onready var inventory_btn: Button = $HBox/InventoryBtn
@onready var character_btn: Button = $HBox/CharacterBtn
@onready var crafting_btn: Button = $HBox/CraftingBtn
@onready var quest_btn: Button = $HBox/QuestBtn
@onready var map_btn: Button = $HBox/MapBtn

func _ready() -> void:
	inventory_btn.pressed.connect(_on_pressed.bind("InventoryPanel"))
	character_btn.pressed.connect(_on_pressed.bind("CharacterPanel"))
	crafting_btn.pressed.connect(_on_pressed.bind("CraftingPanel"))
	quest_btn.pressed.connect(_on_pressed.bind("QuestPanel"))
	map_btn.pressed.connect(_on_pressed.bind("WorldMapPanel"))

# Only one of these panels is meant to be on screen at a time - switching
# between them via the toolbar closes whatever else is open first, rather
# than stacking (clicking the already-open one just closes it).
func _on_pressed(panel_autoload_name: String) -> void:
	if Combat.in_combat:
		return
	var target: Node = get_node("/root/%s" % panel_autoload_name)
	var was_open: bool = target.is_open()
	for autoload_name in PANEL_AUTOLOADS:
		get_node("/root/%s" % autoload_name).close()
	if not was_open:
		target.open()
