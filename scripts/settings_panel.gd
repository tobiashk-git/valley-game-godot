extends CanvasLayer
# Autoload — the window behind the cog (panel_buttons.gd in play, title.gd
# on the title screen): Music and Sounds sliders feeding the Audio buses
# (Audio persists them to user://settings.cfg), the audio engine's status
# line, and - in play only - a Game section: the save's age, Save now
# (reads "Saved!" for a moment), Load last save, and Quit to title (asks
# "Sure?" first, then saves and quits). These used to sit in a "Game" block
# at the top of the Hero tab's stats column, then as three toolbar buttons;
# the user asked for a single cog instead.

const FEEDBACK_SECONDS := 1.6
const CONFIRM_SECONDS := 3.0

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
@onready var game_section: VBoxContainer = $Window/Rows/Game
@onready var save_line: Label = $Window/Rows/Game/SaveLine
@onready var save_btn: Button = $Window/Rows/Game/SaveRow/SaveBtn
@onready var load_btn: Button = $Window/Rows/Game/SaveRow/LoadBtn
@onready var quit_btn: Button = $Window/Rows/Game/QuitBtn

var confirm_quit := false
var _ignore_close_this_frame := false
var _save_token := 0
var _quit_token := 0

func _ready() -> void:
	layer = 50 # above the tracker and system bar, under the nap panel (90) and intro (100)
	dim.visible = false
	window.visible = false
	close_btn.pressed.connect(close)
	save_btn.pressed.connect(_on_save)
	load_btn.pressed.connect(_on_load)
	quit_btn.pressed.connect(_on_quit)
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
	_reset_quit()
	refresh()
	_apply_layout()
	dim.visible = true
	window.visible = true
	_ignore_close_this_frame = true

func close() -> void:
	_reset_quit()
	dim.visible = false
	window.visible = false

func toggle() -> void:
	if is_open():
		close()
	else:
		open()

# The Game section only makes sense with a game running (not on the title).
func in_game() -> bool:
	return GameState.is_gameplay()

func refresh() -> void:
	music_slider.set_value_no_signal(round(Audio.music_volume * 100.0))
	music_value.text = str(int(music_slider.value))
	sfx_slider.set_value_no_signal(round(Audio.sfx_volume * 100.0))
	sfx_value.text = str(int(sfx_slider.value))
	audio_line.text = Audio.debug_state()
	game_section.visible = in_game()
	save_line.text = SaveSystem.saved_ago_text()
	load_btn.disabled = not SaveSystem.has_save()

func _on_save() -> void:
	var ok: bool = SaveSystem.save_game()
	save_line.text = SaveSystem.saved_ago_text()
	load_btn.disabled = not SaveSystem.has_save()
	_save_token += 1
	var token: int = _save_token
	save_btn.text = "Saved!" if ok else "Not now"
	save_btn.disabled = true
	get_tree().create_timer(FEEDBACK_SECONDS).timeout.connect(func() -> void:
		if token == _save_token:
			save_btn.text = "Save now"
			save_btn.disabled = false)

func _on_load() -> void:
	close()
	SaveSystem.load_game()

# Quit asks first - a stray tap on a phone would otherwise drop you to the
# title - then saves and goes.
func _on_quit() -> void:
	if not confirm_quit:
		confirm_quit = true
		_quit_token += 1
		var token: int = _quit_token
		quit_btn.text = "Sure? Save and quit"
		quit_btn.theme_type_variation = &"PrimaryButton"
		get_tree().create_timer(CONFIRM_SECONDS).timeout.connect(func() -> void:
			if token == _quit_token:
				_reset_quit())
		return
	close()
	SaveSystem.quit_to_title()

func _reset_quit() -> void:
	confirm_quit = false
	_quit_token += 1
	quit_btn.text = "Quit to title"
	quit_btn.theme_type_variation = &"SecondaryButton"

func _apply_layout() -> void:
	var w: float
	var h: float = 400.0 if in_game() else 250.0
	if Layout.is_narrow():
		w = Layout.width - 24.0
		window.position = Vector2(12, 56)
	else:
		w = 360.0
		window.position = Vector2((Layout.width - w) / 2.0, 100)
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
