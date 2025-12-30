# 作物脚本
extends Node2D

# 成长阶段枚举
enum GrowthStage {
	SEED,      # 种子
	SPROUT,    # 发芽
	MATURE,    # 成熟
	FRUIT      # 果实
}

# 当前成长阶段
var current_stage: GrowthStage = GrowthStage.SEED
# 种子类型（如 "wheat", "carrot", "tomato"）
var seed_type: String = ""
# 成长进度（浇水次数）
var growth_progress: int = 0
# 当前阶段最小浇水次数（保底机制）
var min_water_count: int = 1
# 当前阶段已浇水次数
var water_count: int = 0
# 所属的 TileMap 格子坐标
var tile_coord: Vector2i = Vector2i.ZERO
# 果实拾取区域
var fruit_pickup_area: Area2D = null

# 信号
signal stage_changed(new_stage: GrowthStage)
signal fruit_ready()
signal fruit_picked()

# 节点引用
var anim_sprite: AnimatedSprite2D = null
var pickup_area: Area2D = null

func _ready() -> void:
	# 获取节点引用
	anim_sprite = get_node_or_null("AnimatedSprite2D")
	pickup_area = get_node_or_null("Area2D")
	
	# 初始化，设置初始状态
	if anim_sprite:
		update_sprite()
	
	# 连接拾取区域信号
	if pickup_area:
		pickup_area.body_entered.connect(_on_fruit_area_entered)
		pickup_area.area_entered.connect(_on_fruit_area_entered)
		# 初始时禁用拾取区域（只有果实阶段才启用）
		pickup_area.monitoring = false
		pickup_area.monitorable = false

# 执行浇水操作，有概率进入下一阶段
func water() -> void:
	water_count += 1
	
	# 获取种子配置
	var seed_data = SeedData.SEED_TYPES.get(seed_type, {})
	if seed_data.is_empty():
		return
	
	# 获取当前阶段的最小浇水次数
	var stage_name = _get_stage_name(current_stage)
	var min_water_per_stage = seed_data.get("min_water_per_stage", {})
	min_water_count = min_water_per_stage.get(stage_name, 1)
	
	# 保底机制：达到最小浇水次数后，每次浇水都有概率成长
	if water_count >= min_water_count:
		var growth_chance = seed_data.get("growth_chance", 0.3)
		if randf() < growth_chance:
			advance_stage()

# 进入下一成长阶段
func advance_stage() -> void:
	match current_stage:
		GrowthStage.SEED:
			current_stage = GrowthStage.SPROUT
			water_count = 0  # 重置浇水计数
		GrowthStage.SPROUT:
			current_stage = GrowthStage.MATURE
			water_count = 0
		GrowthStage.MATURE:
			current_stage = GrowthStage.FRUIT
			water_count = 0
			# 果实阶段启用拾取区域
			if pickup_area:
				pickup_area.monitoring = true
				pickup_area.monitorable = true
			fruit_ready.emit()
		GrowthStage.FRUIT:
			# 已经是果实阶段，不再成长
			return
	
	# 更新视觉状态
	update_sprite()
	stage_changed.emit(current_stage)

# 更新精灵显示
func update_sprite() -> void:
	if not anim_sprite:
		return
	
	var seed_data = SeedData.SEED_TYPES.get(seed_type, {})
	if seed_data.is_empty():
		return
	
	var stages = seed_data.get("stages", {})
	var stage_name = _get_stage_name(current_stage)
	var stage_data = stages.get(stage_name, {})
	
	var sprite_path = stage_data.get("sprite", "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var texture = load(sprite_path) as Texture2D
		if texture:
			# 如果是 AnimatedSprite2D，可能需要设置帧
			# 这里假设使用静态图片，直接设置 texture
			if anim_sprite.sprite_frames:
				# 如果有动画帧，可以在这里处理
				pass
			else:
				# 如果没有动画帧，可能需要使用 Sprite2D 而不是 AnimatedSprite2D
				# 这里先保持 AnimatedSprite2D 的结构
				pass

# 检测鼠标进入果实区域
func _on_fruit_area_entered(area_or_body: Node) -> void:
	# 检查是否是鼠标相关的区域（可以通过 Area2D 的鼠标检测）
	if current_stage == GrowthStage.FRUIT:
		# 延迟一帧执行，确保检测稳定
		call_deferred("pickup_fruit")

# 拾取果实，发送到仓库
func pickup_fruit() -> void:
	if current_stage != GrowthStage.FRUIT:
		return
	
	# 获取仓库节点（通过父节点查找）
	var warehouse = get_tree().get_first_node_in_group("warehouse")
	if not warehouse:
		# 如果找不到，尝试通过 FarmingSystem 获取
		var farming_system = get_tree().get_first_node_in_group("farming_system")
		if farming_system and farming_system.has_method("get_warehouse"):
			warehouse = farming_system.get_warehouse()
	
	if warehouse and warehouse.has_method("add_fruit"):
		warehouse.add_fruit(seed_type, 1)
	
	fruit_picked.emit()
	
	# 通知 FarmingSystem 移除这个作物
	var farming_system = get_tree().get_first_node_in_group("farming_system")
	if farming_system and farming_system.has_method("remove_crop_at_tile"):
		farming_system.remove_crop_at_tile(tile_coord)
	
	# 销毁作物节点
	queue_free()

# 获取阶段名称字符串
func _get_stage_name(stage: GrowthStage) -> String:
	match stage:
		GrowthStage.SEED:
			return "seed"
		GrowthStage.SPROUT:
			return "sprout"
		GrowthStage.MATURE:
			return "mature"
		GrowthStage.FRUIT:
			return "fruit"
		_:
			return "seed"

