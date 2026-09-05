extends CanvasLayer
# Autoload - the in-world opening. New Game (SaveSystem.new_game()) drops
# Oliver beside his own bed with GameState.intro_pending set; House._ready()
# then calls play(): the screen starts black and fades up on Oliver dozing
# on his feet (z z Z), and his first-morning thoughts run through the
# dialogue box page by page - Next button, E or the action button all turn
# the page, so it's never a dead end. The last page hands control over:
# intro_pending cleared, autosave. The player is frozen throughout
# (player.gd checks is_playing()). Leaving the scene (quit to title, a load)
# cancels it; a save taken mid-intro replays it on Continue.

const SPEAKER := "Oliver"
const PAGES: Array[String] = [
	"*yawn*... Morning already? The birds are loud out here.",
	"My first day in the valley. A house of my own, a village I barely know, and a whole valley beyond the gates that nobody has told me much about.",
	"The Village Elder asked me to find him on the square once I was up. He said he'd show me around.",
	"Boots on, then. The door's just south of here - let's go and see this valley.",
]
const FADE_SECONDS := 1.4
const HEAD_Y := -50.0 # z z Z just above Oliver's head (64px sprite, centred)

var _playing := false
var _fading := false
var _page := -1
var _scene: Node = null
var _run := 0 # bumps per play(); a cancelled play's parked coroutine sees a stale token and stops
var _black: ColorRect
var _marker: SleepMarker = null

func _ready() -> void:
	layer = 100 # over every overlay while it fades
	_black = ColorRect.new()
	_black.name = "Black"
	_black.color = Color(0, 0, 0, 1)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	_black.visible = false
	add_child(_black)

func is_playing() -> bool:
	return _playing

func page_index() -> int:
	return _page

func play(player: Node2D) -> void:
	_run += 1
	var run: int = _run
	_playing = true
	_fading = true
	_page = -1
	_scene = get_tree().current_scene
	_black.visible = true
	_black.modulate.a = 1.0
	# Just up, still facing the bed, still half asleep.
	player.facing = "left"
	player.sprite.play("left_idle")
	_marker = SleepMarker.attach(player, HEAD_Y)
	_marker.visible = true
	await get_tree().create_timer(0.6).timeout
	if not _still_running(run):
		return
	var t := create_tween()
	t.tween_property(_black, "modulate:a", 0.0, FADE_SECONDS)
	await t.finished
	if not _still_running(run):
		return
	_black.visible = false
	await get_tree().create_timer(0.8).timeout # a beat of dozing
	if not _still_running(run):
		return
	_drop_marker()
	_fading = false
	_next_page()

func _still_running(run: int) -> bool:
	return _playing and run == _run and get_tree().current_scene == _scene

func _drop_marker() -> void:
	if _marker != null and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null

func _next_page() -> void:
	_page += 1
	if _page >= PAGES.size():
		_finish()
		return
	var last: bool = _page == PAGES.size() - 1
	DialogueUI.show_dialogue(SPEAKER, PAGES[_page], [{"label": "Off we go" if last else "Next", "callback": _next_page}])

func _finish() -> void:
	_playing = false
	_scene = null
	GameState.intro_pending = false
	SaveSystem._mark_dirty()

func cancel() -> void:
	_playing = false
	_fading = false
	_scene = null
	_black.visible = false
	_drop_marker()

func _process(_delta: float) -> void:
	if not _playing:
		return
	# The scene went away under it (quit to title, a load): drop everything.
	if get_tree().current_scene != _scene:
		cancel()
		return
	if _fading:
		return
	# E / the action button closed the page without the button - turn it.
	if not DialogueUI.is_open():
		_next_page()
