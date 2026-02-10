extends Node2D

@onready var _pot_area: Area2D = $pot_area
@onready var _shelf_area: Area2D = get_node("../shelf/shelf_area")
@onready var _farming_system: Node = get_node("../farming_system")
@onready var _hoe_controller: Node = get_node("../hoe")
@onready var _pot_animation: AnimatedSprite2D = $pot_animation

var _is_following_mouse: bool = false
var _start_position: Vector2
var _default_scale: Vector2
var _follow_scale: Vector2
var _idle_light_timer: float = 0.0  # 用于每 5 秒播放 pot_light 待机动画


func _ready() -> void:
	_start_position = position
	_default_scale = scale
	# 目标从 (1.5, 1.5) 放大到 (1.7, 1.7)，比例约为 1.1333
	_follow_scale = _default_scale * 1.1333333

	if _pot_area and not _pot_area.input_event.is_connected(_on_pot_area_input_event):
		_pot_area.input_event.connect(_on_pot_area_input_event)

	if _shelf_area and not _shelf_area.input_event.is_connected(_on_shelf_area_input_event):
		_shelf_area.input_event.connect(_on_shelf_area_input_event)

	if _pot_animation and not _pot_animation.animation_finished.is_connected(_on_pot_animation_finished):
		_pot_animation.animation_finished.connect(_on_pot_animation_finished)

	_set_pot_following(false)


func _process(delta: float) -> void:
	if _is_following_mouse:
		global_position = get_global_mouse_position()
		_idle_light_timer = 0.0  # 被持有时不累计，放下后重新计 5 秒
	else:
		# 待机时每 5 秒自动播放一次 pot_light
		_idle_light_timer += delta
		if _idle_light_timer >= 5.0 and _pot_animation: # 如果计时器大于5秒，并且pot_animation存在，则播放pot_light动画
			var anim := _pot_animation.animation # 获取当前动画	
			var can_play_idle := (anim != "pot_water") and not (anim == "pot_light" and _pot_animation.is_playing()) # 如果当前动画不是pot_water，并且不是pot_light正在播放，则可以播放pot_light动画
			if can_play_idle:
				_pot_animation.play("pot_light") # 播放pot_light动画
				_idle_light_timer = 0.0 # 重置计时器


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
	# 跟随时放大，不跟随时恢复默认大小
	if is_following:
		scale = _follow_scale
		_idle_light_timer = 0.0  # 拿起时重置待机动画计时
	else:
		scale = _default_scale

	if _farming_system and _farming_system.has_method("set_pot_following_mouse"):
		_farming_system.set_pot_following_mouse(is_following)


func play_use_animation() -> void:
	if not _pot_animation:
		return

	# 如果水动画正在播放，则忽略新的点击（不会从头开始）
	if _pot_animation.animation == "pot_water" and _pot_animation.is_playing():
		return

	_pot_animation.play("pot_water")


func _on_pot_animation_finished() -> void:
	# 水动画或 pot_light 结束后切回默认待机动画
	if _pot_animation.animation == "pot_water" or _pot_animation.animation == "pot_light":
		_pot_animation.play("pot_default")

