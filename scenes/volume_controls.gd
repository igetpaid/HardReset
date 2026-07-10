extends Control

@onready var music_slider: HSlider = $MusicSlider
@onready var sfx_slider: HSlider = $SfxSlider


func _ready() -> void:
	music_slider.value = SoundManager.music_volume
	sfx_slider.value = SoundManager.sfx_volume

	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)


func _on_music_changed(value: float) -> void:
	SoundManager.set_music_volume(value)


func _on_sfx_changed(value: float) -> void:
	SoundManager.set_sfx_volume(value)
