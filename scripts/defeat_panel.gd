extends CanvasLayer
# Autoload — the death sequence. Combat._defeat() restores HP/MP, docks a
# tenth of the gold, sends the player home (House.tscn) and emits
# Combat.defeated(info); this layer covers the scene change with black,
# then reveals the house under a dimmed panel: "You were defeated", what
# got you, where you woke up and what it cost, and a Wake up button. While
# it's up the player can't move (player.gd checks is_open()) and the world
# is dimmed; Wake up fades it away and play resumes at home. Autosave then
# records the respawn.

signal woke

@onready var black: ColorRect = $Black
@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/TitleLabel
@onready var body_label: Label = $Panel/BodyLabel
@onready var wake_btn: Button = $Panel/WakeBtn

var _open := false
var _tween: Tween = null

func _ready() -> void:
	black.visible = false
	panel.visible = false
	Combat.defeated.connect(show_defeat)
	wake_btn.pressed.connect(wake_up)
	Layout.changed.connect(_apply_layout)
	_apply_layout()

func is_open() -> bool:
	return _open

func _apply_layout() -> void:
	var w: float = Layout.width - 24.0 if Layout.is_narrow() else 440.0
	panel.offset_left = -w / 2.0
	panel.offset_right = w / 2.0
	panel.offset_top = -130.0
	panel.offset_bottom = 130.0
	title_label.position = Vector2(0, 16)
	title_label.size = Vector2(w, 30)
	body_label.position = Vector2(20, 54)
	body_label.size = Vector2(w - 40.0, 120)
	wake_btn.position = Vector2(w / 2.0 - 110.0, 196)
	wake_btn.size = Vector2(220, 44)

# What the panel says, from Combat's defeat info ({cause, gold_lost}).
static func story(info: Dictionary) -> String:
	var cause: String = str(info.get("cause", ""))
	var first: String
	if cause == "poison":
		first = "The poison finally took its toll."
	elif cause == "confusion":
		first = "Confused, you struck yourself down."
	elif cause == "":
		first = "The fight went badly."
	else:
		first = "The %s got the better of you." % cause
	var lost: int = int(info.get("gold_lost", 0))
	var purse: String = "%d gold slipped from your purse on the way." % lost if lost > 0 else "Your purse, at least, is untouched."
	return "%s\n\nYou come to in your own bed at home. %s" % [first, purse]

func show_defeat(info: Dictionary) -> void:
	_open = true
	if _tween != null:
		_tween.kill()
	title_label.text = "You were defeated"
	body_label.text = story(info)
	black.visible = true
	black.modulate.a = 1.0
	panel.visible = false
	# Hold the black while the house loads underneath, then reveal it dimmed
	# with the panel fading in.
	await get_tree().create_timer(0.5).timeout
	if not _open:
		return
	panel.visible = true
	panel.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(black, "modulate:a", 0.6, 0.8)
	_tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.6)

func wake_up() -> void:
	if not _open:
		return
	_open = false
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(black, "modulate:a", 0.0, 0.5)
	_tween.parallel().tween_property(panel, "modulate:a", 0.0, 0.3)
	_tween.tween_callback(func() -> void:
		black.visible = false
		panel.visible = false)
	woke.emit()

func _process(_delta: float) -> void:
	# A new fight (or the title screen) always wins over a stale panel. A
	# null current scene is the house still loading under the black - not
	# the title.
	var scene: Node = get_tree().current_scene
	if _open and (Combat.in_combat or (scene != null and not scene.has_node("YSort/Player"))):
		_open = false
		black.visible = false
		panel.visible = false
