extends Control

@onready var ok_button = $Button

const MobileSizer = preload("res://tools/mobile_sizer.gd")

func _ready():
	MobileSizer.enlarge_scene(self)
	ok_button.pressed.connect(_on_ok_pressed)

func _on_ok_pressed():
	get_tree().change_scene_to_file("res://scenes/main.tscn")
