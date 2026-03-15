extends Node2D

## 仓库库存管理器：统计飞向 barn 的各类果实数量，并在 GridContainer 中显示。
## 果实类型与图标等来自 CropDB 单例。

@onready var _barn_area: Area2D = $barn_area
@onready var _barn_panel: PanelContainer = $barn_PanelContainer
@onready var _grid: GridContainer = $barn_PanelContainer/barn_MarginContainer/barn_NinePatchRect/barn_GridContainer

const ITEM_SLOT_SCENE := preload("res://scenes/field/map_field_barn_item_slot.tscn")

var _inventory: Dictionary = {}

func _ready() -> void:
	for fruit_type in CropDB.get_crop_ids():
		_inventory[fruit_type] = 0
	_create_slots()

func _process(_delta: float) -> void:
	var mouse_pos := get_global_mouse_position()
	var in_area := _is_mouse_in_barn_area(mouse_pos)
	var in_panel := _barn_panel.get_global_rect().has_point(mouse_pos)
	_barn_panel.visible = in_area or in_panel

func _is_mouse_in_barn_area(global_pos: Vector2) -> bool:
	var params := PhysicsPointQueryParameters2D.new()
	params.position = global_pos
	params.collide_with_bodies = false
	params.collide_with_areas = true
	var results := get_world_2d().direct_space_state.intersect_point(params)
	for r in results:
		if r["collider"] == _barn_area:
			return true
	return false

# 创建所有物品槽
func _create_slots() -> void:
	# 先删除所有已有的物品槽
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	# 创建新的物品槽
	for fruit_type in CropDB.get_crop_ids():
		var slot := ITEM_SLOT_SCENE.instantiate()
		_setup_slot(slot, fruit_type, 0)
		_grid.add_child(slot)

# 设置物品槽的显示内容
func _setup_slot(slot: Control, fruit_type: String, count: int) -> void:
	var icon_path: String = CropDB.get_barn_icon_path(fruit_type)
	if icon_path != "":#如果图标路径不为空，则加载图标
		var icon_tex := load(icon_path) as Texture2D
		if icon_tex:
			var icon_rect: TextureRect = slot.get_node_or_null("MarginContainer/HBoxContainer/barn_icon")
			if icon_rect:
				icon_rect.texture = icon_tex
	var label: Label = slot.get_node_or_null("MarginContainer/HBoxContainer/barn_lable")
	if label:
		label.text = str(count)


## 增加指定类型果实数量并刷新显示
func add_fruit(fruit_type: String) -> void:
	if not CropDB.has_crop(fruit_type):  # 果实类型不在配置中则忽略
		push_warning("barn_inventory: 未知果实类型 '%s'，已忽略" % fruit_type)
		return
	_inventory[fruit_type] = _inventory.get(fruit_type, 0) + 1#增加指定类型果实数量
	_refresh_slots()


func _refresh_slots() -> void:  # 刷新所有物品槽的显示内容
	var crop_ids: Array = CropDB.get_crop_ids()
	for i in _grid.get_child_count():
		var slot: Control = _grid.get_child(i)
		var fruit_type: String = crop_ids[i] if i < crop_ids.size() else ""
		var count: int = _inventory.get(fruit_type, 0)
		_setup_slot(slot, fruit_type, count)
