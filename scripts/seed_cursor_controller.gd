extends Node2D
## 种子图标跟随鼠标控制器。当玩家点击商店中的种子商品后，对应图标跟随鼠标，可在已耕地块上种植。

@onready var _texture_rect: TextureRect = $seed_cursor_TextureRect
@onready var _farming_system: Node = $"../../farming_system"
@onready var _pot_controller: Node = $"../../pot"
@onready var _hoe_controller: Node = $"../../hoe"

var _is_following: bool = false
var _current_plant_type: String = ""


func _ready() -> void:
	visible = false
	# 使 TextureRect 中心对准父节点原点（即鼠标位置）
	if _texture_rect:
		_texture_rect.position = Vector2(-20, -20)


func _process(_delta: float) -> void:
	if _is_following:
		global_position = get_global_mouse_position()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_following:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_seed()
		get_viewport().set_input_as_handled()


func pick_seed(plant_type: String, texture: Texture2D) -> void:
	"""拿起种子，图标开始跟随鼠标。会取消 pot/hoe。"""
	if _pot_controller and _pot_controller.has_method("reset_from_other_tool"):
		_pot_controller.reset_from_other_tool()
	if _hoe_controller and _hoe_controller.has_method("reset_from_other_tool"):
		_hoe_controller.reset_from_other_tool()

	_current_plant_type = plant_type
	_is_following = true
	visible = true
	if _texture_rect:
		_texture_rect.texture = texture

	if _farming_system and _farming_system.has_method("set_seed_following_mouse"):
		_farming_system.set_seed_following_mouse(true, plant_type)


func cancel_seed() -> void:
	"""取消种子跟随（供 pot/hoe 等外部调用）。"""
	_cancel_seed()


func _cancel_seed() -> void:
	_is_following = false
	_current_plant_type = ""
	visible = false
	if _texture_rect:
		_texture_rect.texture = null

	if _farming_system and _farming_system.has_method("set_seed_following_mouse"):
		_farming_system.set_seed_following_mouse(false, "")


func is_following() -> bool:
	return _is_following
