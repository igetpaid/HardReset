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
@onready var load_dialog = $LoadDialog
@onready var yes_button = $LoadDialog/YesButton
@onready var no_button = $LoadDialog/NoButton
@onready var link_dialog = $LinkDialog
@onready var link_label = $LinkDialog/LinkLabel
@onready var open_button = $LinkDialog/OpenButton
@onready var cancel_button = $LinkDialog/CancelButton

const MobileSizer = preload("res://tools/mobile_sizer.gd")

var pending_url: String = ""


func _ready():
	# Исключаем крупные кнопки меню из MobileSizer (они и так большие)
	play_button.set_meta("mobile_exclude", true)
	settings_button.set_meta("mobile_exclude", true)

	MobileSizer.enlarge_scene(self)
	load_dialog.visible = false
	link_dialog.visible = false
	_set_state(MenuState.MENU)
	# Синхронизируем текст тоггла с фактическим состоянием
	mobile_toggle.button_pressed = MobileSizer.force_enabled
	_update_toggle_text()



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
	pending_url = "https://github.com/igetpaid/HardReset"
	link_label.text = "https://github.com/igetpaid/HardReset"
	link_dialog.visible = true


func _on_vk_pressed():
	pending_url = "https://vk.com/igor_tengel"
	link_label.text = "https://vk.com/igor_tengel"
	link_dialog.visible = true


func _on_link_confirmed():
	OS.shell_open(pending_url)
	link_dialog.visible = false


func _on_link_cancelled():
	link_dialog.visible = false


func _update_toggle_text():
	if MobileSizer.force_enabled:
		mobile_toggle.text = "Large Buttons: ON"
	else:
		mobile_toggle.text = "Large Buttons: OFF"

func _on_mobile_toggle():
	MobileSizer.force_enabled = mobile_toggle.button_pressed
	if MobileSizer.force_enabled:
		MobileSizer.enlarge_scene(self)
	else:
		MobileSizer.shrink_scene(self)
	_update_toggle_text()


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
