extends Control

@onready var close_button = $Panel/CloseButton
@onready var save_exit_button = $Panel/SaveExitButton


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	save_exit_button.pressed.connect(_on_save_exit_pressed)

	_style_buttons()


func _on_close_pressed() -> void:
	visible = false


func _on_save_exit_pressed() -> void:
	SaveManager.save_game(
		MinigameManager.player_money,
		MinigameManager.current_exp,
		MinigameManager.current_level
	)
	get_tree().quit()


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
