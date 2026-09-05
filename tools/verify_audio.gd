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
	print("Music and Sfx buses exist on top of Master: ", AudioServer.get_bus_index("Music") != -1 and AudioServer.get_bus_index("Sfx") != -1 and AudioServer.get_bus_send(AudioServer.get_bus_index("Music")) == "Master")
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
	print("...and the village theme returns when it ends: ", audio.current_music() == "village")

	# Audible path, muted: crossfade players.
	var music_bus: int = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_mute(music_bus, true)
	audio.enabled = true
	audio.play_music("")
	await process_frame
	audio.play_music("village")
	await process_frame
	var p0: AudioStreamPlayer = audio._players[audio._active]
	print("Playing the village track on one player, looping: ", p0.playing and p0.stream is AudioStreamOggVorbis and p0.stream.loop)
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
	print("The dungeon has no track yet: the music is cleared: ", audio.current_music() == "")
	await create_timer(1.5).timeout
	print("...and the old player has stopped once the fade is done: ", not p0.playing)
	audio.play_sfx("nothing_like_this")
	print("An unknown sound effect is a no-op: ", true)

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
