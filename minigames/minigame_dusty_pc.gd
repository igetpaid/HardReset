extends Control

signal completed(success: bool, completion_time: float)
signal play_click_sound()
signal toggle_case_visibility(visible: bool)

const CASE_RECT = Rect2(550, 160, 770, 760)
const PIXELS_NEEDED = 30000.0

@onready var duster_button = $DusterButton
@onready var airblower_button = $AirblowerButton
@onready var progress_bar = $CleanProgressBar
@onready var dust_texture = $GamingDustyLook
@onready var duster_cursor = $DusterCursor
@onready var airblower_animation = $AirblowerAnimation

var pixels_traveled = 0.0
var cleaning_mode = false
var is_rag_mode = false
var start_time = 0.0
var last_mouse_pos = Vector2()

func _ready():
	duster_button.pressed.connect(_on_duster_selected)
	airblower_button.pressed.connect(_on_airblower_selected)
	duster_cursor.visible = false
	hide()
	airblower_animation.visible = false

func start():
	airblower_animation.visible = false
	toggle_case_visibility.emit(false)
	pixels_traveled = 0.0
	cleaning_mode = false
	is_rag_mode = false
	progress_bar.value = 0
	dust_texture.modulate.a = 1.0
	duster_button.visible = true
	airblower_button.visible = true
	duster_cursor.visible = false
	progress_bar.visible = false  # <-- скрываем
	start_time = Time.get_ticks_msec() / 1000.0
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	animate_button_in(duster_button, duster_button.position.x)
	animate_button_in(airblower_button, airblower_button.position.x)
	show()

func _on_duster_selected():
	is_rag_mode = true
	cleaning_mode = true
	animate_button_out(duster_button)
	animate_button_out(airblower_button)
	duster_cursor.visible = true
	progress_bar.visible = true   # <-- показываем
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	last_mouse_pos = get_global_mouse_position()

func _on_airblower_selected():
	if MinigameManager.subtract_money(25):
		is_rag_mode = false
		cleaning_mode = false
		animate_button_out(duster_button)
		animate_button_out(airblower_button)
		
		# Анимация баллончика
		airblower_animation.visible = true
		airblower_animation.rotation_degrees = 22
		var tween = create_tween()
		tween.tween_property(airblower_animation, "rotation_degrees", -37, 0.5)
		tween.tween_property(airblower_animation, "rotation_degrees", 22, 0.5)
		tween.tween_callback(func(): airblower_animation.visible = false)
		
		var dust_tween = create_tween()
		dust_tween.tween_property(dust_texture, "modulate:a", 0.0, 1.0)
		dust_tween.tween_callback(_finish.bind(true))
	else:
		print("Не хватает денег для баллончика!")

func _process(delta):
	if not cleaning_mode or not is_rag_mode:
		return
	
	var mouse_pos = get_global_mouse_position()
	
	if duster_cursor.visible:
		duster_cursor.global_position = mouse_pos - duster_cursor.size / 2
	
	if CASE_RECT.has_point(mouse_pos):
		var distance = last_mouse_pos.distance_to(mouse_pos)
		pixels_traveled += distance
		
		# Прогресс от 0 до 100 (для max_value = 100)
		var progress = min(pixels_traveled / PIXELS_NEEDED, 1.0)
		progress_bar.value = progress * 100
		dust_texture.modulate.a = 1.0 - progress
		
		if pixels_traveled >= PIXELS_NEEDED:
			cleaning_mode = false
			_finish(true)
	
	last_mouse_pos = mouse_pos

func animate_button_in(button: TextureButton, start_x: float):
	button.show()
	play_click_sound.emit()
	button.modulate.a = 0.0
	button.position.x = start_x
	var tween = create_tween()
	tween.tween_property(button, "position:x", button.position.x - 478, 0.15)
	tween.parallel().tween_property(button, "modulate:a", 1.0, 0.25)

func animate_button_out(button: TextureButton):
	play_click_sound.emit()
	var tween = create_tween()
	tween.tween_property(button, "position:x", button.position.x + 478, 0.15)
	tween.parallel().tween_property(button, "modulate:a", 0.0, 0.25)
	tween.tween_callback(button.hide)

func _finish(success: bool):
	toggle_case_visibility.emit(true)
	var elapsed = (Time.get_ticks_msec() / 1000.0) - start_time
	var reward = 30 if not is_rag_mode else 20
	var exp = 60 if not is_rag_mode else 30
	
	if success:
		MinigameManager.add_money(reward)
		MinigameManager.add_exp(exp)
		MinigameManager.xp_gained_with_multiplier.emit(exp, 1.0)
		# Отправляем сигнал через MinigameManager, а не через completed
		MinigameManager.complete_minigame("dusty_pc", success, elapsed)
	
	duster_cursor.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	hide()
