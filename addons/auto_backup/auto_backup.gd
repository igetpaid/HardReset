@tool
extends EditorPlugin

# Settings Keys
const SETTING_FREQ = "addons/auto_backup/save_frequency_minutes"
const SETTING_DIR = "addons/auto_backup/output_directory"
const SETTING_ENABLE_ZIP = "addons/auto_backup/enable_zipping"
const SETTING_PERSIST = "addons/auto_backup/persistent_count"
const SETTING_COUNT_VAL = "addons/auto_backup/_internal_count_storage"

# State
var backup_count: int = 0
var backup_timer: Timer
var confirm_dialog: ConfirmationDialog

func _enter_tree():
	_setup_settings()
	
	if ProjectSettings.get_setting(SETTING_PERSIST):
		backup_count = ProjectSettings.get_setting(SETTING_COUNT_VAL)
	
	# Только диалог подтверждения (нужен для сброса)
	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "Reset AutoBackup?"
	confirm_dialog.dialog_text = "Are you sure you want to reset the session backup count and timer?"
	confirm_dialog.confirmed.connect(_perform_reset)
	get_editor_interface().get_base_control().add_child(confirm_dialog)
	
	# Таймер автосохранения
	backup_timer = Timer.new()
	add_child(backup_timer)
	backup_timer.timeout.connect(_on_backup_timeout)
	
	ProjectSettings.settings_changed.connect(_on_settings_changed)
	_reset_timer()

func _exit_tree():
	if backup_timer:
		backup_timer.queue_free()
	if confirm_dialog:
		confirm_dialog.queue_free()

func _on_settings_changed():
	_reset_timer()

func _reset_timer():
	var mins = ProjectSettings.get_setting(SETTING_FREQ)
	backup_timer.start((mins if mins > 0 else 5) * 60)

func _setup_settings():
	_add_setting(SETTING_FREQ, 5, TYPE_INT, PROPERTY_HINT_RANGE, "1,120,1,or_greater")
	_add_setting(SETTING_DIR, "user://backups/", TYPE_STRING, PROPERTY_HINT_GLOBAL_DIR)
	_add_setting(SETTING_ENABLE_ZIP, false, TYPE_BOOL)
	_add_setting(SETTING_PERSIST, true, TYPE_BOOL)
	_add_setting(SETTING_COUNT_VAL, 0, TYPE_INT, PROPERTY_HINT_RANGE, "0,9999,1,or_greater")

func _add_setting(name: String, default_value, type: int, hint: int = PROPERTY_HINT_NONE, hint_string: String = ""):
	if not ProjectSettings.has_setting(name):
		ProjectSettings.set_setting(name, default_value)
	ProjectSettings.add_property_info({"name": name, "type": type, "hint": hint, "hint_string": hint_string})
	ProjectSettings.save()

func _on_backup_timeout():
	var backup_result = await _run_backup_logic()
	if backup_result != "":
		backup_count += 1
		_update_stored_count()
		
		# Показываем тост (маленькое уведомление в углу)
		if backup_result == "SAVE_ONLY":
			_show_toast("Auto-Saved Successfully")
		else:
			_show_toast("Created Backup Archive: '%s'" % backup_result)
	_reset_timer()

func _show_toast(message: String):
	var base = get_editor_interface().get_base_control()
	var toast = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.set_corner_radius_all(5)
	toast.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	toast.add_child(margin)
	
	var label = Label.new()
	label.text = message
	margin.add_child(label)
	
	base.add_child(toast)
	toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	toast.position.y -= 40
	toast.position.x += 20
	
	var tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(toast, "modulate:a", 0.0, 0.6)
	tween.tween_callback(toast.queue_free)

func _update_stored_count():
	if ProjectSettings.get_setting(SETTING_PERSIST):
		ProjectSettings.set_setting(SETTING_COUNT_VAL, backup_count)
		ProjectSettings.save()

func _on_reset_pressed():
	confirm_dialog.popup_centered()

func _perform_reset():
	backup_count = 0
	_update_stored_count()
	_reset_timer()

# ==========================================
# Основная логика сохранения
# ==========================================

func _trigger_native_script_save(node: Node) -> bool:
	if node is PopupMenu:
		for i in range(node.get_item_count()):
			var text = node.get_item_text(i).to_lower()
			if "save all" in text:
				var id = node.get_item_id(i)
				node.id_pressed.emit(id)
				return true
	for child in node.get_children(true):
		if _trigger_native_script_save(child):
			return true
	return false

func _run_backup_logic() -> String:
	var ei = get_editor_interface()
	
	# 1. Сохраняем сцены
	ei.save_all_scenes()
	
	# 2. Сохраняем скрипты
	var script_editor = ei.get_script_editor()
	if script_editor:
		_trigger_native_script_save(script_editor)
	
	await get_tree().process_frame
	
	# 3. Проверяем, нужно ли создавать ZIP
	var should_zip = ProjectSettings.get_setting(SETTING_ENABLE_ZIP)
	if not should_zip:
		print("AutoBackup: Auto-saved all scenes and scripts (Zipping disabled).")
		return "SAVE_ONLY"
	
	# 4. Сканируем файловую систему
	ei.get_resource_filesystem().scan()
	
	var output_path = ProjectSettings.get_setting(SETTING_DIR)
	var proj_name = ProjectSettings.get_setting("application/config/name")
	if not DirAccess.dir_exists_absolute(output_path):
		DirAccess.make_dir_recursive_absolute(output_path)
	
	var next_idx = _get_next_index(output_path, proj_name)
	var file_name = "%s_%03d.zip" % [proj_name, next_idx]
	var final_path = output_path.path_join(file_name)
	
	var writer = ZIPPacker.new()
	if writer.open(final_path) == OK:
		_recursive_zip("res://", writer, output_path)
		writer.close()
		print("AutoBackup: Saved and Zipped to ", final_path)
		return file_name
	return ""

func _get_next_index(path: String, prefix: String) -> int:
	var dir = DirAccess.open(path)
	var max_idx = 0
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.begins_with(prefix) and file_name.ends_with(".zip"):
				var parts = file_name.get_basename().split("_")
				if parts.size() > 1 and parts[-1].is_valid_int():
					max_idx = max(max_idx, parts[-1].to_int())
			file_name = dir.get_next()
	return max_idx + 1

func _recursive_zip(base_path: String, writer: ZIPPacker, output_dir: String):
	var dir = DirAccess.open(base_path)
	if dir:
		dir.list_dir_begin()
		var item = dir.get_next()
		while item != "":
			if item.begins_with(".") or item == "addons/auto_backup" or item == ".godot":
				item = dir.get_next()
				continue
			
			var full = base_path.path_join(item)
			
			var global_full = ProjectSettings.globalize_path(full)
			var global_out = ProjectSettings.globalize_path(output_dir)
			if global_full.begins_with(global_out):
				item = dir.get_next()
				continue
			
			if dir.current_is_dir():
				_recursive_zip(full + "/", writer, output_dir)
			else:
				var f = FileAccess.open(full, FileAccess.READ)
				if f:
					writer.start_file(full.replace("res://", ""))
					var chunk_size = 8 * 1024 * 1024
					while not f.eof_reached():
						var chunk = f.get_buffer(chunk_size)
						if chunk.size() > 0:
							writer.write_file(chunk)
					writer.close_file()
			item = dir.get_next()