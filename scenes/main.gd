extends Control

enum MenuState { MENU, SETTINGS }
var current_state = MenuState.MENU

@onready var menu_background = $MenuBackground
@onready var settings_background = $SettingsBackground
@onready var menu_group = $MenuGroup
@onready var settings_group = $SettingsGroup
@onready var play_button = $MenuGroup/PlayButton
@onready var settings_button = $MenuGroup/SettingsButton
@onready var back_button = $SettingsGroup/BackButton
@onready var mobile_toggle = $SettingsGroup/MobileToggle
@onready var github_button = $SettingsGroup/GithubButton
@onready var vk_button = $SettingsGroup/VkButton
@onready var stats_button = $SettingsGroup/StatsButton
@onready var load_dialog = $LoadDialog
@onready var yes_button = $LoadDialog/YesButton
@onready var no_button = $LoadDialog/NoButton

const MobileSizer = preload("res://tools/mobile_sizer.gd")

func _ready():
	MobileSizer.enlarge_scene(self)
	load_dialog.visible = false
	_set_state(MenuState.MENU)
	
	play_button.pressed.connect(_on_play_button_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	back_button.pressed.connect(_on_back_pressed)
	mobile_toggle.pressed.connect(_on_mobile_toggle)
	github_button.pressed.connect(_on_github_pressed)
	vk_button.pressed.connect(_on_vk_pressed)
	stats_button.pressed.connect(_on_stats_button_pressed)
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(_on_no_pressed)


func _set_state(state: MenuState):
	current_state = state
	menu_background.visible = (state == MenuState.MENU)
	menu_group.visible = (state == MenuState.MENU)
	settings_background.visible = (state == MenuState.SETTINGS)
	settings_group.visible = (state == MenuState.SETTINGS)


func _on_settings_pressed():
	_set_state(MenuState.SETTINGS)


func _on_back_pressed():
	_set_state(MenuState.MENU)


func _on_github_pressed():
	OS.shell_open("https://github.com/igetpaid/HardReset")


func _on_vk_pressed():
	OS.shell_open("https://vk.com/igor_tengel")


func _on_mobile_toggle():
	MobileSizer.force_enabled = not MobileSizer.force_enabled
	if MobileSizer.force_enabled:
		MobileSizer.enlarge_scene(self)
		mobile_toggle.text = "Mobile Mode: ON"
	else:
		get_tree().reload_current_scene()


func _on_play_button_pressed():
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
