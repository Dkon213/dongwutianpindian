extends Node2D

## 仓库库存管理器：统计飞向 barn 的各类果实数量，并在 GridContainer 中显示。

# 支持的果实类型及对应图标路径（可扩展）
const FRUIT_ICONS := {
	"carrot": "res://assets/Things/field/fruits/fruit_carrot.png",
	"tomato": "res://assets/Things/field/fruits/fruit_tomato.png",
	"wheat": "res://assets/Things/field/fruits/fruit_wheat.png",
}

# 果实显示顺序（决定 GridContainer 中格子的排列顺序）
const FRUIT_ORDER := ["carrot", "tomato", "wheat"]

@onready var _grid: GridContainer = $barn_PanelContainer/barn_MarginContainer/barn_NinePatchRect/barn_GridContainer

const ITEM_SLOT_SCENE := preload("res://scenes/map_field_barn_item_slot.tscn")

var _inventory: Dictionary = {}

func _ready() -> void:
	for fruit_type in FRUIT_ORDER:
		_inventory[fruit_type] = 0
	_create_slots()

# 创建所有物品槽
func _create_slots() -> void:
	# 先删除所有已有的物品槽
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	# 创建新的物品槽
	for fruit_type in FRUIT_ORDER:
		var slot := ITEM_SLOT_SCENE.instantiate()
		_setup_slot(slot, fruit_type, 0)
		_grid.add_child(slot)


func _setup_slot(slot: Control, fruit_type: String, count: int) -> void:
	var icon_path: String = FRUIT_ICONS.get(fruit_type, "")
	if icon_path != "":
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
	if not FRUIT_ICONS.has(fruit_type):
		push_warning("barn_inventory: 未知果实类型 '%s'，已忽略" % fruit_type)
		return
	_inventory[fruit_type] = _inventory.get(fruit_type, 0) + 1
	_refresh_slots()


func _refresh_slots() -> void:
	for i in _grid.get_child_count():
		var slot: Control = _grid.get_child(i)
		var fruit_type: String = FRUIT_ORDER[i] if i < FRUIT_ORDER.size() else ""
		var count: int = _inventory.get(fruit_type, 0)
		_setup_slot(slot, fruit_type, count)
