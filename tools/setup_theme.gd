extends SceneTree
# Builds resources/ui_theme.tres — the shared UI Theme every panel/dialogue
# builder script now draws from instead of hand-rolling its own StyleBoxFlat.
# Set as the project's global default theme (project.godot [gui] section),
# so plain Panel/Label/ProgressBar nodes pick it up automatically; the two
# Label variations and two ProgressBar variations are opted into explicitly
# via `node.theme_type_variation = &"Name"`.
# Run via: godot --headless --script res://tools/setup_theme.gd

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.06, 0.85)
	style.border_color = Color(0.7, 0.55, 0.2, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	return style

const GOLD := Color(0.7, 0.55, 0.2, 1.0)

func _box(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style

# A Button type variation with the same look in every state (hover a touch
# lighter, pressed a touch darker, disabled faded) so nothing falls back to
# Godot's default grey.
func _button_variation(theme: Theme, name: String, bg: Color, border: Color, width: int, radius: int, font_color: Color) -> void:
	theme.set_type_variation(name, "Button")
	theme.set_stylebox("normal", name, _box(bg, border, width, radius))
	theme.set_stylebox("hover", name, _box(bg.lightened(0.12), border, width, radius))
	theme.set_stylebox("pressed", name, _box(bg.darkened(0.15), border, width, radius))
	theme.set_stylebox("disabled", name, _box(Color(bg.r, bg.g, bg.b, bg.a * 0.5), Color(border.r, border.g, border.b, border.a * 0.5), width, radius))
	theme.set_stylebox("focus", name, StyleBoxEmpty.new())
	theme.set_color("font_color", name, font_color)
	theme.set_color("font_hover_color", name, font_color)
	theme.set_color("font_pressed_color", name, font_color)
	theme.set_color("font_disabled_color", name, Color(font_color.r, font_color.g, font_color.b, 0.5))

func _bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	return style

func _initialize() -> void:
	print("=== Theme setup starting ===")
	var theme := Theme.new()

	# Default Panel background — every Panel.new() picks this up with no
	# per-node override needed.
	theme.set_stylebox("panel", "Panel", _panel_style())

	# Gold section-title labels (panel/dialogue headers).
	theme.set_type_variation("PanelTitle", "Label")
	theme.set_color("font_color", "PanelTitle", Color(0.9, 0.75, 0.35))
	theme.set_font_size("font_size", "PanelTitle", 18)

	# Dim/secondary labels ("(empty)" placeholders, hint text).
	theme.set_type_variation("DimLabel", "Label")
	theme.set_color("font_color", "DimLabel", Color(0.6, 0.6, 0.6))

	# HP/MP stat bars (Character panel).
	theme.set_type_variation("HPBar", "ProgressBar")
	theme.set_stylebox("fill", "HPBar", _bar_style(Color(0.75, 0.15, 0.15, 1.0)))
	theme.set_stylebox("background", "HPBar", _bar_style(Color(0.2, 0.05, 0.05, 1.0)))

	theme.set_type_variation("MPBar", "ProgressBar")
	theme.set_stylebox("fill", "MPBar", _bar_style(Color(0.15, 0.35, 0.75, 1.0)))
	theme.set_stylebox("background", "MPBar", _bar_style(Color(0.05, 0.1, 0.2, 1.0)))

	# Experience bar (HUD, under the MP bar) - gold.
	theme.set_type_variation("XPBar", "ProgressBar")
	theme.set_stylebox("fill", "XPBar", _bar_style(Color(0.85, 0.65, 0.2, 1.0)))
	theme.set_stylebox("background", "XPBar", _bar_style(Color(0.2, 0.15, 0.05, 1.0)))

	# --- Character-sheet kit (UI redesign Phase 1) - the slot / tab / detail
	# pane language every redesigned screen shares. Buttons need all four
	# states or Godot's default grey shows through on hover/press. ---
	_button_variation(theme, "SlotButton", Color(0.16, 0.14, 0.11, 0.95), GOLD, 1, 5, Color(1, 1, 1))
	_button_variation(theme, "SlotButtonSelected", Color(0.32, 0.26, 0.14, 1.0), Color(1.0, 0.85, 0.4), 3, 5, Color(1, 1, 1))
	_button_variation(theme, "TabButton", Color(0.2, 0.17, 0.12, 0.95), GOLD, 1, 6, Color(1, 1, 1))
	_button_variation(theme, "TabButtonActive", Color(0.7, 0.55, 0.2, 0.95), Color(0.9, 0.75, 0.35), 2, 6, Color(0.1, 0.08, 0.04))
	_button_variation(theme, "PrimaryButton", Color(0.7, 0.55, 0.2, 0.95), Color(0.9, 0.75, 0.35), 2, 6, Color(0.1, 0.08, 0.04))
	_button_variation(theme, "SecondaryButton", Color(0.2, 0.17, 0.12, 0.95), GOLD, 1, 6, Color(1, 1, 1))
	theme.set_type_variation("DetailPanel", "Panel")
	var detail := _box(Color(0.1, 0.09, 0.07, 0.9), GOLD, 1, 8)
	detail.set_content_margin_all(0)
	theme.set_stylebox("panel", "DetailPanel", detail)

	var err := ResourceSaver.save(theme, "res://resources/ui_theme.tres")
	print("ui_theme.tres saved: ", err)
	print("=== Setup complete ===")
	quit()
