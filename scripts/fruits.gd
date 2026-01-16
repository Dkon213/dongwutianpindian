extends RigidBody2D

# 初始速度参数（可在编辑器中调整）
@export var upward_velocity: float = 200.0  # 向上速度（像素/秒）
@export var horizontal_random_range: float = 100.0  # 左右随机偏移范围（像素/秒）

func _ready() -> void:
	# 锁定旋转，确保果实不会旋转
	lock_rotation = false
	
	# 设置初始速度：向上 + 随机左右偏移
	var horizontal_velocity = randf_range(-horizontal_random_range, horizontal_random_range)
	var initial_velocity = Vector2(horizontal_velocity, -upward_velocity)
	
	# 设置 RigidBody2D 的线性速度
	linear_velocity = initial_velocity
