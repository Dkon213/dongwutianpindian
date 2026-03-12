extends Node2D

## 收获果实时显示的 "+金额" 浮动图标，播放动画并缓慢上移，动画结束后自动删除。

@onready var _coin_anime: AnimatedSprite2D = $coin_anime
@onready var _price_label: Label = $HBoxContainer/price

## 上移距离（像素）
@export var float_up_distance: float = 80.0
## 上移时长（秒）
@export var float_duration: float = 0.8


# 金额
var _amount: int = 0

# 设置金额
func setup(amount: int) -> void:
	_amount = amount
	if _price_label != null:
		_price_label.text = str(amount)
	elif is_node_ready():
		_price_label = $HBoxContainer/price
		if _price_label:
			_price_label.text = str(amount)

# 初始化
func _ready() -> void:
	# 若在 add_child 之前已调用 setup，则此时 _price_label 可能已有值，否则需要在 ready 时再设置一次
	if _amount > 0 and _price_label:
		_price_label.text = str(_amount)

	if _coin_anime != null:
		_coin_anime.play("default")
		_coin_anime.animation_finished.connect(_on_animation_finished)

	# 延后一帧启动 tween，确保 add_child 后的位置已完全应用
	call_deferred("_start_float_tween")


func _start_float_tween() -> void:
	if not is_instance_valid(self):
		return
	var start := global_position
	var target := Vector2(start.x, start.y - float_up_distance)
	var tween := create_tween()
	tween.tween_property(self, "global_position", target, float_duration)
	tween.set_ease(Tween.EASE_OUT)


func _on_animation_finished() -> void:
	queue_free()
