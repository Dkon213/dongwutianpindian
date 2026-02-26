extends Node2D

@onready var _shop_menu: Window = $"../UI/shop_menu_window"
@onready var _shop_area: Area2D = $shop_area


func _ready() -> void:
	# 确保 shop_area 能接收鼠标输入（某些配置下 Area2D 默认可能不接收）
	if _shop_area:
		_shop_area.input_pickable = true
	# 点击窗口自带关闭按钮时关闭
	_shop_menu.close_requested.connect(_on_shop_menu_close_requested)


func _on_shop_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var mouse_btn := event as InputEventMouseButton
	if mouse_btn == null or mouse_btn.button_index != MOUSE_BUTTON_LEFT or not mouse_btn.pressed:
		return
	get_viewport().set_input_as_handled()  # 避免事件继续传递
	_open_shop_menu_at_mouse()


func _open_shop_menu_at_mouse() -> void:
	# 使用屏幕坐标（当 popup_window=true 且 embed_subwindows=false 时，Window 为原生弹出窗口）
	var mouse_pos: Vector2 = DisplayServer.mouse_get_position()
	var sz: Vector2i = _shop_menu.size
	# 让窗口右下角落在点击位置
	var pos := Vector2i(int(mouse_pos.x - sz.x), int(mouse_pos.y - sz.y))
	# 限制在屏幕内，避免完全跑出可视范围
	var screen_size := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	pos.x = clampi(pos.x, -sz.x + 20, screen_size.x - 20)
	pos.y = clampi(pos.y, -sz.y + 20, screen_size.y - 20)
	_shop_menu.position = pos
	_shop_menu.popup()


func _on_shop_menu_close_requested() -> void:
	_shop_menu.hide()


func _unhandled_input(event: InputEvent) -> void:
	# 点击窗口外部时关闭（使用屏幕坐标，与原生弹出窗口一致）
	if not _shop_menu.visible:
		return
	var mouse_btn := event as InputEventMouseButton
	if mouse_btn != null and mouse_btn.pressed and mouse_btn.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos: Vector2 = DisplayServer.mouse_get_position()
		var menu_rect := Rect2(Vector2(_shop_menu.position.x, _shop_menu.position.y), Vector2(_shop_menu.size.x, _shop_menu.size.y))
		if not menu_rect.has_point(mouse_pos):
			_shop_menu.hide()
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	# 按 Esc 关闭
	if not _shop_menu.visible:
		return
	if event is InputEventKey:
		var key_ev := event as InputEventKey
		if key_ev.pressed and key_ev.keycode == KEY_ESCAPE:
			_shop_menu.hide()
			get_viewport().set_input_as_handled()
