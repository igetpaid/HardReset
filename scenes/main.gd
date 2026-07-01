extends Control

@onready var play_button = $PlayButton
@onready var load_dialog = $LoadDialog
@onready var yes_button = $LoadDialog/YesButton
@onready var no_button = $LoadDialog/NoButton
@onready var mobile_toggle = $MobileToggle

const MobileSizer = preload("res://tools/mobile_sizer.gd")

func _ready():
	MobileSizer.enlarge_scene(self)
	load_dialog.visible = false
	play_button.pressed.connect(_on_play_pressed)
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(_on_no_pressed)
	mobile_toggle.pressed.connect(_on_mobile_toggle)

func _on_mobile_toggle():
	MobileSizer.force_enabled = not MobileSizer.force_enabled
	if MobileSizer.force_enabled:
		MobileSizer.enlarge_scene(self)
		mobile_toggle.text = "Mobile ON"
	else:
		# Revert: reload scene
		get_tree().reload_current_scene()

func _on_play_pressed():
	if SaveManager.has_save():
		load_dialog.visible = true
	else:
		_start_new_game()

func _on_yes_pressed():
	load_dialog.visible = false
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_no_pressed():
	load_dialog.visible = false
	SaveManager.delete_save()
	_start_new_game()

func _start_new_game():
	MinigameManager.player_money = 0
	MinigameManager.current_exp = 0
	MinigameManager.current_level = 1
	MinigameManager.exp_to_next_level = 100
	SaveManager.delete_save()
	get_tree().change_scene_to_file("res://scenes/intro.tscn")

func _on_stats_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/stats.tscn")
	#get_tree().change_scene_to_file("res://scenes/ending.tscn")

func _on_exit_button_pressed() -> void:
	get_tree().quit()
