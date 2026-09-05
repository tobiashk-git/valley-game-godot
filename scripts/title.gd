extends Control
# The title screen - the project's main scene. Continue (when an auto save
# exists: "Saved 2 min ago - in the Valley") loads it; New Game starts
# fresh, with a second tap to confirm when it would overwrite a save. The
# in-game overlays (HUD, toolbar, quick bar, tracker, touch controls) stay
# hidden here - they show only on scenes with a player (GameState.
# is_gameplay()). Background: the valley's rendered map (WorldMap.render_map)
# dimmed under a vignette, Oliver's illustration to the side (above the
# menu on a phone).

@onready var map_bg: TextureRect = $MapBackground
@onready var figure: TextureRect = $Figure
@onready var menu: Panel = $MenuPanel
@onready var title_label: Label = $MenuPanel/TitleLabel
@onready var tagline: Label = $MenuPanel/Tagline
@onready var buttons: VBoxContainer = $MenuPanel/Buttons
@onready var continue_btn: Button = $MenuPanel/Buttons/ContinueBtn
@onready var new_game_btn: Button = $MenuPanel/Buttons/NewGameBtn
@onready var save_line: Label = $MenuPanel/SaveLine
@onready var version_label: Label = $VersionLabel

var _confirm_new := false

func _ready() -> void:
	map_bg.texture = WorldMap.render_map(Rect2i(World.WORLD_CENTER_X - 60, World.WORLD_CENTER_Y - 60, 120, 120))
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	version_label.text = "build %s" % version
	version_label.visible = version != ""
	continue_btn.pressed.connect(_on_continue)
	new_game_btn.pressed.connect(_on_new_game)
	Layout.changed.connect(_apply_layout)
	_apply_layout()
	refresh()

func _place(c: Control, pos: Vector2, size: Vector2) -> void:
	c.position = pos
	c.size = size

func _apply_layout() -> void:
	var w: float = Layout.width
	var h: float = Layout.size().y
	if not Layout.is_narrow():
		# Menu column left of centre, Oliver on the right.
		_place(menu, Vector2(w * 0.5 - 300.0, h * 0.5 - 170.0), Vector2(360, 340))
		_place(figure, Vector2(w * 0.5 + 90.0, h * 0.5 - 170.0), Vector2(156, 340))
	else:
		# Oliver above the menu, both centred.
		var fig_h: float = minf(260.0, h * 0.34)
		_place(figure, Vector2((w - 120.0) / 2.0, h * 0.08), Vector2(120, fig_h))
		_place(menu, Vector2(12, h * 0.08 + fig_h + 12.0), Vector2(w - 24.0, 330))
	_place(title_label, Vector2(0, 18), Vector2(menu.size.x, 48))
	_place(tagline, Vector2(0, 66), Vector2(menu.size.x, 20))
	_place(buttons, Vector2((menu.size.x - 280.0) / 2.0, 110), Vector2(280, 124))
	_place(save_line, Vector2(16, 244), Vector2(menu.size.x - 32.0, 60))
	_place(version_label, Vector2(w - 160.0, h - 24.0), Vector2(148, 16))

# Button states from the auto save (Continue first when one exists).
func refresh() -> void:
	var has: bool = SaveSystem.has_save()
	continue_btn.visible = has
	continue_btn.theme_type_variation = &"PrimaryButton"
	new_game_btn.theme_type_variation = &"SecondaryButton" if has else &"PrimaryButton"
	new_game_btn.text = "Overwrite save?" if _confirm_new else "New Game"
	if has:
		var data: Dictionary = SaveSystem.read_save()
		var scene_name: String = str(data.get("scene", "")).get_file().get_basename()
		var where: String = WorldMap.LOCATION_NAMES.get(scene_name, scene_name)
		SaveSystem.last_saved_unix = int(data.get("saved_unix", 0))
		save_line.text = "%s  -  in %s" % [SaveSystem.saved_ago_text(), where]
	else:
		save_line.text = "No save yet - a new valley awaits."

func _on_continue() -> void:
	SaveSystem.load_game()

func _on_new_game() -> void:
	if SaveSystem.has_save() and not _confirm_new:
		_confirm_new = true
		refresh()
		get_tree().create_timer(4.0).timeout.connect(func() -> void:
			if is_inside_tree() and _confirm_new:
				_confirm_new = false
				refresh())
		return
	_confirm_new = false
	SaveSystem.new_game()
