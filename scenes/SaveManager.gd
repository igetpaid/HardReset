extends Node

const SAVE_PATH = "user://savegame.save"

func save_game(money: int, exp: int, level: int):
	var save_data = {
		"money": money,
		"exp": exp,
		"level": level
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data))
	print("Игра сохранена")

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		return null
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var content = file.get_as_text()
	var data = JSON.parse_string(content)
	return data

func delete_save():
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		print("Сохранение удалено")

func has_save():
	return FileAccess.file_exists(SAVE_PATH)
