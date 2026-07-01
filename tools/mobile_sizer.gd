# mobile_sizer.gd
# Увеличивает мелкие кнопки для Android touch targets.
# Вызвать: MobileSizer.enlarge_scene(self) в _ready() любой сцены.
# На Windows — ничего не делает, если force_enabled = false.
#
# Подход: SCALE вместо изменения rect.
# - rect, offset_*, position не трогаются (любой layout_mode)
# - scale применяется от pivot_offset
# - pivot_offset НЕ сбрасывается — кнопки с rotation продолжают правильно вращаться
# - texture_filter переключается на LINEAR — дробный scale (1.5x) даёт плавное изображение
#
# Исключить кнопку из увеличения:
#   btn.set_meta("mobile_exclude", true)
#
# Когда вызывается несколько раз (разные сцены в одной сессии),
# scale применяется один раз на каждый заход в _ready().

static var force_enabled: bool = false

static func enlarge_scene(root: Node, factor: float = 1.5) -> void:
	if OS.get_name() != "Android" and not force_enabled:
		return
	_collect_and_enlarge(root, factor)

static func _collect_and_enlarge(node: Node, factor: float) -> void:
	for child in node.get_children():
		if _is_small_button(child):
			_enlarge(child, factor)
		_collect_and_enlarge(child, factor)

# Проверка: визуальный размер (rect_size * собственный scale) меньше 100px
# visible НЕ проверяем — кнопки в диалогах/скрытых панелях тоже должны быть увеличены
# Только BaseButton — TextureRect (glow rings, иконки) не трогаем
static func _is_small_button(node: Node) -> bool:
	if not (node is BaseButton):
		return false
	var c: Control = node as Control
	if c.mouse_filter == Control.MOUSE_FILTER_IGNORE \
	or c.mouse_filter == Control.MOUSE_FILTER_PASS:
		return false
	# Проверяем мета-исключение
	if c.has_meta("mobile_exclude") and c.get_meta("mobile_exclude"):
		return false
	var visual_size = c.size * c.scale
	return min(visual_size.x, visual_size.y) < 100.0

static func _enlarge(ctrl: Control, factor: float) -> void:
	# Linear-фильтр — дробный scale (1.5x) даёт плавное, а не ломаное изображение
	ctrl.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	# pivot_offset НЕ меняем, если он уже задан (кнопки с rotation)
	if ctrl.pivot_offset == Vector2.ZERO:
		var old_scale := ctrl.scale
		# Ставим pivot в центр rect
		ctrl.pivot_offset = ctrl.size / 2.0
		# Компенсируем сдвиг визуального центра при смене pivot:
		#   до: визуальный центр = pos + size * old_scale / 2
		#   после: визуальный центр = pos + pivot (= pos + size/2)
		#   чтобы центр остался на месте, сдвигаем pos:
		#   pos += size * (old_scale - 1) / 2
		if old_scale != Vector2.ONE:
			ctrl.position += ctrl.size * (old_scale - Vector2.ONE) / 2.0
	# scale применяется от pivot — rect не трогается, центр сохраняется
	ctrl.scale *= factor
