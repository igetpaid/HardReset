extends Node

const SETTINGS_PATH := "user://audio_settings.cfg"

var music_volume: float = 0.8
var sfx_volume: float = 0.8

var music_bus: int
var sfx_bus: int

var _music_player: AudioStreamPlayer
var _current_music_path: String = ""


func _ready() -> void:
	_setup_busses()

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)

	load_settings()


func _setup_busses() -> void:
	if AudioServer.get_bus_count() == 0:
		AudioServer.add_bus()

	if AudioServer.get_bus_name(0) != "Master":
		AudioServer.set_bus_name(0, "Master")

	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		music_bus = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(music_bus, "Music")
	else:
		music_bus = AudioServer.get_bus_index("Music")

	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		sfx_bus = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(sfx_bus, "SFX")
	else:
		sfx_bus = AudioServer.get_bus_index("SFX")

	# Делаем Music не наследуемым от Master (чтобы не было двойной громкости)
	AudioServer.set_bus_send(music_bus, &"Master")
	AudioServer.set_bus_send(sfx_bus, &"Master")


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	var db := linear_to_db(music_volume)
	AudioServer.set_bus_volume_db(music_bus, db)
	save_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	var db := linear_to_db(sfx_volume)
	AudioServer.set_bus_volume_db(sfx_bus, db)
	save_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.save(SETTINGS_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		music_volume = cfg.get_value("audio", "music_volume", 0.8)
		sfx_volume = cfg.get_value("audio", "sfx_volume", 0.8)

	set_music_volume(music_volume)
	set_sfx_volume(sfx_volume)


func play_music(path: String) -> void:
	if _current_music_path == path and _music_player.playing:
		return

	var stream := load(path) as AudioStream
	if not stream:
		return

	_current_music_path = path
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()
	_current_music_path = ""


func is_music_playing() -> bool:
	return _music_player.playing


# Переносит AudioStreamPlayer на шину SFX.
static func assign_to_sfx(player: AudioStreamPlayer) -> void:
	player.bus = "SFX"
