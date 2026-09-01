extends CanvasLayer
# Autoload — toggled with the "toggle_map" action (M key). Lists every
# discovered POI with a Fast Travel button, plus a "you are here" status
# line, port of worldmap.js's renderWorldMap(). Openable from anywhere
# (Overworld or any interior) except mid-combat, matching every other panel.

@onready var panel: Panel = $Panel
@onready var status_label: Label = $Panel/Margin/VBox/StatusLabel
@onready var list: VBoxContainer = $Panel/Margin/VBox/List

func _ready() -> void:
	panel.visible = false

func _refresh() -> void:
	status_label.text = "You are in %s" % WorldMap.current_location_name()

	for child in list.get_children():
		child.queue_free()
	var any := false
	for poi_id in WorldMap.POI_NAMES.keys():
		if not WorldMap.is_discovered(poi_id):
			continue
		any = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		list.add_child(row)

		var label := Label.new()
		label.text = WorldMap.POI_NAMES[poi_id]
		label.custom_minimum_size = Vector2(180, 0)
		label.add_theme_font_size_override("font_size", 14)
		row.add_child(label)

		var btn := Button.new()
		btn.text = "Fast Travel"
		btn.pressed.connect(_on_travel.bind(poi_id))
		row.add_child(btn)

	if not any:
		var empty_label := Label.new()
		empty_label.text = "(nothing discovered yet)"
		empty_label.theme_type_variation = &"DimLabel"
		list.add_child(empty_label)

func _on_travel(poi_id: String) -> void:
	panel.visible = false
	WorldMap.travel_to(poi_id)

func toggle_open() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		_refresh()

func _process(_delta: float) -> void:
	if not Combat.in_combat and Input.is_action_just_pressed("toggle_map"):
		toggle_open()
