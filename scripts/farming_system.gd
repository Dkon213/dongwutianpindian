# 种植系统管理器脚本
extends Node2D

# 节点引用
var farmland_layer: TileMapLayer  # TileMapLayer 节点引用
var crop_manager: Node2D  # 作物管理器节点
var warehouse: Node2D  # 仓库节点引用
var ji_chi_node: CharacterBody2D  # ji_chi 角色引用

# 系统状态
var watering_tool_available: bool = false  # 是否持有浇水工具
var player_idle_timer: Timer  # 玩家无操作计时器
var player_idle_timeout: float = 10.0  # 无操作超时时间（秒）

# 地块状态管理：使用字典存储每个格子坐标对应的作物
var farmland_crops: Dictionary = {}  # {Vector2i(格子坐标): Crop节点}
var tile_size: Vector2i  # TileMapLayer 的格子大小
var farmland_row: int  # 可种植区域所在的行（地图底部）

# 当前选中的种子类型（用于玩家播种）
var selected_seed_type: String = "wheat"

# 自动行为相关
var auto_behavior_active: bool = false
var current_auto_task: String = ""  # "planting", "watering", "picking"
var auto_task_queue: Array = []  # 任务队列

# 场景资源
const CropScene = preload("res://scenes/crop.tscn")
const SeedData = preload("res://scripts/seed_data.gd")

func _ready() -> void:
	# 添加到组，方便其他节点查找
	add_to_group("farming_system")
	
	# 获取节点引用
	farmland_layer = $FarmlandTileMapLayer
	
	# 获取 TileSet 的格子大小
	if farmland_layer.tile_set:
		var source_count = farmland_layer.tile_set.get_source_count()
		if source_count > 0:
			var source_id = farmland_layer.tile_set.get_source_id(0)
			var source = farmland_layer.tile_set.get_source(source_id)
			if source:
				# 尝试获取纹理区域大小
				if source.has_method("get_texture_region_size"):
					tile_size = source.get_texture_region_size()
				elif "texture_region_size" in source:
					tile_size = source.texture_region_size
				else:
					# 尝试从纹理获取
					if source.has_method("get_texture"):
						var texture = source.get_texture()
						if texture:
							tile_size = Vector2i(texture.get_width(), texture.get_height())
	
	# 如果无法从 TileSet 获取，使用默认值
	if tile_size == Vector2i.ZERO:
		tile_size = Vector2i(64, 64)  # 默认格子大小
	
	# 获取作物管理器
	crop_manager = $CropManager
	
	# 获取仓库节点（可能在父节点）
	warehouse = get_node_or_null("../Warehouse")
	if not warehouse:
		# 尝试通过组查找
		warehouse = get_tree().get_first_node_in_group("warehouse")
	
	# 初始化玩家无操作计时器
	player_idle_timer = Timer.new()
	player_idle_timer.wait_time = player_idle_timeout
	player_idle_timer.one_shot = false
	player_idle_timer.timeout.connect(_on_player_idle_timeout)
	add_child(player_idle_timer)
	player_idle_timer.start()
	
	# 生成底部一行的可种植格子
	_generate_farmland_layer()
	
	# 查找 ji_chi 节点（可能在根节点下）
	_find_ji_chi_node()

# 生成可种植区域图层
func _generate_farmland_layer() -> void:
	# 计算地图底部一行的Y坐标（根据视口高度和地图布局）
	var viewport_height = ProjectSettings.get_setting("display/window/size/viewport_height")
	var viewport_width = ProjectSettings.get_setting("display/window/size/viewport_width")
	
	# 计算底部一行的格子坐标
	# 假设地图从 (0, 0) 开始，底部一行应该是 viewport_height - tile_size.y 附近
	farmland_row = int((viewport_height - tile_size.y) / tile_size.y)
	
	# 生成底部一行的可种植格子
	var tile_count_x = int(viewport_width / tile_size.x) + 1  # 多生成一个确保覆盖
	
	for x in range(tile_count_x):
		var tile_coord = Vector2i(x, farmland_row)
		# 设置一个图块来标识可种植区域
		# 使用 source_id=0, atlas_coords=Vector2i(0,0) 作为占位符
		farmland_layer.set_cell(tile_coord, 0, Vector2i(0, 0))

# 查找 ji_chi 节点
func _find_ji_chi_node() -> void:
	# 尝试多种方式查找 ji_chi
	var root = get_tree().root
	ji_chi_node = _find_node_recursive(root, "JiChi")
	
	if not ji_chi_node:
		# 尝试通过场景路径查找（可能在根节点下）
		var root_node = get_tree().root.get_child(0)  # 通常是主场景
		if root_node:
			ji_chi_node = _find_node_recursive(root_node, "JiChi")
	
	if not ji_chi_node:
		# 尝试通过组查找
		ji_chi_node = get_tree().get_first_node_in_group("ji_chi")
	
	# 如果还是找不到，延迟查找（可能在场景加载后）
	if not ji_chi_node:
		await get_tree().process_frame
		ji_chi_node = _find_node_recursive(get_tree().root, "JiChi")

# 递归查找节点
func _find_node_recursive(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	
	for child in node.get_children():
		var result = _find_node_recursive(child, node_name)
		if result:
			return result
	
	return null

# 检测鼠标点击
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 重置玩家无操作计时器
		if player_idle_timer:
			player_idle_timer.start()
		
		var world_pos = get_global_mouse_position()
		var tile_coord = _get_farmland_tile_coord(world_pos)
		
		if _is_valid_farmland(tile_coord):
			_on_farmland_clicked(tile_coord, world_pos)

# 将世界坐标转换为 TileMapLayer 格子坐标
func _get_farmland_tile_coord(world_pos: Vector2) -> Vector2i:
	# 将世界坐标转换为 TileMapLayer 的本地坐标
	var local_pos = farmland_layer.to_local(world_pos)
	# 转换为格子坐标
	return farmland_layer.local_to_map(local_pos)

# 判断格子坐标是否为有效的可种植区域
func _is_valid_farmland(tile_coord: Vector2i) -> bool:
	# 检查是否为底部一行
	if tile_coord.y != farmland_row:
		return false
	# 检查该格子是否在 TileMapLayer 中存在
	return farmland_layer.get_cell_source_id(tile_coord) != -1

# 处理可种植区域点击
func _on_farmland_clicked(tile_coord: Vector2i, _world_pos: Vector2) -> void:
	# 检查该格子是否已种植
	if farmland_crops.has(tile_coord):
		# 已种植，尝试浇水
		var crop = farmland_crops[tile_coord]
		if crop and is_instance_valid(crop):
			# 检查是否可以浇水
			if crop.current_stage != crop.GrowthStage.FRUIT:
				if watering_tool_available:
					water_crop_at_tile(tile_coord)
	else:
		# 未种植，尝试播种
		plant_seed_at_tile(tile_coord, selected_seed_type)

# 在指定格子播种
func plant_seed_at_tile(tile_coord: Vector2i, seed_type: String) -> void:
	# 检查是否已种植
	if farmland_crops.has(tile_coord):
		return
	
	# 创建作物实例
	var crop = CropScene.instantiate()
	if not crop:
		return
	
	# 设置作物属性
	crop.seed_type = seed_type
	crop.tile_coord = tile_coord
	crop.current_stage = crop.GrowthStage.SEED
	
	# 将作物添加到作物管理器
	crop_manager.add_child(crop)
	
	# 设置作物位置（格子中心）
	var local_pos = farmland_layer.map_to_local(tile_coord)
	var world_pos = farmland_layer.to_global(local_pos)
	crop.global_position = world_pos
	
	# 记录到字典
	farmland_crops[tile_coord] = crop
	
	# 连接信号
	crop.fruit_picked.connect(_on_crop_fruit_picked.bind(tile_coord))

# 在指定格子浇水
func water_crop_at_tile(tile_coord: Vector2i) -> void:
	if not farmland_crops.has(tile_coord):
		return
	
	var crop = farmland_crops[tile_coord]
	if not crop or not is_instance_valid(crop):
		# 清理无效引用
		farmland_crops.erase(tile_coord)
		return
	
	# 检查是否可以浇水
	if crop.current_stage == crop.GrowthStage.FRUIT:
		return
	
	# 执行浇水
	crop.water()

# 移除指定格子的作物
func remove_crop_at_tile(tile_coord: Vector2i) -> void:
	if farmland_crops.has(tile_coord):
		farmland_crops.erase(tile_coord)

# 作物果实被拾取的回调
func _on_crop_fruit_picked(tile_coord: Vector2i) -> void:
	# 作物节点会在 pickup_fruit 中自行销毁
	# 这里只需要清理字典引用
	remove_crop_at_tile(tile_coord)

# 获取所有未种植的格子坐标
func get_all_empty_tiles() -> Array[Vector2i]:
	var empty_tiles: Array[Vector2i] = []
	var used_cells = farmland_layer.get_used_cells()
	
	for tile_coord in used_cells:
		if not farmland_crops.has(tile_coord):
			empty_tiles.append(tile_coord)
	
	return empty_tiles

# 获取所有需要浇水的格子坐标
func get_all_waterable_tiles() -> Array[Vector2i]:
	var waterable_tiles: Array[Vector2i] = []
	
	for tile_coord in farmland_crops.keys():
		var crop = farmland_crops[tile_coord]
		if crop and is_instance_valid(crop):
			# 需要浇水：SEED、SPROUT、MATURE 阶段
			if crop.current_stage != crop.GrowthStage.FRUIT:
				waterable_tiles.append(tile_coord)
		else:
			# 清理无效引用
			farmland_crops.erase(tile_coord)
	
	return waterable_tiles

# 获取所有有果实的格子坐标
func get_all_fruit_tiles() -> Array[Vector2i]:
	var fruit_tiles: Array[Vector2i] = []
	
	for tile_coord in farmland_crops.keys():
		var crop = farmland_crops[tile_coord]
		if crop and is_instance_valid(crop):
			if crop.current_stage == crop.GrowthStage.FRUIT:
				fruit_tiles.append(tile_coord)
		else:
			# 清理无效引用
			farmland_crops.erase(tile_coord)
	
	return fruit_tiles

# 玩家无操作超时，触发 ji_chi 自动行为
func _on_player_idle_timeout() -> void:
	if not auto_behavior_active:
		start_ji_chi_auto_behavior()

# 启动 ji_chi 自动行为序列
func start_ji_chi_auto_behavior() -> void:
	if not ji_chi_node:
		_find_ji_chi_node()
		if not ji_chi_node:
			return
	
	auto_behavior_active = true
	# 按顺序执行：播种 -> 浇水 -> 拾取
	_execute_auto_planting_phase()

# 执行自动播种阶段
func _execute_auto_planting_phase() -> void:
	current_auto_task = "planting"
	var empty_tiles = get_all_empty_tiles()
	
	if empty_tiles.is_empty():
		# 没有空地块，进入下一阶段
		_execute_auto_watering_phase()
		return
	
	# 执行第一个播种任务
	_execute_next_auto_task(empty_tiles, _auto_plant_at_tile, _execute_auto_watering_phase)

# 执行自动浇水阶段
func _execute_auto_watering_phase() -> void:
	current_auto_task = "watering"
	var waterable_tiles = get_all_waterable_tiles()
	
	if waterable_tiles.is_empty():
		# 没有需要浇水的地块，进入下一阶段
		_execute_auto_picking_phase()
		return
	
	# 执行第一个浇水任务
	_execute_next_auto_task(waterable_tiles, _auto_water_at_tile, _execute_auto_picking_phase)

# 执行自动拾取阶段
func _execute_auto_picking_phase() -> void:
	current_auto_task = "picking"
	var fruit_tiles = get_all_fruit_tiles()
	
	if fruit_tiles.is_empty():
		# 没有果实，完成自动行为
		_finish_auto_behavior()
		return
	
	# 执行第一个拾取任务
	_execute_next_auto_task(fruit_tiles, _auto_pick_at_tile, _finish_auto_behavior)

# 执行下一个自动任务
func _execute_next_auto_task(tiles: Array, action_func: Callable, next_phase_func: Callable) -> void:
	if tiles.is_empty():
		next_phase_func.call()
		return
	
	var tile_coord = tiles[0]
	tiles.remove_at(0)
	
	# 将格子坐标转换为世界坐标
	var local_pos = farmland_layer.map_to_local(tile_coord)
	var world_pos = farmland_layer.to_global(local_pos)
	
	# 设置 ji_chi 移动目标
	ji_chi_node.target_x = world_pos.x
	ji_chi_node.start_move(ji_chi_node.AnimState.WALK_BIG)
	
	# 等待到达后执行操作（通过轮询检测）
	_wait_and_execute(world_pos, action_func.bind(tile_coord), func(): _execute_next_auto_task(tiles, action_func, next_phase_func))

# 等待到达并执行操作
func _wait_and_execute(target_pos: Vector2, action: Callable, next_action: Callable) -> void:
	# 创建一个定时器来轮询检测是否到达
	var check_timer = Timer.new()
	check_timer.wait_time = 0.1  # 每0.1秒检查一次
	check_timer.timeout.connect(_check_arrival.bind(target_pos, action, next_action, check_timer))
	add_child(check_timer)
	check_timer.start()

# 检查是否到达目标位置
func _check_arrival(target_pos: Vector2, action: Callable, next_action: Callable, timer: Timer) -> void:
	if ji_chi_node and abs(ji_chi_node.global_position.x - target_pos.x) < 10.0:
		# 到达目标，执行操作
		action.call()
		# 停止定时器
		timer.stop()
		timer.queue_free()
		# 等待一小段时间后执行下一个任务
		await get_tree().create_timer(0.5).timeout
		next_action.call()

# 自动播种
func _auto_plant_at_tile(tile_coord: Vector2i) -> void:
	var random_seed = SeedData.get_random_seed_type()
	plant_seed_at_tile(tile_coord, random_seed)

# 自动浇水
func _auto_water_at_tile(tile_coord: Vector2i) -> void:
	# 自动行为时，假设有浇水工具
	watering_tool_available = true
	water_crop_at_tile(tile_coord)
	watering_tool_available = false

# 自动拾取
func _auto_pick_at_tile(tile_coord: Vector2i) -> void:
	if farmland_crops.has(tile_coord):
		var crop = farmland_crops[tile_coord]
		if crop and is_instance_valid(crop) and crop.current_stage == crop.GrowthStage.FRUIT:
			crop.pickup_fruit()

# 完成自动行为
func _finish_auto_behavior() -> void:
	auto_behavior_active = false
	current_auto_task = ""
	# 重置玩家无操作计时器
	if player_idle_timer:
		player_idle_timer.start()

# 获取仓库节点（供其他节点调用）
func get_warehouse() -> Node2D:
	return warehouse

