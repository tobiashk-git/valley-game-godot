extends Node
# Autoload "Audio" - music and sound effects.
#
# Music: one looping track per situation (MUSIC), chosen by the current
# scene (SCENE_MUSIC); a fight overrides with "battle" and the scene's
# track comes back when it ends. Two players crossfade so a scene change never cuts a track
# dead; a scene that maps to the track already playing just keeps it
# going. Sound effects: a small pool of players over the SFX table (empty
# until the first effects land - play_sfx() of an unknown id is a no-op).
#
# Buses (res://default_bus_layout.tres): Music and Sfx under Master carry
# the Hero tab's sliders; MusicA and MusicB under Music hold one player
# each, and the crossfade is done on THOSE bus volumes. Web-build facts
# behind this shape (found with an analyser tapped on the page's output):
# a bus added at runtime made the engine's web audio graph unplug the
# master output (total silence); and once a sample is playing on the web
# NO later volume change is honoured - neither the player's volume_db nor
# any bus volume - so the web gets a clean cut between tracks instead of a
# crossfade, and the Music slider restarts the track at its position so
# the new bus volume is picked up. Desktop keeps the crossfade. The
# settings persist in user://settings.cfg. On the web the browser only unmutes after the
# player's first tap - Godot resumes the audio context itself.
#
# Under a verify script nothing is audible (`enabled` off) but the choice
# of track is still tracked (current_music()) so verifies can assert it.

const SETTINGS_PATH := "user://settings.cfg"
const CROSSFADE_SECONDS := 1.2
const PLAYER_BUSES := ["MusicA", "MusicB"]
const SILENT_DB := -40.0

# A plain path loops whole; {"path", "loop_offset"} plays its intro once and
# repeats from the offset (tools/make_music_loop.py --keep-intro).
const MUSIC := {
	"village": "res://assets/music/village.ogg",
	"battle": "res://assets/music/battle.ogg",
	"frostpeak": "res://assets/music/frostpeak.ogg",
	"verdantwood": {"path": "res://assets/music/verdantwood.ogg", "loop_offset": 12.63},
	"badlands": "res://assets/music/badlands.ogg",
	"gloomfen": "res://assets/music/gloomfen.ogg",
}

static func music_path(id: String) -> String:
	var entry = MUSIC[id]
	return entry.path if entry is Dictionary else entry

static func _load_music(id: String):
	var entry = MUSIC[id]
	var stream = load(music_path(id))
	if stream != null and "loop" in stream:
		stream.loop = true
		if entry is Dictionary and "loop_offset" in stream:
			stream.loop_offset = float(entry.loop_offset)
	return stream
# Scene name -> music id. Until more tracks exist the village theme carries
# the valley and the houses; interiors and the title stay quiet.
const SCENE_MUSIC := {
	"Title": "village",
	"Overworld": "village",
	"House": "village",
	"ElderHouse": "village",
	"TraderHouse": "village",
	"BlacksmithHouse": "village",
	"FrostpeakInterior": "frostpeak",
	"VerdantwoodInterior": "verdantwood",
	"BadlandsInterior": "badlands",
	"GloomfenInterior": "gloomfen",
}
# On the overworld the track follows the biome under Oliver's feet (the
# valley keeps the village theme until it has its own); biomes without a
# track yet fall back to the valley's.
const ZONE_MUSIC := {
	World.Zone.FROSTPEAK: "frostpeak",
	World.Zone.VERDANTWOOD: "verdantwood",
	World.Zone.BADLANDS: "badlands",
	World.Zone.GLOOMFEN: "gloomfen",
}
const SFX := {}

var enabled := true
var hard_switch := false # web: cut between tracks, no fades (see above)
var music_volume := 0.8 # 0..1
var sfx_volume := 0.9
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _current := ""
var _fade: Tween = null
var _sfx_pool: Array[AudioStreamPlayer] = []

func _ready() -> void:
	enabled = get_tree().get_script() == null
	hard_switch = OS.has_feature("web")
	for bus_name in ["Music", "MusicA", "MusicB", "Sfx"]:
		_ensure_bus(bus_name)
	for i in range(2):
		var p := AudioStreamPlayer.new()
		p.name = "Music%d" % i
		p.bus = PLAYER_BUSES[i]
		add_child(p)
		_players.append(p)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(PLAYER_BUSES[i]), SILENT_DB)
	for i in range(4):
		var s := AudioStreamPlayer.new()
		s.name = "Sfx%d" % i
		s.bus = "Sfx"
		add_child(s)
		_sfx_pool.append(s)
	_load_settings()
	_apply_volumes()

# The buses come from res://default_bus_layout.tres so they exist before any
# playback. Adding a bus at RUNTIME broke the web build: the engine's web
# audio graph disconnected the master output from the speakers and wired
# it into the new bus instead (silence on every browser). This is only a
# fallback for a missing layout.
func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	push_warning("Audio bus '%s' missing from the bus layout - adding at runtime (silent on the web)" % bus_name)
	AudioServer.add_bus()
	var idx: int = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")

func current_music() -> String:
	return _current

func _process(_delta: float) -> void:
	play_music(wanted_music())

# What should be playing right now: the fight, else the scene's track.
func wanted_music() -> String:
	if Combat.in_combat:
		return "battle"
	var scene: Node = get_tree().current_scene
	if scene == null:
		return _current # mid scene change: hold whatever plays
	if HUD.BIOME_SCENES.has(scene.name):
		var player: Node2D = scene.get_node_or_null("YSort/Player")
		if player != null:
			var zone: int = World.biome_at(floori(player.position.x / 32.0), floori(player.position.y / 32.0)).zone
			if ZONE_MUSIC.has(zone):
				return ZONE_MUSIC[zone]
	return SCENE_MUSIC.get(scene.name, "")

# Switch to a track ("" = fade out to silence). The same track keeps playing.
func play_music(id: String) -> void:
	if id == _current:
		return
	_current = id
	if not enabled:
		return
	var outgoing: AudioStreamPlayer = _players[_active]
	var out_bus: int = AudioServer.get_bus_index(PLAYER_BUSES[_active])
	_active = 1 - _active
	var incoming: AudioStreamPlayer = _players[_active]
	var in_bus: int = AudioServer.get_bus_index(PLAYER_BUSES[_active])
	if _fade != null:
		_fade.kill()
	if hard_switch:
		outgoing.stop()
		AudioServer.set_bus_volume_db(out_bus, SILENT_DB)
		if id != "" and MUSIC.has(id):
			incoming.stream = _load_music(id)
			incoming.volume_db = 0.0
			AudioServer.set_bus_volume_db(in_bus, 0.0)
			incoming.play()
		return
	_fade = create_tween()
	if outgoing.playing:
		_fade.tween_method(func(db: float) -> void: AudioServer.set_bus_volume_db(out_bus, db), AudioServer.get_bus_volume_db(out_bus), SILENT_DB, CROSSFADE_SECONDS)
		_fade.parallel()
	if id != "" and MUSIC.has(id):
		incoming.stream = _load_music(id)
		incoming.volume_db = 0.0
		AudioServer.set_bus_volume_db(in_bus, SILENT_DB)
		incoming.play()
		_fade.tween_method(func(db: float) -> void: AudioServer.set_bus_volume_db(in_bus, db), SILENT_DB, 0.0, CROSSFADE_SECONDS)
	_fade.tween_callback(func() -> void:
		if outgoing.playing and outgoing != incoming:
			outgoing.stop())

func play_sfx(id: String) -> void:
	if not enabled or not SFX.has(id):
		return
	for s in _sfx_pool:
		if not s.playing:
			s.stream = load(SFX[id])
			s.play()
			return
	_sfx_pool[0].stream = load(SFX[id])
	_sfx_pool[0].play()

# One line for the Hero tab: what the game is trying to play and, on the
# web, whether the browser's audio context is actually running (phones
# keep it suspended until the first tap, and an iPhone's silent switch
# mutes it outright - neither shows up any other way).
func debug_state() -> String:
	var playing := false
	for p in _players:
		if p.playing:
			playing = true
	var line: String = "Audio: %s, %s, %d kHz%s" % ["silence" if _current == "" else _current, "playing" if playing else "stopped", int(AudioServer.get_mix_rate() / 1000.0), "" if enabled else " (test mute)"]
	if OS.has_feature("web"):
		# The export's head_include captures the engine's own context as
		# window.__godotCtx, resumes it inside every tap, and taps an
		# analyser onto the output so the actual signal level is readable.
		var state = JavaScriptBridge.eval("window.__godotCtx ? window.__godotCtx.state : 'not captured'", true)
		var level = JavaScriptBridge.eval("window.__godotLevel ? window.__godotLevel() : -1", true)
		line += "
Browser %s, output level %.3f" % [str(state), float(level)]
	return line

# --- settings ---

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()
	_save_settings()
	if hard_switch:
		# The web only reads bus volumes when a sample starts: restart the
		# track where it is so the new level applies.
		var p: AudioStreamPlayer = _players[_active]
		if p.playing:
			var pos: float = p.get_playback_position()
			p.stop()
			p.play(pos)

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()
	_save_settings()

static func _to_db(v: float) -> float:
	return linear_to_db(v) if v > 0.001 else -80.0

func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), _to_db(music_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Sfx"), _to_db(sfx_volume))

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	music_volume = clampf(float(cfg.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)

func _save_settings() -> void:
	if not enabled:
		return
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(SETTINGS_PATH)
