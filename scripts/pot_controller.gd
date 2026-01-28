extends Node2D

@onready var _pot_area: Area2D = $pot_area
@onready var _shelf_area: Area2D = get_node("../shelf/shelf_area")
@onready var _farming_system: Node = get_node("../farming_system")
@onready var _hoe_controller: Node = get_node("../hoe")

var _is_following_mouse: bool = false
var _start_position: Vector2


func _ready() -> void:
	_start_position = position

	if _pot_area and not _pot_area.input_event.is_connected(_on_pot_area_input_event):
		_pot_area.input_event.connect(_on_pot_area_input_event)

	if _shelf_area and not _shelf_area.input_event.is_connected(_on_shelf_area_input_event):
		_shelf_area.input_event.connect(_on_shelf_area_input_event)

	_set_pot_following(false)


func _process(_delta: float) -> void:
	if _is_following_mouse:
		global_position = get_global_mouse_position()


func _unhandled_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return

	# 仅在水壶跟随鼠标时才处理右键复位
	if _is_following_mouse and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		_reset_pot()


func _on_pot_area_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return

	# 左键点击 pot_area，开始跟随鼠标
	if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		# 如果此时锄头正在跟随鼠标，先让锄头复位
		if _hoe_controller and _hoe_controller.has_method("is_following") and _hoe_controller.is_following():
			_hoe_controller.reset_from_other_tool()

		_is_following_mouse = true
		_set_pot_following(true)
		get_viewport().set_input_as_handled()


func _on_shelf_area_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return

	# 当水壶正在跟随鼠标时，左键点击 shelf 区域也会让水壶复位
	if _is_following_mouse and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		_reset_pot()
		get_viewport().set_input_as_handled()


func _reset_pot() -> void:
	_is_following_mouse = false
	position = _start_position
	_set_pot_following(false)


func is_following() -> bool:
	return _is_following_mouse


func reset_from_other_tool() -> void:
	_reset_pot()


func _set_pot_following(is_following: bool) -> void:
	if _farming_system and _farming_system.has_method("set_pot_following_mouse"):
		_farming_system.set_pot_following_mouse(is_following)

