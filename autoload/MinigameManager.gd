extends Node

signal minigame_completed(minigame_id: String, success: bool, completion_time: float)
signal money_changed(new_amount: int)
signal exp_changed(new_exp: int, new_level: int, exp_needed: int)
signal level_up(new_level: int)
signal xp_gained_with_multiplier(amount: int, multiplier: float)

var current_minigame = null
var current_fan_button = null
var player_money: int = 100
var current_exp: int = 0
var current_level: int = 1
var exp_to_next_level: int = 100

const MINIGAMES = {
	"broken_fan": "res://minigames/minigame_fix_fan.tscn",
}

func start_minigame(minigame_id: String) -> bool:
	if not MINIGAMES.has(minigame_id):
		print("Ошибка: Мини-игра '", minigame_id, "' не найдена")
		return false
	
	var path = MINIGAMES[minigame_id]
	var scene = load(path)
	if not scene:
		print("Ошибка: Не удалось загрузить сцену '", path, "'")
		return false
	
	current_minigame = scene.instantiate()
	get_tree().root.add_child(current_minigame)
	print("Запущена мини-игра: ", minigame_id)
	return true

func complete_minigame(minigame_id: String, success: bool, completion_time: float = 0.0):
	print("Sending from instance ID: ", get_instance_id())
	# Сначала отправляем сигнал
	minigame_completed.emit(minigame_id, success, completion_time)
	await get_tree().process_frame  # даём время на обработку сигнала
	print("Сигнал отправлен, minigame_id: ", minigame_id)
	
	# Потом удаляем мини-игру
	if current_minigame:
		current_minigame.queue_free()
		current_minigame = null

func add_money(amount: int):
	player_money += amount
	money_changed.emit(player_money)
	SaveManager.save_game(player_money, current_exp, current_level)
	print("Денег добавлено: ", amount, ". Теперь: ", player_money)

func subtract_money(amount: int) -> bool:
	if player_money >= amount:
		player_money -= amount
		money_changed.emit(player_money)
		SaveManager.save_game(player_money, current_exp, current_level)
		print("Денег списано: ", amount, ". Осталось: ", player_money)
		return true
	else:
		print("Не хватает денег! Нужно: ", amount, ", есть: ", player_money)
		return false
		
func add_exp(amount: int):
	current_exp += amount
	print("Опыта добавлено: ", amount, ". Всего: ", current_exp)
	
	# Проверяем повышение уровня
	while current_exp >= exp_to_next_level:
		current_exp -= exp_to_next_level
		current_level += 1
		exp_to_next_level = _calculate_exp_for_level(current_level)
		print("Повышение уровня! Теперь уровень: ", current_level)
		level_up.emit(current_level)
	
	# Отправляем сигнал об обновлении
	exp_changed.emit(current_exp, current_level, exp_to_next_level)
	
	SaveManager.save_game(player_money, current_exp, current_level)
	
func _calculate_exp_for_level(level: int) -> int:
	return 100 * level  # 1 уровень = 100, 2 = 200, 3 = 300 и т.д.

func load_progress():
	var data = SaveManager.load_game()
	if data:
		player_money = data["money"]
		current_exp = data["exp"]
		current_level = data["level"]
		exp_to_next_level = _calculate_exp_for_level(current_level)
		# Корректировка опыта
		while current_exp >= exp_to_next_level:
			current_exp -= exp_to_next_level
			current_level += 1
			exp_to_next_level = _calculate_exp_for_level(current_level)
		# Отправка сигналов для обновления UI
		money_changed.emit(player_money)
		exp_changed.emit(current_exp, current_level, exp_to_next_level)
		print("Прогресс загружен: деньги=", player_money, " опыт=", current_exp, " уровень=", current_level)
		return true
	return false
