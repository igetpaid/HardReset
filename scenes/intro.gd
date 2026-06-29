extends Control

@onready var video_player = $VideoStreamPlayer
@onready var skip_progress = $SkipProgressBar
@onready var skip_hint = $SkipHintLabel

var skip_held_time = 0.0
var skip_required_time = 1.0
var skip_active = false
var video_ended = false

func _ready():
	skip_progress.visible = false
	skip_hint.visible = true
	skip_hint.modulate.a = 0.5
	skip_progress.value = 0
	video_player.play()
	video_player.finished.connect(_on_video_finished)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	# Плавное исчезновение подсказки через 1 секунду
	var tween = create_tween()
	tween.tween_property(skip_hint, "modulate:a", 0.0, 0.5).set_delay(1.0)
	tween.tween_property(skip_progress, "modulate:a", 0.0, 0.5).set_delay(1.0)
	tween.tween_callback(func(): 
		if not skip_active:
			skip_hint.visible = false
	)

func _process(delta):
	var any_key_pressed = false
	
	# Проверяем основные клавиши и кнопки мыши
	if Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_ESCAPE):
		any_key_pressed = true
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		any_key_pressed = true
	
	if any_key_pressed and not video_ended:
		if not skip_active:
			skip_active = true
			skip_held_time = 0.0
			skip_progress.visible = true
			if not skip_hint.visible:
				skip_hint.visible = true
				skip_hint.modulate.a = 1.0
		skip_held_time += delta
		var progress = min(skip_held_time / skip_required_time, 1.0) * 100
		skip_progress.value = progress
		if skip_held_time >= skip_required_time:
			_go_to_game()
	else:
		if skip_active:
			skip_active = false
			skip_progress.visible = false
			skip_progress.value = 0
			if skip_hint.visible and skip_hint.modulate.a == 1.0:
				var tween = create_tween()
				tween.tween_property(skip_hint, "modulate:a", 0.0, 0.5)
				tween.tween_callback(func(): 
					if not skip_active:
						skip_hint.visible = false
				)

func _on_video_finished():
	video_ended = true
	_go_to_game()

func _go_to_game():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/game.tscn")
