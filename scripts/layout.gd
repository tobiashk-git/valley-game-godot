extends Node
# Autoload (FIRST in project.godot) — picks the game's logical viewport width
# from the physical screen so UI elements are the same real-world size on a
# phone as on a tablet or desktop.
#
# The problem it solves (user feedback from an iPhone + iPad playtest): with a
# fixed 800-unit logical width (window/stretch/aspect="keep_width"), an
# ~820 CSS-px iPad maps one unit to about one CSS px - everything reads at
# the intended size - but a 390 CSS-px iPhone squeezes the same 800 units
# into half the width, so every button, slot and line of text came out at
# half size. Rather than scale each element up (they'd no longer fit the
# 800-wide layouts), the logical width itself now follows the screen:
#
#   CSS width >= WIDE_THRESHOLD  -> 800 units (desktop, iPad: unchanged)
#   narrower                     -> the CSS width itself, clamped to
#                                   NARROW_MIN..NARROW_MAX (iPhones: ~390-430)
#
# so one logical unit is ~one CSS px everywhere. Overlays that were laid out
# for 800 units check `Layout.is_narrow()` and switch to a stacked/narrow
# arrangement (see each script's _apply_layout()). The camera zoom on touch
# devices is scaled to match so the WORLD keeps the same field of view it
# had before (touch_controls.gd) - only the UI changes size.
#
# Stretch mode is "canvas_items" (was "viewport"): a 390-unit-wide viewport
# upscaled 3x for an iPhone's pixel ratio would render text at 390 px and
# blur it; canvas_items draws at the full device resolution instead.
#
# Verify scripts simulate a phone by resizing the window (root.size =
# Vector2i(400, 860)) - the size_changed hook below re-applies the rule.

signal changed

const WIDE_WIDTH := 800
const WIDE_THRESHOLD := 640.0
const NARROW_MIN := 360
const NARROW_MAX := 480
const BASE_HEIGHT := 600

var width: int = WIDE_WIDTH
var _applying := false

func _ready() -> void:
	get_window().size_changed.connect(_apply)
	_apply()

func is_narrow() -> bool:
	return width < WIDE_WIDTH

# Logical viewport size after the stretch (height grows with a tall screen).
func size() -> Vector2:
	return get_viewport().get_visible_rect().size

# The screen's size in CSS px (web) or window px (desktop) - the units a
# finger or a mouse actually experiences.
func css_size() -> Vector2:
	if OS.has_feature("web"):
		var w: Variant = JavaScriptBridge.eval("window.innerWidth", true)
		var h: Variant = JavaScriptBridge.eval("window.innerHeight", true)
		if (w is float or w is int) and (h is float or h is int) and float(w) > 0.0:
			return Vector2(float(w), float(h))
	var scale: float = maxf(DisplayServer.screen_get_scale(), 1.0)
	return Vector2(DisplayServer.window_get_size()) / scale

static func width_for(css_width: float) -> int:
	if css_width >= WIDE_THRESHOLD:
		return WIDE_WIDTH
	return clampi(int(round(css_width)), NARROW_MIN, NARROW_MAX)

func _apply() -> void:
	# Changing content_scale_size fires size_changed again from inside this
	# call - one pass is enough.
	if _applying:
		return
	_applying = true
	var wanted: int = width_for(css_size().x)
	var window: Window = get_window()
	var changed_width: bool = wanted != width
	width = wanted
	if window.content_scale_size.x != wanted:
		window.content_scale_size = Vector2i(wanted, BASE_HEIGHT)
	# Re-announce on every window resize (not just a width change): a taller
	# viewport moves bottom-anchored things even at the same width.
	changed.emit()
	if changed_width:
		print("Layout: logical width %d (css %s)" % [width, css_size()])
	_applying = false
