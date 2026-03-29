extends Node2D

const SHOP_ITEM_SLOT_SCENE := preload("res://scenes/field/map_field_shop_item_slot.tscn")

@onready var _shop_menu: Window = $"../UI/shop_menu_window"
@onready var _shop_area: Area2D = $shop_area
@onready var _shop_grid: GridContainer = $"../UI/shop_menu_window/shop_content_scaled_root/TabContainer_seeds/MarginContainer_seed/shop_menu_ScrollContainer/shop_menu_GridContainer"
@onready var _seed_cursor: Node = $"../UI/seed_cursor"


func _ready() -> void:
	_populate_shop_grid()
	# 确保 shop_area 能接收鼠标输入（某些配置下 Area2D 默认可能不接收）
	if _shop_area:
		_shop_area.input_pickable = true
	# 点击窗口自带关闭按钮时关闭
	_shop_menu.close_requested.connect(_on_shop_menu_close_requested)


func _populate_shop_grid() -> void:
	for item_data in CropDB.get_shop_items():
		var texture := load(item_data.texture_path) as Texture2D
		if texture == null:
			push_warning("商店商品图片加载失败: %s" % item_data.texture_path)
			continue
		var plant_type: String = item_data.get("plant_type", "")
		var slot: TextureButton = SHOP_ITEM_SLOT_SCENE.instantiate()
		slot.setup(texture, item_data.name, item_data.price, plant_type)
		if slot.has_signal("item_clicked"):
			slot.item_clicked.connect(_on_shop_item_clicked)
		_shop_grid.add_child(slot)


func _on_shop_item_clicked(plant_type: String, texture: Texture2D) -> void:
	if _seed_cursor and _seed_cursor.has_method("pick_seed"):
		_seed_cursor.pick_seed(plant_type, texture)


func _on_shop_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var mouse_btn := event as InputEventMouseButton
	if mouse_btn == null or mouse_btn.button_index != MOUSE_BUTTON_LEFT or not mouse_btn.pressed:
		return
	get_viewport().set_input_as_handled()  # 避免事件继续传递
	_open_shop_menu_at_mouse()


func _open_shop_menu_at_mouse() -> void:
	# 使用屏幕坐标（当 popup_window=true 且 embed_subwindows=false 时，Window 为原生弹出窗口）
	var mouse_pos: Vector2 = DisplayServer.mouse_get_position()
	if _shop_menu.has_method("prepare_for_popup_at_global_pos"):
		_shop_menu.prepare_for_popup_at_global_pos(mouse_pos)
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
	if not _shop_menu.visible:
		return
	# 按 Esc 关闭
	if event is InputEventKey:
		var key_ev := event as InputEventKey
		if key_ev.pressed and key_ev.keycode == KEY_ESCAPE:
			_shop_menu.hide()
			get_viewport().set_input_as_handled()
		return
	# 当种子跟随鼠标时：左键点击 shop_menu_window 范围外可关闭窗口（使用 _input 以在 farming 处理前执行）
	var mouse_btn := event as InputEventMouseButton
	if mouse_btn != null and mouse_btn.pressed and mouse_btn.button_index == MOUSE_BUTTON_LEFT:
		if _seed_cursor and _seed_cursor.has_method("is_following") and _seed_cursor.is_following():
			var mouse_pos: Vector2 = DisplayServer.mouse_get_position()
			var menu_rect := Rect2(Vector2(_shop_menu.position.x, _shop_menu.position.y), Vector2(_shop_menu.size.x, _shop_menu.size.y))
			if not menu_rect.has_point(mouse_pos):
				_shop_menu.hide()
				# 不消耗事件，允许 farming_system 继续处理种植
