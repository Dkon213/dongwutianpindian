extends Node2D
## 金币管理系统：维护游戏全局金币数量并更新 UI 显示。
## 挂载在根节点下的 money_system 节点上，与 map_field 独立。

@export var initial_coins: int = 0

var _coin_count: int = 0

@onready var _money_count_label: Label = $money_panel/money_margin/money_NinePatchRect/money_count


func _ready() -> void:
	_coin_count = initial_coins
	_refresh_display()


## 增加金币并刷新显示
func add_coins(amount: int) -> void:
	_coin_count += amount
	_refresh_display()


## 获取当前金币数量（可用于存档等）
func get_coin_count() -> int:
	return _coin_count


## 设置金币数量（可用于读档等）
func set_coin_count(value: int) -> void:
	_coin_count = maxi(0, value)
	_refresh_display()


func _refresh_display() -> void:
	if _money_count_label != null:
		_money_count_label.text = str(_coin_count)
