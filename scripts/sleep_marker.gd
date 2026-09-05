class_name SleepMarker
extends Label
# A floating "z z Z" over a sleeping monster (nothing in the valley dies -
# a beaten monster dozes off and you take its things while it sleeps). The
# letters drift up and fade in a slow loop. Attach with SleepMarker.attach();
# the owner shows/hides it as the monster sleeps/wakes.

var _t := 0.0
var _base_y := 0.0

static func attach(parent: Node2D, above_y: float) -> SleepMarker:
	var m := SleepMarker.new()
	m.name = "SleepMarker"
	m.text = "z z Z"
	m.add_theme_font_size_override("font_size", 18)
	m.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	m.add_theme_color_override("font_outline_color", Color(0.15, 0.12, 0.3))
	m.add_theme_constant_override("outline_size", 5)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.size = Vector2(60, 24)
	m.position = Vector2(-30.0 + 8.0, above_y)
	m._base_y = above_y
	m.visible = false
	parent.add_child(m)
	return m

func _process(delta: float) -> void:
	if not visible:
		return
	_t = fmod(_t + delta, 2.4)
	var k: float = _t / 2.4
	position.y = _base_y - 14.0 * k
	modulate.a = 1.0 - k * k
