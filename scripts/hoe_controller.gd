extends Node2D

@onready var _hoe_area: Area2D = $hoe_area
@onready var _shelf_area: Area2D = get_node("../shelf/shelf_area")
@onready var _farming_system: Node = get_node("../farming_system")
@onready var _pot_controller: Node = get_node("../pot")

var _is_following_mouse: bool = false
var _start_position: Vector2


func _ready() -> void:
	_start_position = position

	if _hoe_area and not _hoe_area.input_event.is_connected(_on_hoe_area_input_event):
		_hoe_area.input_event.connect(_on_hoe_area_input_event)

	if _shelf_area and not _shelf_area.input_event.is_connected(_on_shelf_area_input_event):
		_shelf_area.input_event.connect(_on_shelf_area_input_event)

	_set_hoe_following(false)


func _process(_delta: float) -> void:
	if _is_following_mouse:
		global_position = get_global_mouse_position()


func _unhandled_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return

	# 仅在锄头跟随鼠标时才处理右键复位
	if _is_following_mouse and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		_reset_hoe()


func _on_hoe_area_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return

	# 左键点击 hoe_area，开始跟随鼠标
	if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		# 如果此时水壶正在跟随鼠标，先让水壶复位
		if _pot_controller and _pot_controller.has_method("is_following") and _pot_controller.is_following():
			_pot_controller.reset_from_other_tool()

		_is_following_mouse = true
		_set_hoe_following(true)
		get_viewport().set_input_as_handled()


func _on_shelf_area_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return

	# 当锄头正在跟随鼠标时，左键点击 shelf 区域也会让锄头复位
	if _is_following_mouse and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		_reset_hoe()
		get_viewport().set_input_as_handled()


func _reset_hoe() -> void:
	_is_following_mouse = false
	position = _start_position
	_set_hoe_following(false)


func is_following() -> bool:
	return _is_following_mouse


func reset_from_other_tool() -> void:
	_reset_hoe()


func _set_hoe_following(is_following: bool) -> void:
	if _farming_system and _farming_system.has_method("set_hoe_following_mouse"):
		_farming_system.set_hoe_following_mouse(is_following)

