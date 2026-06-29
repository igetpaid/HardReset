extends Control

@onready var ok_button = $Button

func _ready():
	ok_button.pressed.connect(_on_ok_pressed)

func _on_ok_pressed():
	get_tree().change_scene_to_file("res://scenes/main.tscn")
