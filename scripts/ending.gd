extends Control
# The completion screen (2026-09-12): Oliver's illustration at the top with
# Luigi and Eden either side, "Oliver has conquered the Valley of
# Adventure", a strip of every boss he put to sleep scrolling past, and Play
# again (a new game) / Quit (the title). Built in code; Ending.tscn is just
# this script on a Control. The in-game overlays stay hidden here (no
# YSort/Player, so GameState.is_gameplay() is false).

const OLIVER := "res://assets/oliver_portrait.png"
const LUIGI := "res://assets/portraits/luigi.png"
const EDEN := "res://assets/portraits/eden.png"
const HEADLINE := "Oliver has conquered the Valley of Adventure"
# Story order.
const BOSSES := ["golden_plains_boss", "dungeon_boss", "frostpeak_boss", "verdantwood_maze_guardian_1", "verdantwood_boss", "badlands_boss", "gloomfen_boss", "castle_boss", "final_boss"]
const STRIP_SPEED := 40.0 # px per second

var bg: ColorRect
var oliver: TextureRect
var luigi: TextureRect
var eden: TextureRect
var headline: Label
var sub: Label
var strip_clip: Control
var strip_row: HBoxContainer
var strip_row2: HBoxContainer
var play_btn: Button
var quit_btn: Button
var beaten: Array = []
var _strip_w := 0.0

func _ready() -> void:
	bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.09, 0.07, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	oliver = _figure("Oliver", OLIVER)
	luigi = _figure("Luigi", LUIGI)
	eden = _figure("Eden", EDEN)
	headline = Label.new()
	headline.name = "Headline"
	headline.text = HEADLINE
	headline.theme_type_variation = &"PanelTitle"
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(headline)
	sub = Label.new()
	sub.name = "Sub"
	sub.theme_type_variation = &"DimLabel"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)
	strip_clip = Control.new()
	strip_clip.name = "BossStrip"
	strip_clip.clip_contents = true
	add_child(strip_clip)
	strip_row = _build_strip("Row")
	strip_row2 = _build_strip("Row2")
	play_btn = Button.new()
	play_btn.name = "PlayAgainBtn"
	play_btn.text = "Play again"
	play_btn.theme_type_variation = &"PrimaryButton"
	play_btn.pressed.connect(_on_play_again)
	add_child(play_btn)
	quit_btn = Button.new()
	quit_btn.name = "QuitBtn"
	quit_btn.text = "Quit to title"
	quit_btn.theme_type_variation = &"SecondaryButton"
	quit_btn.pressed.connect(_on_quit)
	add_child(quit_btn)
	Layout.changed.connect(_apply_layout)
	_apply_layout()

func _figure(node_name: String, path: String) -> TextureRect:
	var t := TextureRect.new()
	t.name = node_name
	if ResourceLoader.exists(path):
		t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(t)
	return t

# One run of the bosses Oliver put to sleep, each a portrait over its name.
func _build_strip(node_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = node_name
	row.add_theme_constant_override("separation", 18)
	var enemies: Node = get_node("/root/Enemies")
	beaten = []
	for boss_id in BOSSES:
		if not GameState.boss_defeated.get(boss_id, false):
			continue
		beaten.append(boss_id)
		var def: Dictionary = enemies.BOSSES[boss_id]
		var box := VBoxContainer.new()
		box.name = boss_id.to_pascal_case()
		box.add_theme_constant_override("separation", 4)
		var pic := TextureRect.new()
		pic.name = "Art"
		if ResourceLoader.exists(def.sprite):
			pic.texture = load(def.sprite)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		pic.custom_minimum_size = Vector2(96, 96)
		box.add_child(pic)
		var name_label := Label.new()
		name_label.name = "Name"
		name_label.text = def.name
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.custom_minimum_size = Vector2(110, 0)
		box.add_child(name_label)
		row.add_child(box)
	strip_clip.add_child(row)
	return row

func _apply_layout() -> void:
	var w: float = Layout.width
	var h: float = Layout.size().y
	var narrow: bool = Layout.is_narrow()
	var fig_h: float = 200.0 if narrow else 260.0
	var bust: float = 84.0 if narrow else 120.0
	var top: float = 16.0 if narrow else 28.0
	var fig_w: float = fig_h * 156.0 / 370.0
	oliver.position = Vector2((w - fig_w) / 2.0, top)
	oliver.size = Vector2(fig_w, fig_h)
	var gap: float = 12.0 if narrow else 30.0
	luigi.position = Vector2((w - fig_w) / 2.0 - gap - bust, top + fig_h - bust)
	luigi.size = Vector2(bust, bust)
	eden.position = Vector2((w + fig_w) / 2.0 + gap, top + fig_h - bust)
	eden.size = Vector2(bust, bust)
	var y: float = top + fig_h + 14.0
	headline.position = Vector2(20, y)
	headline.size = Vector2(w - 40.0, 64)
	headline.add_theme_font_size_override("font_size", 22 if narrow else 28)
	y += 68.0
	sub.text = "%d %s put to sleep along the way" % [beaten.size(), "boss" if beaten.size() == 1 else "bosses"]
	sub.position = Vector2(20, y)
	sub.size = Vector2(w - 40.0, 20)
	y += 30.0
	strip_clip.position = Vector2(0, y)
	strip_clip.size = Vector2(w, 130)
	_strip_w = strip_row.get_combined_minimum_size().x + 18.0
	strip_row.position = Vector2(0, 0)
	strip_row2.position = Vector2(_strip_w, 0)
	y += 146.0
	var bw: float = minf(280.0, w - 40.0)
	play_btn.position = Vector2((w - bw) / 2.0, y)
	play_btn.size = Vector2(bw, 44)
	quit_btn.position = Vector2((w - bw) / 2.0, y + 52.0)
	quit_btn.size = Vector2(bw, 44)
	if quit_btn.position.y + 44.0 > h - 8.0:
		# A short phone: pull the figures up a little.
		var over: float = quit_btn.position.y + 44.0 - (h - 8.0)
		for c in [oliver, luigi, eden, headline, sub, strip_clip, play_btn, quit_btn]:
			c.position.y -= over

# The strip drifts left forever: two identical rows, wrapped end to end.
func _process(delta: float) -> void:
	if _strip_w <= 0.0 or beaten.is_empty():
		return
	for row in [strip_row, strip_row2]:
		row.position.x -= STRIP_SPEED * delta
		if row.position.x <= -_strip_w:
			row.position.x += _strip_w * 2.0

func _on_play_again() -> void:
	SaveSystem.new_game()

func _on_quit() -> void:
	get_tree().change_scene_to_file("res://scenes/Title.tscn")
