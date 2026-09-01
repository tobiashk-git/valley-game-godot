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

	var err := ResourceSaver.save(theme, "res://resources/ui_theme.tres")
	print("ui_theme.tres saved: ", err)
	print("=== Setup complete ===")
	quit()
