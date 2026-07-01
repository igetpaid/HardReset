extends Control

@onready var level3_panel = $Level3Panel
@onready var level3_button = $Level3Panel/Level3Button
@onready var money_label = $MoneyLabel
@onready var broken_fan_buttons = [$ComputerView/FrontView/GamingBrokenFan1, $ComputerView/FrontView/GamingBrokenFan2,
$ComputerView/FrontView/GamingBrokenFan3]
@onready var front_view = $ComputerView/FrontView
@onready var side_view = $ComputerView/SideView
@onready var rotate_button = $RotateButton
@onready var front_panel = $ComputerView/FrontView/GamingFrontPanel
@onready var front_panel_button = $ComputerView/FrontView/GamingFrontPanelButton
@onready var dusty_button = $ComputerView/SideView/GamingDustButton
@onready var dusty_look = $ComputerView/SideView/GamingDustyLook
@onready var dusty_minigame = $MinigameDustyPC
@onready var customers = [$Customer1, $Customer2, $Customer3, $Customer4, $Customer5]
@onready var next_button = $NextButton
@onready var task_box = $Box 
@onready var task_text = $Box/BoxText 
@onready var thumb_bolts = [
	$ComputerView/SideView/ThumbBolts/ThumbBolt1,
	$ComputerView/SideView/ThumbBolts/ThumbBolt2,
	$ComputerView/SideView/ThumbBolts/ThumbBolt3,
	$ComputerView/SideView/ThumbBolts/ThumbBolt4,
]
@onready var side_panel = $ComputerView/SideView/GamingSidePanel
@onready var thumb_bolt_sound = $ThumbBoltSound

# Glow-обводка для GamingFrontPanelButton (постоянно, исчезает при нажатии)
var front_panel_glow: Panel = null
var _front_panel_glow_tween: Tween = null

var side_panel_textures = {
	"Customer1": preload("res://resources/cover_babushka.png"),
	"Customer2": preload("res://resources/cover_lazarev.png"),
	"Customer3": preload("res://resources/cover_milfa.png"),
	"Customer4": preload("res://resources/cover_tanki.png"),
	"Customer5": preload("res://resources/cover_anime.png"),
}

var side_panel_active = false

var recent_customers = []  # список последних появившихся клиентов
const RECENT_LIMIT = 2     # сколько последних клиентов не повторять

var bolts_unscrewed = 0

const CUSTOMER_MOVE_DURATION = 0.4
const CUSTOMER_START_X = -150   # начальная позиция за левым краем
#const CUSTOMER_END_X = 200      # конечная позиция перед компьютером

var customer_original_positions = {}
var customer_active = false  # есть ли активный клиент
var current_customer: TextureButton = null
var active_problems = []
var all_problems = []
var order_completed = true
var customer_animating = false

var is_panel_open = false
const XP_POPUP_DURATION := 2.5
const XP_POPUP_FADE_DURATION := 0.5
const XP_POPUP_RISE_DISTANCE := 50.0
var xp_popup_container: CanvasLayer

var last_money_amount: int = 0

const MobileSizer = preload("res://tools/mobile_sizer.gd")

var is_front_view = true

var next_button_blinking = false

var customer_phrases = {
	"Customer1": [
		"Я на Одноклассниках уже три дня синий экран ловлю.",
		"Сделай потише, а то вентилятор как трактор — соседи стучат."
	],
	"Customer2": [
		"Срочно! У меня фпс просел в Симсе до 20. Мои люди страдают!",
		"Рендер видео уже 5 часов висит. Преподаватель убьёт, если не сдам.",
		"Хочу начать стримить, но комп выключается, когда я открываю ОБС."
	],
	"Customer3": [
		"Не знаю, что с ним. Сделай чтобы работал",
		"Сделай потише, а то вентилятор как трактор — соседи стучат."
	],
	"Customer4": [
		"Хочу как у внука: чтобы вентиляторы крутились и светились.",
		"Я в компьютерах не бум-бум, сделай так чтобы он снова работал"
	],
	"Customer5": [
		"Компьютер пищит и не включается. Это серьезно?",
		"Говорят, у вас можно быстро починить. Правда?"
	]
}

var completion_phrases = [
	"Спасибо, теперь всё работает как новое!",
	"Ого, так быстро! Держи оплату.",
	"Слава Богу, а то я уже думал(а) покупать новый.",
	"Ты просто волшебник! Обязательно приду ещё.",
	"Отличная работа! Деньги твои.",
	"Наконец-то компьютер перестал шуметь как реактивный двигатель."
]

var current_bolt: TextureButton = null
var is_holding_bolt = false
var bolt_hold_timer = 0.0
const BOLT_HOLD_TIME = 0.4

func _on_return_button_pressed() -> void:
	get_tree().quit()

func _ready():
	# GamingFrontPanelButton: НЕ увеличивать (вместо этого — обводка)
	front_panel_button.set_meta("mobile_exclude", true)
	# GlowHighlight Panel — прямоугольная обводка через StyleBoxFlat
	front_panel_glow = front_panel_button.get_node_or_null("GlowHighlight") as Panel
	if front_panel_glow:
		var style := StyleBoxFlat.new()
		style.draw_center = false
		style.border_color = Color(1, 0.65, 0.1)
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		front_panel_glow.add_theme_stylebox_override("panel", style)
	
	MobileSizer.enlarge_scene(self)
	MinigameManager.load_progress()
	last_money_amount = MinigameManager.player_money
	
	for bolt in thumb_bolts:
		bolt.button_down.connect(_on_bolt_button_down.bind(bolt))
		bolt.button_up.connect(_on_bolt_button_up.bind(bolt))

	if MinigameManager.current_level >= 3:
		_show_level3_panel()

	side_panel.pressed.connect(_on_side_panel_pressed)
	side_panel.visible = false  # сначала скрыта, пока болты не откручены
	
	# Подключаем все три кнопки вентиляторов
	for button in broken_fan_buttons:
		button.pressed.connect(_on_broken_fan_pressed.bind(button))
		
	dusty_button.pressed.connect(_on_dusty_pressed)
	rotate_button.pressed.connect(_on_rotate_pressed)
	front_panel_button.pressed.connect(_on_front_panel_button_pressed)
	front_panel.pressed.connect(_on_front_panel_pressed)
	MinigameManager.minigame_completed.connect(_on_minigame_completed)
	MinigameManager.money_changed.connect(_on_money_changed)
	MinigameManager.exp_changed.connect(_on_exp_changed)
	MinigameManager.level_up.connect(_on_level_up)
	MinigameManager.xp_gained_with_multiplier.connect(_on_xp_gained)
	
	# Подключаем сигналы мини-игр
	dusty_minigame.play_click_sound.connect(_play_dusty_click_sound)
	dusty_minigame.toggle_case_visibility.connect(_on_dusty_case_visibility)
	
	_on_exp_changed(MinigameManager.current_exp, MinigameManager.current_level, MinigameManager.exp_to_next_level)
	update_money_display()
	show_front_view()
	
	# Собираем все кликабельные кнопки проблем
	all_problems = [
		$ComputerView/FrontView/GamingBrokenFan1,
		$ComputerView/FrontView/GamingBrokenFan2,
		$ComputerView/FrontView/GamingBrokenFan3,
		$ComputerView/SideView/GamingDustButton,
	]
	next_button.pressed.connect(_on_next_button_pressed)
	
	# Скрываем всех клиентов
	for customer in customers:
		customer.visible = false
	
	# Начальное состояние: заказа нет, можно нажать "Следующий"
	order_completed = true
	next_button.disabled = false
	
	# Начальная видимость
	$ComputerView.visible = false  # компьютер скрыт до первого клиента
	$RotateButton.visible = false   # кнопка поворота скрыта
	next_button.visible = false       # кнопка "Следующий" видна
	
	customer_active = false
	task_box.visible = false
	
	# Сохраняем оригинальные позиции для сброса
	for customer in customers:
		customer_original_positions[customer] = customer.position
	if front_panel:
		front_panel.set_meta("original_position", front_panel.position)
	if front_panel_button:
		front_panel_button.set_meta("original_position", front_panel_button.position)
	if side_panel:
		side_panel.set_meta("original_position", side_panel.position)
	
	recent_customers = []
	
	await get_tree().create_timer(1).timeout
	_spawn_next_customer()
	
func get_random_customer_excluding_recent() -> TextureButton:
	var available_customers = []
	
	# Собираем клиентов, которых не было в recent_customers
	for customer in customers:
		if not customer in recent_customers:
			available_customers.append(customer)
	
	# Если все клиенты были недавно (например, их мало) — разрешаем повторы
	if available_customers.size() == 0:
		available_customers = customers.duplicate()
	
	# Выбираем случайного из доступных
	var chosen = available_customers[randi() % available_customers.size()]
	
	# Обновляем список последних клиентов
	recent_customers.append(chosen)
	if recent_customers.size() > RECENT_LIMIT:
		recent_customers.pop_front()
	
	return chosen
	
func _spawn_next_customer():
	if customer_animating or customer_active:
		return
		
	next_button.visible = false
	$NewCustomerSound.play()
	
	# Сброс состояния компьютера при каждом новом клиенте
	reset_computer_state()
	
	if current_customer:
		current_customer.visible = false
	
	next_button.visible = false
	
	# Выбираем случайного клиента
	current_customer = get_random_customer_excluding_recent()
	var target_position = customer_original_positions[current_customer]
	
	# Меняем текстуру боковой панели в зависимости от клиента
	if side_panel and side_panel_textures.has(current_customer.name):
		side_panel.texture_normal = side_panel_textures[current_customer.name]
	
	current_customer.position = Vector2(CUSTOMER_START_X, target_position.y)
	current_customer.modulate.a = 0.0
	current_customer.visible = true
	
	customer_animating = true
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(current_customer, "position:x", target_position.x, CUSTOMER_MOVE_DURATION).set_ease(Tween.EASE_OUT)
	tween.tween_property(current_customer, "modulate:a", 1.0, CUSTOMER_MOVE_DURATION).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_on_customer_arrived)
	
	customer_active = true
	order_completed = false
	
func _after_customer_leave():
	await get_tree().create_timer(1.0).timeout
	_spawn_next_customer()
	
func generate_problems():
	# Сброс всех проблем
	for problem in all_problems:
		problem.visible = false
	active_problems.clear()
	
	$ComputerView/SideView/GamingDustyLook.visible = false
	
	# Случайный выбор активных проблем (1-3)
	#var problem_count = randi() % 3 + 1
	var problem_count = randi() % 2 + 1
	var shuffled = all_problems.duplicate()
	shuffled.shuffle()
	
	for i in range(problem_count):
		var problem = shuffled[i]
		problem.visible = true
		active_problems.append(problem)
		print("Активирована проблема: ", problem.name)
		
		if problem == $ComputerView/SideView/GamingDustButton:
			$ComputerView/SideView/GamingDustyLook.visible = true
	
func _on_task_box_pressed():
	$ButtonClickSound.play()
	next_button.visible = false
	
	# Закрываем диалог
	$Dialog.visible = false
	$DialogText.visible = false
	
	task_box.pressed.disconnect(_on_task_box_pressed)
	task_box.visible = false
	
	# Показываем компьютер
	$ComputerView.visible = true
	_show_front_panel_glow()  # первый реальный показ обводки
	$RotateButton.visible = true
		
func _on_task_box_completed():
	if not order_completed:
		return
	
	task_box.pressed.disconnect(_on_task_box_completed)
	task_box.visible = false
	$Dialog.visible = false
	$DialogText.visible = false
	
	_animate_customer_leave(_after_customer_leave)
		
func _update_task_box():
	var text = ""
	for problem in active_problems:
		var problem_name = ""
		match problem.name:
			"GamingBrokenFan1", "GamingBrokenFan2", "GamingBrokenFan3":
				problem_name = "broken_fan"
			"GamingDustButton":
				problem_name = "dusty_pc"
		text += "- " + problem_name + "\n"
	task_text.text = text

func _update_task_box_strikethrough():
	var text = ""
	for problem in active_problems:
		var problem_name = ""
		match problem.name:
			"GamingBrokenFan1", "GamingBrokenFan2", "GamingBrokenFan3":
				problem_name = "broken_fan"
			"GamingDustButton":
				problem_name = "dusty_pc"
		text += "- [s]" + problem_name + "[/s]\n"
	task_text.text = text
	
func _on_next_button_pressed():
		# Если активен клиент и заказ не выполнен — пропускаем со штрафом
	if customer_active and not order_completed:
		if MinigameManager.current_exp >= 10:
			_skip_current_customer()
		else:
			print("Не хватает опыта для пропуска! Нужно 10 XP.")
			_blink_next_button()
		return
		
func _blink_next_button():
	if next_button_blinking:
		return
	
	next_button_blinking = true
	var original_color = next_button.modulate
	var blink_color = Color(1, 0.3, 0.3, 1)
	
	var tween = create_tween()
	tween.set_loops(4)
	tween.tween_property(next_button, "modulate", blink_color, 0.15)
	tween.tween_property(next_button, "modulate", original_color, 0.15)
	tween.tween_callback(func(): next_button_blinking = false)
		
func _skip_current_customer():
	if not current_customer:
		return
	
	# Штраф: -10 опыта
	MinigameManager.add_exp(-10)
	print("Клиент ушёл! Штраф: -10 опыта")
		
	# Скрываем всё
	$Dialog.visible = false
	$DialogText.visible = false
	task_box.visible = false
	$ComputerView.visible = false
	$RotateButton.visible = false
	next_button.visible = false
	
	_animate_customer_leave(_after_customer_leave)

func show_next_button_smooth():
	next_button.visible = true
	next_button.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(next_button, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)

func _show_dialog_for_customer(customer_name: String):
	if not customer_phrases.has(customer_name):
		return
	
	var phrases = customer_phrases[customer_name]
	var random_phrase = phrases[randi() % phrases.size()]
	
	$DialogText.text = random_phrase
	$Dialog.visible = true
	$DialogText.visible = true
	
func _on_customer_arrived():
	customer_animating = false
	print("Клиент пришёл: ", current_customer.name)
	
	generate_problems()
	_update_task_box()
	
	await get_tree().create_timer(0.4).timeout
	task_box.visible = true
	
	if not task_box.pressed.is_connected(_on_task_box_pressed):
		task_box.pressed.connect(_on_task_box_pressed)
	
	# Показываем диалог с фразой клиента
	_show_dialog_for_customer(current_customer.name)
	
	next_button.visible = true
	next_button.modulate.a = 1.0
	
func complete_order():
	if active_problems.size() > 0:
		print("Ещё не все проблемы решены: ", active_problems.size())
		return
	if not customer_active:
		return
	
	order_completed = true
	print("Заказ выполнен! Нажми на Box, чтобы завершить")
	
	# Скрываем компьютер и кнопку поворота
	$ComputerView.visible = false
	$RotateButton.visible = false
		
	# Показываем финальный диалог
	_show_completion_dialog()
	
	# Показываем Box с финальным сообщением
	task_box.visible = true
	task_text.text = "   ✅ Все проблемы решены!\n    Нажми, чтобы завершить"
	
	if not task_box.pressed.is_connected(_on_task_box_completed):
		task_box.pressed.connect(_on_task_box_completed)
		
func _show_completion_dialog():
	var random_phrase = completion_phrases[randi() % completion_phrases.size()]
	
	$DialogText.text = random_phrase
	$Dialog.visible = true
	$DialogText.visible = true
		
func _on_exp_changed(new_exp: int, new_level: int, exp_needed: int):
	$ExpPanel/LevelLabel.text = str(new_level)
	$ExpPanel/ExpLabel.text = str(new_exp) + " / " + str(exp_needed)
	$ExpPanel/ExpProgressBar.value = new_exp
	$ExpPanel/ExpProgressBar.max_value = exp_needed

func _on_level_up(new_level: int):
	print("Ding! Уровень ", new_level, " достигнут!")
	# Можно добавить звук повышения уровня
	if new_level == 3:
		_show_level3_panel()
		
func _on_money_changed(new_amount: int):
	var delta = new_amount - last_money_amount
	last_money_amount = new_amount
	money_label.text = str(new_amount)
	
	if delta > 0:
		show_money_popup(delta)
	elif delta < 0:
		show_money_popup(abs(delta), false)  # списание
		
func update_money_display():
	money_label.text = str(MinigameManager.player_money)
		
func _on_rotate_pressed():
	is_front_view = !is_front_view
	$ButtonClickSound.play()

	if is_front_view:
		show_front_view()
	else:
		show_side_view()

func show_front_view():
	front_view.visible = true
	side_view.visible = false
	_show_front_panel_glow()

func show_side_view():
	front_view.visible = false
	side_view.visible = true
	# Скрываем обводку при переключении на боковой вид
	if front_panel_glow and front_panel_glow.visible:
		_hide_front_panel_glow()

func _show_front_panel_glow():
	if not front_panel_glow:
		return
	if is_panel_open:
		return
	if not front_panel_button.is_visible_in_tree():
		return
	
	front_panel_glow.visible = true
	# Явно устанавливаем modulate (GDScript не поддерживает chained property set)
	var glow_color := front_panel_glow.modulate
	glow_color.a = 0.7
	front_panel_glow.modulate = glow_color
	
	# Пульсирующая анимация (сбрасываем старый твин)
	if _front_panel_glow_tween:
		_front_panel_glow_tween.kill()
	_front_panel_glow_tween = create_tween().set_loops()
	_front_panel_glow_tween.tween_property(front_panel_glow, "modulate:a", 0.3, 0.6)
	_front_panel_glow_tween.tween_property(front_panel_glow, "modulate:a", 0.8, 0.6)

func _hide_front_panel_glow():
	if not front_panel_glow:
		return
	front_panel_glow.visible = false
	var glow_color := front_panel_glow.modulate
	glow_color.a = 0.7
	front_panel_glow.modulate = glow_color
	if _front_panel_glow_tween:
		_front_panel_glow_tween.kill()
		_front_panel_glow_tween = null

func _on_broken_fan_pressed(button: TextureButton):
	print("Запуск мини-игры для сломанного кулера")
	MinigameManager.current_fan_button = button
	MinigameManager.start_minigame("broken_fan")

func _on_minigame_completed(minigame_id: String, success: bool, completion_time: float):
	print("_on_minigame_completed: ", minigame_id, " success: ", success)
	print("active_problems до обработки: ", active_problems)
	
	update_money_display()
	print("Мини-игра завершена: ", minigame_id, " успех: ", success, " время: ", completion_time)
	
	if success:
		match minigame_id:
			"broken_fan":
				if MinigameManager.current_fan_button:
					MinigameManager.current_fan_button.visible = false
					if MinigameManager.current_fan_button in active_problems:
						active_problems.erase(MinigameManager.current_fan_button)
					MinigameManager.current_fan_button = null
			
			"dusty_pc":
				dusty_button.visible = false
				dusty_look.visible = false
				if dusty_button in active_problems:
					active_problems.erase(dusty_button)
		
		# Обновляем список задач с зачёркиванием
		_update_task_box_strikethrough()
		
		if active_problems.size() == 0 and not order_completed:
			complete_order()
						
	print("active_problems после обработки: ", active_problems)
		
func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		print("game.gd удаляется!")
		
func _on_xp_gained(amount: int, multiplier: float):
	$ExpGainSound.play()
	show_xp_popup(amount, multiplier)
	
func show_xp_popup(amount: int, multiplier: float = 1.0):
	var label = Label.new()
	
	var text = "XP +" + str(amount)
	if multiplier > 1.0:
		text += " (бонус за скорость x" + str(multiplier).trim_suffix(".0") + ")"
	label.text = text
	
	label.add_theme_font_override("font", money_label.get_theme_font("font"))
	label.add_theme_font_size_override("font_size", 26)
	
	# Тень: толщина 4, смещение 2
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 4)
	
	var color = Color.WHITE
	if multiplier >= 2.0:
		color = Color(1, 0.8, 0)
	elif multiplier >= 1.5:
		color = Color(0.7, 0.9, 1.0)
	label.add_theme_color_override("font_color", color)
	
	var progress_bar = $ExpPanel/ExpProgressBar
	label.position = progress_bar.global_position + Vector2(-80, -28)
	label.size = Vector2(progress_bar.size.x + 160, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(1.5)
	tween.tween_callback(label.queue_free)
	
func _on_front_panel_button_pressed():
	$ButtonClickSound.play()
	if is_panel_open:
		return  # уже нажали, ничего не делаем
	
	var tween = create_tween()
	# Смещаем кнопку вниз на 6 пикселей
	tween.tween_property(front_panel_button, "position:y", front_panel_button.position.y + 6, 0.1)
	
	is_panel_open = true
	# Скрываем обводку — туториал пройден
	_hide_front_panel_glow()
	print("Передняя панель разблокирована")

func _on_front_panel_pressed():
	if not is_panel_open:
		print("Сначала нажми на маленькую кнопку!")
		return
	
	$FallingItem.play()
	
	var tween = create_tween()
	
	# Падение с вращением (без изменения прозрачности)
	tween.set_parallel(true)
	tween.tween_property(front_panel, "position:y", get_viewport().size.y + 550, 1.0).set_ease(Tween.EASE_IN)
	tween.tween_property(front_panel, "rotation", PI * 0.75, 1.4)
	
	# Кнопка тоже падает
	tween.tween_property(front_panel_button, "position:y", get_viewport().size.y + 550, 1.0).set_ease(Tween.EASE_IN)
	tween.tween_property(front_panel_button, "rotation", PI * 0.75, 1.4)
	
	await tween.finished
	# Просто скрываем, а не удаляем
	tween.tween_callback(_hide_front_panel)
	
	print("Передняя панель снята с эффектом невесомости")

func _hide_front_panel():
	front_panel.visible = false
	front_panel.rotation = 0
	if front_panel.has_meta("original_position"):
		front_panel.position = front_panel.get_meta("original_position")
	
	front_panel_button.visible = false
	front_panel_button.rotation = 0
	if front_panel_button.has_meta("original_position"):
		front_panel_button.position = front_panel_button.get_meta("original_position")

func _on_dusty_pressed():
	# Если боковая панель видна и неактивна (болты не откручены)
	if side_panel.visible and not side_panel_active:
		print("Сначала открутите болты и снимите боковую панель!")
		return
	
	print("Нажата пыль в SideView, dusty_button = ", dusty_button)
	print("dusty_button.visible = ", dusty_button.visible)
	print("dusty_button.disabled = ", dusty_button.disabled)
	print("active_problems содержит dusty_button? ", dusty_button in active_problems)
	
	if dusty_button in active_problems:
		print("Запуск мини-игры DustyPC")
		$MinigameDustyPC.start()
	else:
		print("Пыль не в списке активных проблем!")
	
func _animate_customer_leave(callback = null):
	if not current_customer:
		if callback:
			callback.call()
		return
	
	$CustomerLeavingSound.play()
	customer_animating = true
	var tween = create_tween()
	tween.tween_property(current_customer, "position:x", CUSTOMER_START_X - 130, CUSTOMER_MOVE_DURATION).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(current_customer, "modulate:a", 0.0, CUSTOMER_MOVE_DURATION * 0.6).set_ease(Tween.EASE_IN)
	
	# Сначала очистка, потом вызов callback
	tween.tween_callback(_on_customer_left_cleanup)
	if callback:
		tween.tween_callback(callback)
		
func _on_customer_left_cleanup():
	customer_animating = false
	if current_customer:
		# Возвращаем на оригинальную позицию из словаря
		if customer_original_positions.has(current_customer):
			current_customer.position = customer_original_positions[current_customer]
		current_customer.visible = false
		current_customer.modulate.a = 1.0
		current_customer = null
	
	customer_active = false
	order_completed = true
	$ComputerView.visible = false
	$RotateButton.visible = false
	task_box.visible = false
	$Dialog.visible = false
	$DialogText.visible = false

func _on_bolt_button_down(bolt: TextureButton):
	current_bolt = bolt
	is_holding_bolt = true
	bolt_hold_timer = 0.0
	thumb_bolt_sound.play()

func _on_bolt_button_up(bolt: TextureButton):
	is_holding_bolt = false
	thumb_bolt_sound.stop()
	
	# Возвращаем болт в исходное положение (без вращения)
	if current_bolt:
		var tween = create_tween()
		tween.tween_property(current_bolt, "rotation", 0.0, 0.1)
	
	current_bolt = null

func _process(delta):
	if is_holding_bolt and current_bolt:
		bolt_hold_timer += delta
		# Вращаем болт в противоположную сторону (минус)
		current_bolt.rotation -= delta * 11  # скорость вращения выше
		
		if bolt_hold_timer >= BOLT_HOLD_TIME:
			_unscrew_current_bolt()

func _unscrew_current_bolt():
	if not current_bolt or not current_bolt.visible:
		return
		
	thumb_bolt_sound.stop()
	
	current_bolt.visible = false
	bolts_unscrewed += 1
	
	is_holding_bolt = false
	current_bolt = null
	
	if bolts_unscrewed >= thumb_bolts.size():
		_activate_side_panel()

func _hide_bolt(bolt: TextureButton):
	bolt.visible = false
	bolts_unscrewed += 1
	
	if bolts_unscrewed >= thumb_bolts.size():
		_activate_side_panel()
		
func _activate_side_panel():
	side_panel_active = true
	print("Боковая панель разблокирована")

func _on_side_panel_pressed():
	print("Нажата боковая панель. active = ", side_panel_active)
	if not side_panel_active:
		print("Панель заблокирована! Запускаем пульсацию болтов")
		_pulse_remaining_bolts()
		return
	print("Панель активна, снимаем")
	
	$FallingItem.play()
	
	var tween = create_tween()
	tween.set_parallel(true)
	# Падение вправо (по X) и немного вниз (по Y)
	tween.tween_property(side_panel, "position:x", get_viewport().size.x + 570, 0.9).set_ease(Tween.EASE_IN)
	tween.tween_property(side_panel, "position:y", get_viewport().size.y + 570, 0.9).set_ease(Tween.EASE_IN)
	tween.tween_property(side_panel, "rotation", PI * 0.85, 1.2)
	
	# Скрываем болты (если вдруг ещё видны)
	for bolt in thumb_bolts:
		bolt.visible = false
	
	# Ждём окончания анимации, потом скрываем панель
	await tween.finished
	_hide_side_panel()
	
	print("Анимация запущена, ждём завершения...")
	tween.tween_callback(_hide_side_panel)
	
	print("Боковая панель снята с эффектом невесомости")
	
func _pulse_remaining_bolts():
	# Сначала возвращаем все болты в нормальный цвет
	for bolt in thumb_bolts:
		bolt.modulate = Color(1, 1, 1, 1)
		
	var count = 0
	for bolt in thumb_bolts:
		if bolt.visible:
			print("Найден болт: ", bolt.name)
			_pulse_bolt(bolt)
			count += 1
	print("Всего неоткрученных болтов: ", count)

func _pulse_bolt(bolt: TextureButton):
	var original_color = bolt.modulate
	var yellow_color = Color(2.0, 0.977, 0.0, 0.824)
	
	var tween = create_tween()
	tween.set_loops(4)  # больше циклов мигания
	tween.tween_property(bolt, "modulate", yellow_color, 0.15)
	tween.tween_property(bolt, "modulate", original_color, 0.15)
	
	# Гарантированный сброс после окончания анимации
	tween.tween_callback(func():
		bolt.modulate = Color(1, 1, 1, 1)
	)
	
func _hide_side_panel():
	print("Анимация завершена, сбрасываем состояние панели")
	side_panel.visible = false
	side_panel_active = false
	side_panel.rotation = 0
	if side_panel.has_meta("original_position"):
		side_panel.position = side_panel.get_meta("original_position")
	# Не скрываем панель! Пусть остаётся на месте после падения
	
func reset_computer_state():
	is_front_view = false
	show_side_view()
	
	# 1. Сброс болтов боковой панели
	for bolt in thumb_bolts:
		bolt.visible = true
		bolt.rotation = 0
	bolts_unscrewed = 0
	
	# 2. Боковая панель видна, но НЕАКТИВНА
	if side_panel:
		side_panel.visible = true
		side_panel_active = false  # наш флаг
		side_panel.rotation = 0
		if side_panel.has_meta("original_position"):
			side_panel.position = side_panel.get_meta("original_position")
	
	# 3. Передняя панель
	if front_panel:
		front_panel.visible = true
		front_panel.modulate.a = 1.0
		front_panel.rotation = 0
		if front_panel.has_meta("original_position"):
			front_panel.position = front_panel.get_meta("original_position")
	
	# 4. Кнопка передней панели
	if front_panel_button:
		front_panel_button.visible = true
		front_panel_button.modulate.a = 1.0
		front_panel_button.rotation = 0
		if front_panel_button.has_meta("original_position"):
			front_panel_button.position = front_panel_button.get_meta("original_position")
	
	# 5. Сброс состояния открытия передней панели
	is_panel_open = false
	
	# Пыль НЕ сбрасываем — она управляется через generate_problems()
	
	print("Состояние компьютера сброшено (кроме пыли)")
	
func show_money_popup(amount: int, is_gain: bool = true):
	var label = Label.new()
	
	var text = ("+" if is_gain else "-") + str(amount) + " ₽"
	label.text = text
	
	label.add_theme_font_override("font", money_label.get_theme_font("font"))
	label.add_theme_font_size_override("font_size", 26)  # такой же как у XP
	
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 4)
	
	# Цвет: зелёный для добавления, красный для списания
	var color = Color(0.3, 1.0, 0.3) if is_gain else Color(1.0, 0.3, 0.3)
	label.add_theme_color_override("font_color", color)
	
	var money_pos = money_label.global_position
	label.position = Vector2(money_pos.x - 65, money_pos.y + 45)
	label.size = Vector2(200, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(1.5)
	tween.tween_callback(label.queue_free)
	
# Обработчики сигналов от dusty_minigame
func _play_dusty_click_sound():
	$ButtonClickSound.play()

func _on_dusty_case_visibility(visible: bool):
	$ComputerView/SideView/SideGamingCase.visible = visible

func _show_level3_panel():
	level3_panel.visible = true
	level3_button.pressed.connect(_on_level3_button_pressed)

func _on_level3_button_pressed():
	get_tree().change_scene_to_file("res://scenes/ending.tscn")
	
