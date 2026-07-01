extends Control

@onready var background = $Background
@onready var broken_fan = $BrokenFan
@onready var fixed_fan = $AbsoluteSpace/FixedFan
@onready var trash_bin = $AbsoluteSpace/TrashBin
@onready var timer = $Timer
@onready var bolts_container = $AbsoluteSpace/Bolts
@onready var glow_rings_container = $AbsoluteSpace/GlowRings
@onready var screwdriver_sound = $ScrewdriverSound
@onready var bolt_animators = [$BoltAnimator0, $BoltAnimator1, $BoltAnimator2, $BoltAnimator3]
@onready var trash_animator = $TrashAnimator
@onready var screwdriver_button = $AbsoluteSpace/ScrewdriverButton
@onready var electric_screwdriver_button = $AbsoluteSpace/ElectricScrewdriverButton

var bolts = []
var glow_rings = []
var bolts_unscrewed = 0
var old_fan_removed = false
var new_fan_placed = false
var bolts_screwed = 0

var dragging_object = null
var original_position = Vector2()

var tool_selected = false
var electric_mode = false

# Прогресс удержания болта
var current_bolt = null
var is_holding = false
var hold_timer = 0.0

var time_to_unscrew = 1.0

# Прогресс мини-игры
var is_fan_fixed = false
var start_time: float = 0.0
var completion_time: float = 0.0

const MobileSizer = preload("res://tools/mobile_sizer.gd")

func _ready():
	# 1. ЗАГРУЗКА ТЕКСТУР
	trash_bin.texture = load("res://resources/minigames/trash_bin.png")
	
	# 2. СБОР И НАСТРОЙКА БОЛТОВ
	for child in bolts_container.get_children():
		if child is TextureButton:
			bolts.append(child)
			child.texture_normal = load("res://resources/minigames/bolt.png")
			child.button_down.connect(_on_bolt_button_down.bind(child))
			child.button_up.connect(_on_bolt_button_up.bind(child))
	
	# 3. СБОР И НАСТРОЙКА ОБВОДОК (текстура должна быть до MobileSizer)
	for child in glow_rings_container.get_children():
		if child is TextureRect:
			glow_rings.append(child)
			child.texture = load("res://resources/minigames/glow_ring.png")
			# Linear-фильтр + pivot в центр — для плавного scale
			child.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			child.pivot_offset = child.size / 2.0
	
	# 4. MobileSizer — адаптация под мобильные устройства (увеличивает мелкие BaseButton)
	MobileSizer.enlarge_scene(self)
	
	# 5. Явное увеличение GlowRing'ов на мобильных (TextureRect — MobileSizer их не трогает)
	if OS.get_name() == "Android" or MobileSizer.force_enabled:
		var glow_factor := 1.5
		for ring in glow_rings:
			ring.scale *= glow_factor
	
	# 6. Сброс анимации, размера и масштаба
	# НЕ используем seek(0, true) — он может вызвать RESET-анимацию, сбрасывающую scale
	$MinigameClose.stop()
	size = Vector2(1210, 810)
	scale = Vector2(1, 1)
	
	screwdriver_button.pressed.connect(_on_screwdriver_selected)
	electric_screwdriver_button.pressed.connect(_on_electric_screwdriver_selected)
	
	# Звук при нажатии на кнопки выбора инструмента
	screwdriver_button.pressed.connect(_play_button_sound)
	electric_screwdriver_button.pressed.connect(_play_button_sound)
			
	# 4. НАЧАЛЬНЫЕ НАСТРОЙКИ
	start_time = Time.get_ticks_msec() / 1000.0
	fixed_fan.position = Vector2(1925, 350)
	fixed_fan.scale = Vector2(0.5, 0.5)
	fixed_fan.visible = false  # пока не появится
	
	trash_bin.position = Vector2(191, 1085)
	
	timer.wait_time = 30.0
	timer.start()
	
	# 5. Подключаем сигнал для зацикливания звука один раз
	screwdriver_sound.finished.connect(_on_screwdriver_finished)
	
	# 6. Перетаскивание
	broken_fan.gui_input.connect(_on_broken_fan_input)
	fixed_fan.gui_input.connect(_on_fixed_fan_input)

# Функции выбора инструмента (в конец скрипта)
func _on_screwdriver_selected():
	tool_selected = true
	electric_mode = false
	time_to_unscrew = 1.0
	animate_button_out(screwdriver_button)
	animate_button_out(electric_screwdriver_button)
	print("Выбрана обычная отвёртка")

func _on_electric_screwdriver_selected():
	if MinigameManager.subtract_money(10):
		tool_selected = true
		electric_mode = true
		time_to_unscrew = 0.3
		animate_button_out(screwdriver_button)
		animate_button_out(electric_screwdriver_button)
		print("Выбрана электроотвёртка, осталось денег: ", MinigameManager.player_money)
	else:
		print("Не хватает денег для электроотвёртки!")
		_flash_button_red(electric_screwdriver_button)
	
func _process(delta):
	if is_holding and current_bolt and tool_selected:
		hold_timer += delta
		if hold_timer >= time_to_unscrew:
			_on_bolt_held(current_bolt)

# НАЖАТИЕ БОЛТОВ
func _on_bolt_button_down(bolt: TextureButton):
	if not bolt.visible:
		return
		
	if not tool_selected:
		print("Сначала выберите инструмент!")
		return
		
	current_bolt = bolt
	is_holding = true
	hold_timer = 0.0
		
	var index = bolts.find(bolt)
	if index == -1:
		return
				
	if not new_fan_placed: # Если ОТКРУЧИВАЕМ broken_fan
		bolt_animators[index].play("bolt_turn")
	else:	# Если ЗАКРУЧИВАЕМ fixed_fan
		bolt.modulate = Color(1, 1, 1, 1) # 100% Непрозрачности
		bolt_animators[index].play("bolt_reverse_turn")
		
	screwdriver_sound.play()

func _on_bolt_button_up(bolt: TextureButton):
	is_holding = false
	current_bolt = null
	
	var index = bolts.find(bolt)
	if index != -1:
		bolt_animators[index].stop()
	
	screwdriver_sound.stop()

func _on_screwdriver_finished():
	if is_holding and current_bolt:
		screwdriver_sound.play()  # перезапускаем, пока удерживают

func _on_bolt_held(bolt: TextureButton):
	is_holding = false
	current_bolt = null
	
	var index = bolts.find(bolt)
	if index != -1:
		bolt_animators[index].stop()
	screwdriver_sound.stop()
	
	if not bolt.visible:
		return
	
	if not old_fan_removed: # Если ОТКРУЧИВАЕМ broken_fan
		bolt.visible = false
		if index != -1 and index < glow_rings.size(): # Скрываем соответствующую обводку
			glow_rings[index].visible = false
		bolts_unscrewed += 1
		if bolts_unscrewed >= bolts.size():
			trash_animator.play("trash_appear")
	
	else: # Если ЗАКРУЧИВАЕМ fixed_fan
		if index != -1 and index < glow_rings.size():
			glow_rings[index].visible = false
		bolts_screwed += 1
		if bolts_screwed >= bolts.size():
			_complete(true)

func _on_broken_fan_input(event: InputEvent):
	if bolts_unscrewed < bolts.size():
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging_object = broken_fan
			original_position = broken_fan.position
			broken_fan.scale = Vector2(0.5, 0.5)
			
			# Сразу прикрепляем к курсору
			var half_size = broken_fan.size * broken_fan.scale / 2
			broken_fan.global_position = get_global_mouse_position() - half_size
		else:
			dragging_object = null
			
			var fan_rect = Rect2(broken_fan.global_position, broken_fan.size * broken_fan.scale)
			var trash_rect = Rect2(trash_bin.global_position, trash_bin.size)
			
			if fan_rect.intersects(trash_rect):
				_remove_old_fan()
			else:
				broken_fan.position = original_position
				broken_fan.scale = Vector2(1, 1)
	
	elif event is InputEventMouseMotion and dragging_object == broken_fan:
		var half_size = broken_fan.size * broken_fan.scale / 2
		broken_fan.global_position = get_global_mouse_position() - half_size
 # Проверка наведения на урну
		var fan_rect = Rect2(broken_fan.global_position, broken_fan.size * broken_fan.scale)
		var trash_rect = Rect2(trash_bin.global_position, trash_bin.size)
	
		if fan_rect.intersects(trash_rect):
			trash_bin.scale = Vector2(1.2, 1.2)
		else:
			trash_bin.scale = Vector2(1, 1)

func _remove_old_fan():
	$TrashSound.play()
	broken_fan.visible = false
	trash_bin.scale = Vector2(1, 1)
	
	trash_animator.play("trash_disappear")
	await trash_animator.animation_finished
	
	old_fan_removed = true
	fixed_fan.visible = true
	fixed_fan.position = Vector2(1925, 350)
	fixed_fan.scale = Vector2(0.5, 0.5)

	# Анимация выезда
	var tween = create_tween()
	tween.tween_property(fixed_fan, "position", Vector2(1495, 350), 0.3)
	$ConveyorSound.play()
	
	is_fan_fixed = false
	
func _on_fixed_fan_input(event: InputEvent):
	if not old_fan_removed:
		return
		
	if is_fan_fixed:
		return  # игрок больше не может двигать вентилятор
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging_object = fixed_fan
			original_position = fixed_fan.position
			
			# Увеличиваем до полного размера
			fixed_fan.scale = Vector2(1, 1)
			
			# Сразу центрируем под курсор
			var half_size = fixed_fan.size / 2
			fixed_fan.global_position = get_global_mouse_position() - half_size
			
			# Показываем обводки (подсказки, куда ставить)
			for ring in glow_rings:
				ring.visible = true
			
		else:
			dragging_object = null

			# Локальная позиция вентилятора (внутри AbsoluteSpace)
			var fan_local_pos = fixed_fan.position
			var target_local_pos = Vector2(609, 189)
	
			if fan_local_pos.distance_to(target_local_pos) < 50:
				# Успешная установка
				_place_new_fan()
			else:
				# Возврат в исходное состояние
				fixed_fan.position = Vector2(1495, 350)
				fixed_fan.scale = Vector2(0.5, 0.5)

				for ring in glow_rings:
					ring.visible = false
	
	elif event is InputEventMouseMotion and dragging_object == fixed_fan:
		var half_size = fixed_fan.size / 2
		fixed_fan.global_position = get_global_mouse_position() - half_size

func _place_new_fan():
	var target_center = Vector2(609, 189)
	#var fan_size = fixed_fan.size * fixed_fan.scale
	fixed_fan.position = target_center
	fixed_fan.scale = Vector2(1, 1)
	new_fan_placed = true
	is_fan_fixed = true  # блокируем дальнейшие перемещения
	
	# Отключаем обработку ввода для fixed_fan
	fixed_fan.gui_input.disconnect(_on_fixed_fan_input)
	for bolt in bolts:
		bolt.visible = true
		bolt.modulate = Color(1.0, 1.0, 1.0, 0.65)  # 65% прозрачности
		bolt.rotation_degrees = 0

func _complete(success: bool):
	timer.stop()
	print("_complete вызван, success: ", success)
		
	if success:
		completion_time = (Time.get_ticks_msec() / 1000.0) - start_time
		
		# Рассчитываем опыт в зависимости от времени
		var multiplier = 1.0
		var exp_gained = 0
		if completion_time <= 10.0:
			exp_gained = 70
			multiplier = 2.0
		elif completion_time <= 19.0:
			exp_gained = 50
			multiplier = 1.5
		else:
			exp_gained = 30
			multiplier = 1.0
			
		print("Время: ", completion_time, " сек. Опыт: ", exp_gained)
		
		 # Начисляем деньги и опыт через MinigameManager
		var reward = _calculate_money_reward(completion_time)
		MinigameManager.add_money(reward)
		MinigameManager.add_exp(exp_gained)
		MinigameManager.xp_gained_with_multiplier.emit(exp_gained, multiplier)
		MinigameManager.complete_minigame("broken_fan", success, completion_time)
		
		trash_bin.hide() # убираем trash_bin из анимации закрытия
		$MinigameClose.play("minigame_close") # анимация закрытия мини-игры
		await $MinigameClose.animation_finished
		# Сброс scale (анимация могла его изменить)
		scale = Vector2(1, 1)
		queue_free()
	else:
		print("не complete :(")
		MinigameManager.complete_minigame("broken_fan", false, completion_time)
		queue_free()

func _calculate_money_reward(completion_time: float) -> int:
	if completion_time <= 10.0:
		return 20
	elif completion_time <= 19.0:
		return 15
	else:
		return 10
		
func _play_button_sound():
	$ButtonClickSound.play()

func _flash_button_red(button: TextureButton):
	# Красная вспышка — не хватает денег
	var tween = create_tween()
	tween.tween_property(button, "modulate", Color(1, 0.3, 0.3), 0.1)
	tween.tween_property(button, "modulate", Color(1, 1, 1, 1), 0.4)

func animate_button_out(button: TextureButton):
	var tween = create_tween()
	tween.tween_property(button, "position:x", button.position.x + 500, 0.5)
	tween.parallel().tween_property(button, "modulate:a", 0.0, 0.75)
	tween.tween_callback(button.queue_free)
