extends CanvasLayer
# Autoload — the game's ending (2026-09-12, the user: "for this version the
# crystals at the altar will end the game"). Altar.interact() calls play()
# with the altar's world position: a swirl of light rises out of the altar
# and slowly fills the screen, then the scene switches to Ending.tscn (the
# completion screen). Under a verify script (Combat.fast) the swirl is
# instant. World 2 (the portal) is a future version.

const DURATION := 4.5
const ARMS := 5
const TURNS := 3.0
const ENDING_SCENE := "res://scenes/Ending.tscn"

var playing := false
var _progress := 0.0
var _origin := Vector2.ZERO
var _canvas: Node2D
var _run := 0

func _ready() -> void:
	layer = 110 # over every overlay, the nap panel and the intro
	_canvas = Node2D.new()
	_canvas.name = "Swirl"
	_canvas.visible = false
	_canvas.draw.connect(_draw_swirl)
	add_child(_canvas)

# `world_pos`: the altar, in the current scene's world coordinates.
func play(world_pos: Vector2) -> void:
	if playing:
		return
	_run += 1
	var run: int = _run
	playing = true
	_progress = 0.0
	var vp: Viewport = get_viewport()
	_origin = vp.get_canvas_transform() * world_pos
	_canvas.visible = true
	Audio.play_sting("victory")
	GameState.world_progress.game_completed = true
	SaveSystem.save_game()
	if Combat.fast:
		_progress = 1.0
		_finish(run)
		return
	var t := create_tween()
	t.tween_method(_set_progress, 0.0, 1.0, DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(_finish.bind(run))

func _set_progress(v: float) -> void:
	_progress = v
	_canvas.queue_redraw()

func _finish(run: int) -> void:
	if run != _run:
		return
	playing = false
	_canvas.visible = false
	get_tree().change_scene_to_file(ENDING_SCENE)

# Gold-and-white spiral arms unwinding from the altar, and a warm glow that
# grows until it covers the screen.
func _draw_swirl() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var reach: float = (size - _origin).length() + _origin.length() # to the far corner, generously
	var p: float = _progress
	var glow_r: float = reach * p * p
	_canvas.draw_circle(_origin, maxf(glow_r, 2.0), Color(1.0, 0.95, 0.78, clampf(p * 1.2, 0.0, 1.0)))
	var t: float = Time.get_ticks_msec() / 1000.0
	for arm in range(ARMS):
		var pts := PackedVector2Array()
		var steps := 60
		for i in range(steps + 1):
			var f: float = float(i) / steps
			var r: float = f * reach * clampf(p * 1.4, 0.0, 1.0)
			var a: float = f * TAU * TURNS + arm * TAU / ARMS + t * 1.5
			pts.append(_origin + Vector2(cos(a), sin(a)) * r)
		var alpha: float = clampf(1.0 - p * 0.6, 0.2, 1.0)
		_canvas.draw_polyline(pts, Color(1.0, 0.85, 0.35, alpha), 4.0 + 6.0 * p, true)
		_canvas.draw_polyline(pts, Color(1.0, 1.0, 1.0, alpha * 0.6), 1.5, true)
