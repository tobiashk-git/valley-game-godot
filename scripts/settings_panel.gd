extends CanvasLayer
# Autoload — the Settings window, opened from the system bar's Settings
# button (panel_buttons.gd): Music and Sounds sliders feeding the Audio
# buses (Audio persists them to user://settings.cfg), the audio engine's
# status line, and Load last save with the save's age. These used to sit in
# a "Game" block at the top of the Hero tab's stats column, crowding the
# stats (user feedback) - the sheet now shows stats only.

@onready var dim: ColorRect = $Dim
@onready var window: Panel = $Window
@onready var title_label: Label = $Window/TitleLabel
@onready var close_btn: Button = $Window/CloseBtn
@onready var rows: VBoxContainer = $Window/Rows
@onready var music_slider: HSlider = $Window/Rows/MusicRow/MusicSlider
@onready var music_value: Label = $Window/Rows/MusicRow/MusicValue
@onready var sfx_slider: HSlider = $Window/Rows/SfxRow/SfxSlider
@onready var sfx_value: Label = $Window/Rows/SfxRow/SfxValue
@onready var audio_line: Label = $Window/Rows/AudioLine
@onready var save_line: Label = $Window/Rows/SaveLine
@onready var load_btn: Button = $Window/Rows/LoadBtn

var _ignore_close_this_frame := false

func _ready() -> void:
	layer = 50 # above the tracker and system bar, under the nap panel (90) and intro (100)
	dim.visible = false
	window.visible = false
	close_btn.pressed.connect(close)
	load_btn.pressed.connect(_on_load)
	music_slider.value_changed.connect(func(v: float) -> void:
		Audio.set_music_volume(v / 100.0)
		music_value.text = str(int(v)))
	sfx_slider.value_changed.connect(func(v: float) -> void:
		Audio.set_sfx_volume(v / 100.0)
		sfx_value.text = str(int(v)))
	Layout.changed.connect(_apply_layout)
	_apply_layout()

func is_open() -> bool:
	return window.visible

func open() -> void:
	_apply_layout()
	refresh()
	dim.visible = true
	window.visible = true
	_ignore_close_this_frame = true

func close() -> void:
	dim.visible = false
	window.visible = false

func toggle() -> void:
	if is_open():
		close()
	else:
		open()

func refresh() -> void:
	music_slider.set_value_no_signal(round(Audio.music_volume * 100.0))
	music_value.text = str(int(music_slider.value))
	sfx_slider.set_value_no_signal(round(Audio.sfx_volume * 100.0))
	sfx_value.text = str(int(sfx_slider.value))
	audio_line.text = Audio.debug_state()
	save_line.text = SaveSystem.saved_ago_text()
	load_btn.disabled = not SaveSystem.has_save()

func _on_load() -> void:
	close()
	SaveSystem.load_game()

func _apply_layout() -> void:
	var w: float
	var h := 330.0
	if Layout.is_narrow():
		w = Layout.width - 24.0
		window.position = Vector2(12, 56)
	else:
		w = 360.0
		window.position = Vector2((Layout.width - w) / 2.0, 120)
	window.size = Vector2(w, h)
	title_label.position = Vector2(20, 14)
	close_btn.position = Vector2(w - 44.0, 10)
	rows.position = Vector2(20, 58)
	rows.size = Vector2(w - 40.0, h - 78.0)

# Esc / E close it, same as the kit windows; the frame it opened on is
# skipped so the tap that opened it doesn't also close it.
func _process(_delta: float) -> void:
	if not window.visible:
		return
	if _ignore_close_this_frame:
		_ignore_close_this_frame = false
		return
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_cancel"):
		close()
