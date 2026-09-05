extends SceneTree
# Audio verification. Run via:
# godot --script res://tools/verify_audio.gd (NOT --headless).
#
# The village loop exists and is a real OGG that loops; the Audio autoload
# has Music and Sfx buses; under a verify script it is silent but still
# tracks which music a scene wants; switched on (with the bus muted so
# nothing is heard) a scene change crossfades between the two players and
# a scene mapped to the same track keeps it playing; the Hero tab's
# Music and Sounds sliders set the bus volumes and persist to
# user://settings.cfg; unknown sound effects are a harmless no-op.

func _initialize() -> void:
	var audio: Node = root.get_node("Audio")
	var sheet: CanvasLayer = root.get_node("CharacterSheet")
	await process_frame
	await process_frame

	print("Village loop file exists and loads as an OGG stream: ", ResourceLoader.exists("res://assets/music/village.ogg") and load("res://assets/music/village.ogg") is AudioStreamOggVorbis)
	var stream: AudioStreamOggVorbis = load("res://assets/music/village.ogg")
	print("Loop is between 45 s and 110 s long: ", stream.get_length() >= 45.0 and stream.get_length() <= 110.0)
	print("Bus layout: Music and Sfx under Master, MusicA/MusicB under Music, all from the layout file (none added at runtime): ", AudioServer.get_bus_index("Music") != -1 and AudioServer.get_bus_index("Sfx") != -1 and AudioServer.get_bus_send(AudioServer.get_bus_index("Music")) == "Master" and AudioServer.get_bus_send(AudioServer.get_bus_index("MusicA")) == "Music" and AudioServer.get_bus_send(AudioServer.get_bus_index("MusicB")) == "Music" and ResourceLoader.exists("res://default_bus_layout.tres"))
	print("Desktop keeps the crossfade (the web cuts between tracks): ", not audio.hard_switch)
	print("Silent under a verify script: ", not audio.enabled)

	# Scene -> music, tracked even while silent.
	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame
	print("The overworld asks for the village theme: ", audio.current_music() == "village")
	var world: Node = root.get_node("World")
	var ow_player: CharacterBody2D = overworld.get_node("YSort/Player")
	var home: Vector2 = ow_player.position
	ow_player.position = Vector2(world.WORLD_CENTER_X * 32 + 16, (world.WORLD_CENTER_Y - world.VALLEY_RADIUS - 4) * 32 + 16)
	await process_frame
	await process_frame
	print("Standing in Frostpeak on the overworld switches to the Frostpeak theme: ", audio.current_music() == "frostpeak" and ResourceLoader.exists("res://assets/music/frostpeak.ogg"))
	ow_player.position = Vector2((world.WORLD_CENTER_X + world.VALLEY_RADIUS + 4) * 32 + 16, world.WORLD_CENTER_Y * 32 + 16)
	await process_frame
	await process_frame
	var vw: AudioStreamOggVorbis = audio._load_music("verdantwood")
	print("Verdantwood keeps its intro: the file runs past the loop and repeats from 12.63 s: ", vw.loop and absf(vw.loop_offset - 12.63) < 0.01 and vw.get_length() > 60.0)
	var tt: AudioStreamOggVorbis = audio._load_music("title")
	print("The title screen has its own theme, intro kept, repeating from 20.91 s: ", audio.SCENE_MUSIC.get("Title", "") == "title" and tt.loop and absf(tt.loop_offset - 20.91) < 0.01 and tt.get_length() > 40.0)
	print("Standing in Verdantwood switches to its theme (interior mapped too): ", audio.current_music() == "verdantwood" and ResourceLoader.exists("res://assets/music/verdantwood.ogg") and audio.SCENE_MUSIC.get("VerdantwoodInterior", "") == "verdantwood")
	ow_player.position = Vector2(world.WORLD_CENTER_X * 32 + 16, (world.WORLD_CENTER_Y + world.VALLEY_RADIUS + 4) * 32 + 16)
	await process_frame
	await process_frame
	print("Standing in the Badlands switches to its theme (interior mapped too): ", audio.current_music() == "badlands" and ResourceLoader.exists("res://assets/music/badlands.ogg") and audio.SCENE_MUSIC.get("BadlandsInterior", "") == "badlands")
	ow_player.position = Vector2((world.WORLD_CENTER_X - world.VALLEY_RADIUS - 4) * 32 + 16, world.WORLD_CENTER_Y * 32 + 16)
	await process_frame
	await process_frame
	print("Standing in Gloomfen switches to its theme (interior mapped too): ", audio.current_music() == "gloomfen" and ResourceLoader.exists("res://assets/music/gloomfen.ogg") and audio.SCENE_MUSIC.get("GloomfenInterior", "") == "gloomfen")
	ow_player.position = home
	await process_frame
	await process_frame
	print("Back in the valley the village theme returns; the Frostpeak interior maps to its theme too: ", audio.current_music() == "village" and audio.SCENE_MUSIC.get("FrostpeakInterior", "") == "frostpeak")
	print("Battle loop file exists, 15-80 s: ", ResourceLoader.exists("res://assets/music/battle.ogg") and load("res://assets/music/battle.ogg").get_length() >= 15.0 and load("res://assets/music/battle.ogg").get_length() <= 80.0)
	var combat: Node = root.get_node("Combat")
	combat.start_combat(["dungeon_rat"])
	await process_frame
	print("A fight starting takes the music over: ", audio.current_music() == "battle")
	combat.fast = true
	while combat.in_combat:
		combat.player_run()
		await physics_frame
	await process_frame
	print("...and the village theme returns when it ends (running away: no sting): ", audio.current_music() == "village" and audio.last_sting == "")
	print("Victory sting file exists, 2-8 s, plays once (no loop): ", ResourceLoader.exists("res://assets/music/victory.ogg") and load("res://assets/music/victory.ogg").get_length() >= 2.0 and load("res://assets/music/victory.ogg").get_length() <= 8.0 and not load("res://assets/music/victory.ogg").loop)
	var character: Node = root.get_node("Character")
	combat.start_combat(["dungeon_rat"])
	await process_frame
	while combat.in_combat:
		character.stats.hp = 500
		combat.current_enemies[0].hp = 1
		combat.player_attack()
		await process_frame
	await process_frame
	print("Winning a fight asks for the victory sting: ", audio.last_sting == "victory")
	audio.last_sting = ""

	# Audible path, muted: crossfade players.
	var music_bus: int = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_mute(music_bus, true)
	audio.enabled = true
	audio.play_music("")
	await process_frame
	audio.play_music("village")
	await process_frame
	var p0: AudioStreamPlayer = audio._players[audio._active]
	print("Playing the village track on one player, looping, its sub-bus fading up: ", p0.playing and p0.stream is AudioStreamOggVorbis and p0.stream.loop and p0.volume_db == 0.0 and AudioServer.get_bus_volume_db(AudioServer.get_bus_index(audio.PLAYER_BUSES[audio._active])) > audio.SILENT_DB)
	# Audible path: the sting silences the music while it plays, then the
	# scene's track comes back.
	audio.play_sting("victory")
	await process_frame
	await process_frame
	print("While the sting plays the music is cleared and the sting player runs: ", audio.sting_playing() and audio.current_music() == "")
	await create_timer(load("res://assets/music/victory.ogg").get_length() + 0.3).timeout
	await process_frame
	await process_frame
	print("When the sting ends the overworld's theme comes back: ", not audio.sting_playing() and audio.current_music() == "village")
	await create_timer(1.4).timeout
	p0 = audio._players[audio._active]
	change_scene_to_packed(load("res://scenes/House.tscn"))
	await process_frame
	await process_frame
	await process_frame
	print("Entering the house (same track) keeps it playing without a restart: ", audio.current_music() == "village" and audio._players[audio._active] == p0 and p0.playing)
	change_scene_to_packed(load("res://scenes/Dungeon.tscn"))
	for i in range(90): # the maze generates on load; wait for the scene, then a frame for Audio to notice
		await process_frame
		if current_scene != null and current_scene.name == "Dungeon":
			break
	await process_frame
	await process_frame
	print("The dungeon plays its own theme (castle and hidden maze share it): ", audio.current_music() == "dungeon" and ResourceLoader.exists("res://assets/music/dungeon.ogg") and audio.SCENE_MUSIC.get("Castle", "") == "dungeon" and audio.SCENE_MUSIC.get("FinalBoss", "") == "dungeon")
	await create_timer(1.5).timeout
	print("...and the village player has stopped once the crossfade is done: ", not p0.playing and audio._players[audio._active].playing)
	audio.play_sfx("nothing_like_this")
	print("An unknown sound effect is a no-op: ", true)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Sfx"), true)
	audio.play_sfx("chop")
	await process_frame
	var sfx_playing := false
	for s in audio._sfx_pool:
		if s.playing and s.stream is AudioStreamWAV:
			sfx_playing = true
	print("The chop effect exists as a WAV and plays from the effects pool: ", ResourceLoader.exists("res://assets/sfx/chop.wav") and sfx_playing)
	for s in audio._sfx_pool:
		s.stop()
	var quests: Node = root.get_node("Quests")
	quests.quest_state["gather_wood"] = "active"
	quests._complete_quest("gather_wood")
	await process_frame
	var quest_sfx := false
	for s in audio._sfx_pool:
		if s.playing and s.stream.resource_path.ends_with("quest.wav"):
			quest_sfx = true
	print("Completing a quest plays the quest fanfare (2-5 s WAV): ", quest_sfx and load("res://assets/sfx/quest.wav").get_length() >= 2.0 and load("res://assets/sfx/quest.wav").get_length() <= 5.0)
	for s in audio._sfx_pool:
		s.stop()
	root.get_node("Inventory").add_item("healing_potion", 1)
	root.get_node("Shop").sell_item("healing_potion")
	await process_frame
	var coin_sfx := false
	for s in audio._sfx_pool:
		if s.playing and s.stream.resource_path.ends_with("coin.wav"):
			coin_sfx = true
	print("Selling to the Trader plays the coin (short WAV, under 1 s): ", coin_sfx and load("res://assets/sfx/coin.wav").get_length() < 1.0)
	# Buttons tap: a button added anywhere is hooked, and pressing it plays.
	var btn := Button.new()
	root.add_child(btn)
	await process_frame
	for s in audio._sfx_pool:
		s.stop()
	btn.pressed.emit()
	await process_frame
	var tapped := false
	for s in audio._sfx_pool:
		if s.playing and s.stream.resource_path.ends_with("tap.wav"):
			tapped = true
	print("Any button pressed plays the tap: ", btn.has_meta("tap_hooked") and tapped)
	btn.queue_free()
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Sfx"), false)

	# Sliders on the Hero tab set the buses and persist.
	change_scene_to_packed(load("res://scenes/Overworld.tscn"))
	await process_frame
	await process_frame
	sheet.open("character")
	await process_frame
	var slider: HSlider = sheet.stats_list.find_child("MusicSlider", true, false)
	var sfx_slider: HSlider = sheet.stats_list.find_child("SfxSlider", true, false)
	print("Hero tab has Music and Sounds sliders showing the current volumes: ", slider != null and sfx_slider != null and slider.value == round(audio.music_volume * 100.0))
	slider.value = 40
	await process_frame
	print("Dragging Music to 40 sets the bus to ~-8 dB and the setting: ", absf(AudioServer.get_bus_volume_db(music_bus) - linear_to_db(0.4)) < 0.01 and absf(audio.music_volume - 0.4) < 0.001)
	sfx_slider.value = 0
	await process_frame
	print("Sounds at 0 mutes the Sfx bus (-80 dB): ", AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Sfx")) <= -79.0)
	var cfg := ConfigFile.new()
	var loaded: bool = cfg.load(audio.SETTINGS_PATH) == OK
	print("Settings persisted to user://settings.cfg: ", loaded and absf(float(cfg.get_value("audio", "music", 0.0)) - 0.4) < 0.001 and float(cfg.get_value("audio", "sfx", 1.0)) == 0.0)
	root.get_texture().get_image().save_png("res://verify_audio_sliders.png")
	print("Saved verify_audio_sliders.png")
	# Restore the defaults so the next real session isn't muted.
	audio.set_music_volume(0.8)
	audio.set_sfx_volume(0.9)
	sheet.close()
	audio.enabled = false
	AudioServer.set_bus_mute(music_bus, false)
	quit()
