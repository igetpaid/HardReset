extends Control

@onready var video1 = $Video1
@onready var video2_good = $Video2Good
@onready var video2_bad = $Video2Bad
@onready var video3 = $Video3
@onready var video4_good = $Video4Good
@onready var video4_bad = $Video4Bad
@onready var qte_panel = $QtePanel
@onready var click_catcher = $ClickCatcher

var current_round = 1
var round1_success = false
var video_start_time = 0
var waiting_for_reaction = false

# Максимальное время ожидания реакции (в секундах) — с большим запасом на длинные видео
const REACTION_TIMEOUT := 120.0
var reaction_timer: SceneTreeTimer = null

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	# Скрываем всё лишнее
	qte_panel.visible = false
	click_catcher.visible = false
	
	video2_good.visible = false
	video2_bad.visible = false
	video3.visible = false
	video4_good.visible = false
	video4_bad.visible = false
	
	video2_good.volume_db = -80
	video2_bad.volume_db = -80
	video4_good.volume_db = -80
	video4_bad.volume_db = -80
	
	video1.play()
	print("Видео 1 запущено")
	await video1.finished
	_on_video1_finished()

func _on_video1_finished():
	print("Видео 1 закончилось")
	video1.stop()
	_start_round(1)

func _start_round(round: int):
	current_round = round
	print("_start_round вызван для раунда ", round)
	qte_panel.visible = true
	click_catcher.visible = true
	# Клик в любом месте — подтверждение инструкции
	if click_catcher.gui_input.is_connected(_on_qte_ok_pressed):
		click_catcher.gui_input.disconnect(_on_qte_ok_pressed)
	click_catcher.gui_input.connect(_on_qte_ok_pressed)

func _on_qte_ok_pressed(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("QTE инструкция закрыта — раунд ", current_round)
		if click_catcher.gui_input.is_connected(_on_qte_ok_pressed):
			click_catcher.gui_input.disconnect(_on_qte_ok_pressed)
		qte_panel.visible = false
		click_catcher.visible = false
		
		await get_tree().create_timer(1.0).timeout
		
		if current_round == 1:
			_start_round1_videos()
		elif current_round == 2:
			_start_round2_videos()

func _start_round1_videos():
	# Скрываем видео 1
	video1.visible = false
	
	print("Запуск видео 2 good/bad")
	video2_good.visible = true
	video2_bad.visible = true
	video2_good.play()
	video2_bad.play()
	video2_good.volume_db = 0
	video2_bad.volume_db = -80
	
	_start_waiting_for_reaction()

func _start_round2_videos():
	# Скрываем видео 3
	video3.visible = false
	
	print("Запуск видео 4 good/bad")
	video4_good.visible = true
	video4_bad.visible = true
	video4_good.play()
	video4_bad.play()
	video4_good.volume_db = 0
	video4_bad.volume_db = -80
	
	_start_waiting_for_reaction()

# Выносим общую логику ожидания реакции
func _start_waiting_for_reaction():
	video_start_time = Time.get_ticks_msec()
	waiting_for_reaction = true
	click_catcher.visible = true
	if click_catcher.gui_input.is_connected(_on_reaction_click):
		click_catcher.gui_input.disconnect(_on_reaction_click)
	click_catcher.gui_input.connect(_on_reaction_click)
	
	# Подключаем finished сигналы видео — если игрок не нажмёт, обработаем сами
	if current_round == 1:
		if not video2_good.finished.is_connected(_on_no_click_video_finished):
			video2_good.finished.connect(_on_no_click_video_finished)
		if not video2_bad.finished.is_connected(_on_no_click_video_finished):
			video2_bad.finished.connect(_on_no_click_video_finished)
	elif current_round == 2:
		if not video4_good.finished.is_connected(_on_no_click_video_finished):
			video4_good.finished.connect(_on_no_click_video_finished)
		if not video4_bad.finished.is_connected(_on_no_click_video_finished):
			video4_bad.finished.connect(_on_no_click_video_finished)
	
	# Таймер безопасности: если реакции нет REACTION_TIMEOUT секунд — принудительный выход
	reaction_timer = get_tree().create_timer(REACTION_TIMEOUT)
	await reaction_timer.timeout
	
	if waiting_for_reaction:
		print("Таймаут реакции! Принудительный выход")
		_handle_reaction_timeout()

func _on_no_click_video_finished():
	# Игрок не нажал кнопку ни разу — одно из видео закончилось
	if not waiting_for_reaction:
		return
	print("Видео закончилось, игрок не нажал — проигрыш")
	waiting_for_reaction = false
	if click_catcher.gui_input.is_connected(_on_reaction_click):
		click_catcher.gui_input.disconnect(_on_reaction_click)
	click_catcher.visible = false
	# Отключаем finished, чтобы второй экземпляр не вызвал повторный переход
	_disconnect_no_click_signals()
	_go_to_lose()

func _disconnect_no_click_signals():
	if current_round == 1:
		if video2_good.finished.is_connected(_on_no_click_video_finished):
			video2_good.finished.disconnect(_on_no_click_video_finished)
		if video2_bad.finished.is_connected(_on_no_click_video_finished):
			video2_bad.finished.disconnect(_on_no_click_video_finished)
	elif current_round == 2:
		if video4_good.finished.is_connected(_on_no_click_video_finished):
			video4_good.finished.disconnect(_on_no_click_video_finished)
		if video4_bad.finished.is_connected(_on_no_click_video_finished):
			video4_bad.finished.disconnect(_on_no_click_video_finished)

func _handle_reaction_timeout():
	waiting_for_reaction = false
	if click_catcher.gui_input.is_connected(_on_reaction_click):
		click_catcher.gui_input.disconnect(_on_reaction_click)
	click_catcher.visible = false
	_disconnect_no_click_signals()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Таймаут = проигрыш (а не возврат в меню)
	_go_to_lose()

func _on_reaction_click(event):
	if not waiting_for_reaction:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var reaction_time = Time.get_ticks_msec() - video_start_time
		print("Реакция через ", reaction_time, " мс")
		waiting_for_reaction = false
		if click_catcher.gui_input.is_connected(_on_reaction_click):
			click_catcher.gui_input.disconnect(_on_reaction_click)
		click_catcher.visible = false
		# Если игрок нажал — отключаем finished-обработчики для no-click
		_disconnect_no_click_signals()
		
		var success = (reaction_time >= 100 and reaction_time <= 400)
		
		if current_round == 1:
			round1_success = success
			if success:
				print("✅ Раунд 1 пройден! Ждём окончания видео 2 good")
				video2_bad.stop()
				video2_bad.visible = false
				await _await_video_safe(video2_good)
				_play_video3()
			else:
				print("❌ Раунд 1 провален. Ждём окончания видео 2 bad")
				video2_good.stop()
				video2_good.visible = false
				video2_bad.volume_db = 0
				await _await_video_safe(video2_bad)
				_go_to_lose()
		elif current_round == 2:
			if success and round1_success:
				print("✅✅ Оба раунда пройдены! Хорошая концовка")
				video4_bad.stop()
				video4_bad.visible = false
				await _await_video_safe(video4_good)
				_go_to_win()
			else:
				print("❌ Раунд 2 провален. Ждём окончания видео 4 bad")
				video4_good.stop()
				video4_good.visible = false
				video4_bad.volume_db = 0
				await _await_video_safe(video4_bad)
				_go_to_lose()

# Безопасное ожидание окончания видео: если уже не играет — не ждём сигнал
func _await_video_safe(video: VideoStreamPlayer):
	if video.is_playing():
		await video.finished

func _play_video3():
	print("Запуск видео 3")
	video3.visible = true
	video3.play()
	await video3.finished
	print("Видео 3 закончилось")
	video3.stop()
	_start_round(2)

func _go_to_lose():
	print("Переход на сцену проигрыша")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/lose.tscn")

func _go_to_win():
	print("Переход на сцену победы")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/win.tscn")

func _input(event):
	if qte_panel.visible and event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			accept_event()
