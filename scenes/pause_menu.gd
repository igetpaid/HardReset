extends Control

@onready var music_slider = $Panel/MusicSlider
@onready var sfx_slider = $Panel/SfxSlider
@onready var close_button = $Panel/CloseButton
@onready var save_exit_button = $Panel/SaveExitButton


func _ready() -> void:
	music_slider.value = SoundManager.music_volume
	sfx_slider.value = SoundManager.sfx_volume

	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	close_button.pressed.connect(_on_close_pressed)
	save_exit_button.pressed.connect(_on_save_exit_pressed)

	_style_sliders()
	_style_buttons()


func _on_music_slider_changed(value: float) -> void:
	SoundManager.set_music_volume(value)


func _on_sfx_slider_changed(value: float) -> void:
	SoundManager.set_sfx_volume(value)


func _on_close_pressed() -> void:
	visible = false


func _on_save_exit_pressed() -> void:
	SaveManager.save_game(
		MinigameManager.player_money,
		MinigameManager.current_exp,
		MinigameManager.current_level
	)
	get_tree().quit()


func _style_sliders() -> void:
	for slider in [music_slider, sfx_slider]:
		var track := StyleBoxFlat.new()
		track.bg_color = Color(0.3, 0.3, 0.33)
		track.corner_radius_top_left = 4
		track.corner_radius_top_right = 4
		track.corner_radius_bottom_left = 4
		track.corner_radius_bottom_right = 4
		track.content_margin_left = 0
		track.content_margin_right = 0
		track.content_margin_top = 0
		track.content_margin_bottom = 0

		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.3, 0.7, 0.3)
		fill.corner_radius_top_left = 4
		fill.corner_radius_top_right = 4
		fill.corner_radius_bottom_left = 4
		fill.corner_radius_bottom_right = 4
		fill.content_margin_left = 0
		fill.content_margin_right = 0
		fill.content_margin_top = 0
		fill.content_margin_bottom = 0

		var grabber := StyleBoxFlat.new()
		grabber.bg_color = Color(1, 1, 1)
		grabber.corner_radius_top_left = 8
		grabber.corner_radius_top_right = 8
		grabber.corner_radius_bottom_left = 8
		grabber.corner_radius_bottom_right = 8

		slider.add_theme_stylebox_override("slider", track)
		slider.add_theme_stylebox_override("grabber_area", fill)
		slider.add_theme_stylebox_override("grabber", grabber)


func _style_buttons() -> void:
	for btn in [close_button, save_exit_button]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.5, 0.2)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 6
		style.content_margin_bottom = 6

		var hover := style.duplicate()
		hover.bg_color = Color(0.25, 0.6, 0.25)

		var pressed := style.duplicate()
		pressed.bg_color = Color(0.15, 0.4, 0.15)

		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", pressed)
