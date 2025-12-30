# 仓库脚本 - 后台存储系统（无UI）
extends Node2D

# 库存字典 {种子类型: 数量}
var inventory: Dictionary = {}

# 信号：库存变化
signal inventory_changed(fruit_type: String, new_count: int)

func _ready() -> void:
	# 添加到组，方便其他节点查找
	add_to_group("warehouse")
	# 初始化库存（空字典）
	inventory = {}

# 添加果实到仓库
func add_fruit(fruit_type: String, amount: int = 1) -> void:
	if inventory.has(fruit_type):
		inventory[fruit_type] += amount
	else:
		inventory[fruit_type] = amount
	
	# 发出库存变化信号
	inventory_changed.emit(fruit_type, inventory[fruit_type])

# 获取指定果实数量
func get_fruit_count(fruit_type: String) -> int:
	if inventory.has(fruit_type):
		return inventory[fruit_type]
	return 0

# 获取所有果实库存（用于调试或未来扩展）
func get_all_fruits() -> Dictionary:
	return inventory.duplicate()

