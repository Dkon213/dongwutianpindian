extends Node2D

signal fruit_spawned(global_pos: Vector2, fruit_type: String)

# 土地状态(NORMAL: 未耕种, TILLED: 已耕种)
enum LandState { 
	NORMAL,
	TILLED,
}

# 生长阶段(NONE: 未种植, SEED: 种子, SPROUT: 幼苗, MATURE: 成熟)
enum GrowthStage { 
	NONE,
	SEED,
	SPROUT,
	MATURE,
}

# 地块类(land_state: 土地状态, plant_type: 植物类型, growth_stage: 生长阶段)
class FarmPlot: 
	var land_state: int
	var plant_type: String       
	var growth_stage: int

	func _init() -> void: # 初始化地块
		land_state = LandState.NORMAL
		plant_type = ""
		growth_stage = GrowthStage.NONE

const GRID_WIDTH := 41 # 地块宽度		
const MIN_X := 0 # 地块最小X坐标
const MAX_X := GRID_WIDTH - 1 # 地块最大X坐标
const LAND_Y := 0 # 土地行Y坐标
const PLANT_Y := -1 # 植物行Y坐标

const LAND_SOURCE_ID := 0 # 土地行TileMap图层ID

# 引用节点
@onready var _container: PanelContainer = $farming_tile_map_container
@onready var _tile_map: TileMapLayer = $farming_tile_map_container/farming_tile_map
@onready var _pot_controller: Node = $"../pot"
@onready var _hoe_controller: Node = $"../hoe"
@onready var _barn: Node2D = $"../barn"
@onready var _watering_icons_container: Node2D = $watering_ready_icons

var _plots: Array[FarmPlot] = [] # 地块数组
var _money_system: Node = null # 根节点下的金币系统

# 浇水冷却时长（秒），冷却结束后显示可浇水图标
@export var water_cooldown_duration: float = 5.0
# 刚播种后延迟（秒），延迟结束后显示可浇水图标提示玩家浇水
@export var seed_planted_watering_icon_delay: float = 0.5

# 果实飞向谷仓的吸入动画时长（秒）
@export var collect_fly_duration: float = 0.4

# 上一帧鼠标所在的果实（用于 _process 中“进入”检测，避免重复触发）
var _last_fruit_under_mouse: Node = null
# 上一帧鼠标位置（用于果实收获的路径采样，快速划过高覆盖）
var _last_mouse_pos_for_fruit: Vector2 = Vector2.INF
# 果实收获路径采样步长（像素），越小越不漏果但性能略增
@export var fruit_sweep_sample_step: float = 12.0

# 标记水壶/锄头/种子是否正在跟随鼠标移动
var is_pot_following_mouse: bool = false
var is_hoe_following_mouse: bool = false
var is_seed_following_mouse: bool = false
var following_seed_plant_type: String = ""

# 线段插值拖动：鼠标按住并拖动时，对路径上的所有地块执行操作（锄头/水壶/种子）
var _mouse_held_for_farming: bool = false # 标记鼠标是否按住
var _last_drag_global_pos: Vector2 = Vector2.INF # 上一次拖动时的鼠标位置（用于线段插值）

# 预加载果实场景
const FRUIT_SCENE = preload("res://scenes/field/fruits.tscn")
# 预加载浇水可进行图标场景
const WATERING_ICON_SCENE = preload("res://scenes/field/watering_ready_icon.tscn")
# 预加载金币浮动图标场景
const COIN_PLUS_ICON_SCENE = preload("res://scenes/field/coin_plus_icon.tscn")

# 浇水冷却：正在进行冷却的列（冷却期间不可再次浇水）
var _columns_on_cooldown: Dictionary = {}  # column -> true
# 浇水图标：列号 -> 图标节点
var _column_to_watering_icon: Dictionary = {}
# 可复用的空闲图标池
var _watering_icon_pool: Array = []

#开始函数
func _ready() -> void:
	_init_plots() #先初始化地块
	_refresh_all_tiles() #再刷新所有地块
	# 设置 PanelContainer 不拦截鼠标事件，让事件能传递到 _input 函数
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 连接信号，当果实被收获时自动实例化
	fruit_spawned.connect(_on_fruit_spawned)
	# 预创建浇水图标池
	_init_watering_icon_pool()
	# 获取根节点下的金币系统
	var root := get_parent().get_parent()
	if root != null:
		_money_system = root.get_node_or_null("money_system")

# 当未持工具时，用物理检测鼠标下的果实并触发“吸入”（沿路径采样，避免快速划过漏果）
func _process(_delta: float) -> void:
	if is_pot_following_mouse or is_hoe_following_mouse or is_seed_following_mouse:
		_last_fruit_under_mouse = null
		_last_mouse_pos_for_fruit = get_global_mouse_position()
		return
	if _barn == null:
		return
	var current_pos: Vector2 = get_global_mouse_position()
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var fruits_found: Dictionary = {}  # 用 instance_id 去重
	var start_pos: Vector2
	if _last_mouse_pos_for_fruit.is_finite():
		start_pos = _last_mouse_pos_for_fruit
	else:
		start_pos = current_pos
	var dist: float = start_pos.distance_to(current_pos)
	var num_samples: int = maxi(1, int(dist / fruit_sweep_sample_step))
	for i in range(num_samples + 1):
		var t: float = 1.0 if num_samples == 0 else float(i) / float(num_samples)
		var sample_pos: Vector2 = start_pos.lerp(current_pos, t)
		var params: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
		params.position = sample_pos
		params.collide_with_bodies = true
		params.collide_with_areas = false
		var results: Array = space.intersect_point(params)
		for r in results:
			var collider: Node = r["collider"] as Node
			if is_instance_valid(collider) and collider.get_parent() == self:
				var id_val: int = collider.get_instance_id()
				if not fruits_found.has(id_val):
					fruits_found[id_val] = collider
	for fruit in fruits_found.values():
		_on_fruit_mouse_entered(fruit)
	_last_mouse_pos_for_fruit = current_pos


#初始化地块
func _init_plots() -> void:
	_plots.clear() #清空地块数组
	_plots.resize(GRID_WIDTH) #重新分配地块数组大小
	for x in range(GRID_WIDTH): #遍历地块数组
		_plots[x] = FarmPlot.new() #创建地块

#初始化浇水图标池
func _init_watering_icon_pool() -> void:
	if _watering_icons_container == null:
		return
	_watering_icon_pool.clear()
	_column_to_watering_icon.clear()
	for i in range(GRID_WIDTH):
		var icon: Node2D = WATERING_ICON_SCENE.instantiate()
		_watering_icons_container.add_child(icon)
		icon.visible = false
		_watering_icon_pool.append(icon)

#显示浇水图标
func _show_watering_icon(column: int) -> void:
	if _watering_icon_pool.is_empty() or _watering_icons_container == null:
		return
	if _column_to_watering_icon.has(column):
		return
	var icon: Node2D = _watering_icon_pool.pop_back()
	var pos: Vector2 = _get_plant_global_center(column) + Vector2(0, -24)
	icon.global_position = pos
	icon.visible = true
	_column_to_watering_icon[column] = icon

#隐藏浇水图标
func _hide_watering_icon(column: int) -> void:
	if not _column_to_watering_icon.has(column):
		return
	var icon: Node2D = _column_to_watering_icon[column]
	_column_to_watering_icon.erase(column)
	icon.visible = false
	_watering_icon_pool.append(icon)

#开始浇水冷却
func _start_water_cooldown(column: int) -> void:
	_columns_on_cooldown[column] = true
	var timer := get_tree().create_timer(water_cooldown_duration)
	timer.timeout.connect(_on_water_cooldown_ended.bind(column))

#浇水冷却结束
func _on_water_cooldown_ended(column: int) -> void:
	_columns_on_cooldown.erase(column)
	var plot := _plots[column]
	if plot.land_state == LandState.TILLED and plot.growth_stage != GrowthStage.NONE and plot.plant_type != "":
		_show_watering_icon(column)


# 播种后延迟显示浇水图标（刚种下的种子需要等一段时间才提示浇水）
func _start_seed_planted_icon_delay(column: int) -> void:
	var timer := get_tree().create_timer(seed_planted_watering_icon_delay)
	timer.timeout.connect(_on_seed_planted_icon_delay_ended.bind(column))


func _on_seed_planted_icon_delay_ended(column: int) -> void:
	var plot := _plots[column]
	# 仅当种子仍处于 SEED 阶段（尚未被浇水）时显示图标
	if plot.land_state == LandState.TILLED and plot.growth_stage == GrowthStage.SEED and plot.plant_type != "":
		_show_watering_icon(column)


#处理输入事件（使用 _input 而不是 _unhandled_input，因为 PanelContainer 会拦截事件）
func _input(event: InputEvent) -> void:
	# 只有当有工具或种子在跟随鼠标时，才允许处理地块输入
	if not is_pot_following_mouse and not is_hoe_following_mouse and not is_seed_following_mouse:
		return

	# 处理鼠标移动：按住左键拖动时，对路径上的所有地块执行线段插值操作（锄头/水壶/种子）
	var motion_event := event as InputEventMouseMotion
	if motion_event != null:
		if _mouse_held_for_farming and (motion_event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			var current_pos: Vector2 = motion_event.global_position
			if _last_drag_global_pos.is_finite():
				var affected := _do_farming_action_along_line(_last_drag_global_pos, current_pos)
				if affected > 0:
					_play_tool_animation()
			_last_drag_global_pos = current_pos
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	# 左键松开：停止拖动
	if not mouse_event.pressed:
		_mouse_held_for_farming = false
		_last_drag_global_pos = Vector2.INF
		return

	# 左键按下：在当前鼠标位置执行一次操作，并记录位置供拖动线段插值使用
	if not _do_farming_action_at_mouse():
		return
	get_viewport().set_input_as_handled()
	_mouse_held_for_farming = true
	_last_drag_global_pos = get_global_mouse_position()


# 在当前鼠标位置执行一次浇水（pot）或耕地（hoe），若位置无效则返回 false
func _do_farming_action_at_mouse() -> bool:
	var global_pos: Vector2 = get_global_mouse_position() # 获取鼠标全局位置
	var rect := _container.get_global_rect()
	if not rect.has_point(global_pos):
		return false # 如果鼠标位置不在地块范围内，则返回false

	# 根据当前跟随的工具播放使用动画（种子无动画）
	_play_tool_animation()

	var local_on_tilemap := _tile_map.to_local(global_pos)
	var cell: Vector2i = _tile_map.local_to_map(local_on_tilemap)
	if cell.x < MIN_X or cell.x > MAX_X or cell.y < PLANT_Y or cell.y > LAND_Y:
		return false # 如果鼠标位置不在地块范围内，则返回false

	_on_column_clicked(cell.x)
	return true # 如果鼠标位置在地块范围内，则返回true


# 使用 Bresenham 线段算法，获取两点间路径所经过的地块列号（含起点终点，去重）
func _get_columns_along_line(global_start: Vector2, global_end: Vector2) -> Array[int]:
	var local_start: Vector2 = _tile_map.to_local(global_start)
	var local_end: Vector2 = _tile_map.to_local(global_end)
	var cell_start: Vector2i = _tile_map.local_to_map(local_start)
	var cell_end: Vector2i = _tile_map.local_to_map(local_end)
	var cols: Array[int] = []
	var x0: int = cell_start.x
	var y0: int = cell_start.y
	var x1: int = cell_end.x
	var y1: int = cell_end.y
	var dx: int = abs(x1 - x0)
	var dy: int = -abs(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	while true:
		if x0 >= MIN_X and x0 <= MAX_X and y0 >= PLANT_Y and y0 <= LAND_Y:
			cols.append(x0)
		if x0 == x1 and y0 == y1:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
	var seen: Dictionary = {}
	var result: Array[int] = []
	for c: int in cols:
		if not seen.has(c):
			seen[c] = true
			result.append(c)
	return result


# 对线段路径上的所有有效地块执行耕作操作，返回受影响的地块数量
func _do_farming_action_along_line(global_start: Vector2, global_end: Vector2) -> int:
	var rect: Rect2 = _container.get_global_rect()
	if not rect.has_point(global_start) and not rect.has_point(global_end):
		return 0
	var columns: Array[int] = _get_columns_along_line(global_start, global_end)
	var count: int = 0
	for col: int in columns:
		if col >= MIN_X and col <= MAX_X:
			_on_column_clicked(col)
			count += 1
	return count


func _play_tool_animation() -> void:
	if is_pot_following_mouse and _pot_controller and _pot_controller.has_method("play_use_animation"):
		_pot_controller.play_use_animation()
	elif is_hoe_following_mouse and _hoe_controller and _hoe_controller.has_method("play_use_animation"):
		_hoe_controller.play_use_animation()


func _on_column_clicked(column: int) -> void:
	if column < MIN_X or column > MAX_X:
		return

	var plot := _plots[column]

	# 当种子跟随鼠标时：在已耕地块上播种
	if is_seed_following_mouse:
		if plot.land_state == LandState.TILLED and plot.growth_stage == GrowthStage.NONE and plot.plant_type == "":
			if CropDB.has_crop(following_seed_plant_type):
				plot.plant_type = following_seed_plant_type
				plot.growth_stage = GrowthStage.SEED
				_start_seed_planted_icon_delay(column)
		_update_column_tiles(column)
		return

	# 当锄头跟随鼠标时：
	# - 只负责耕地：NORMAL → TILLED
	if is_hoe_following_mouse:
		if plot.land_state == LandState.NORMAL and plot.growth_stage == GrowthStage.NONE:
			# 耕地：把 NORMAL 变成 TILLED
			plot.land_state = LandState.TILLED
			# 锄头只负责把地从 NORMAL 变为 TILLED，不处理后续生长

	# 当水壶跟随鼠标时：
	# - 只负责在已耕地的基础上处理：TILLED → SEED → SPROUT → MATURE
	# - 如果再点击 MATURE，则直接结成果实，并把地块重置为 NORMAL & NONE
	# - 浇水有冷却：每次浇水只能成长一步，冷却期间不可再次浇水
	if is_pot_following_mouse:
		# 只有已经被锄头耕过的土地才响应水壶
		if plot.land_state != LandState.TILLED:
			_update_column_tiles(column)
			return

		# 浇水只对有植物的地块生效，不会自动播种
		if plot.growth_stage == GrowthStage.NONE or plot.plant_type == "":
			_update_column_tiles(column)
			return

		# 冷却期间不可浇水（SEED→SPROUT、SPROUT→MATURE、MATURE→收获 均需等待冷却）
		if _columns_on_cooldown.has(column):
			_update_column_tiles(column)
			return

		# 浇水时若该列有可浇水图标，先隐藏
		_hide_watering_icon(column)

		if plot.growth_stage == GrowthStage.SEED:
			# SEED → SPROUT
			plot.growth_stage = GrowthStage.SPROUT
			_start_water_cooldown(column)
		elif plot.growth_stage == GrowthStage.SPROUT:
			# SPROUT → MATURE
			plot.growth_stage = GrowthStage.MATURE
			_start_water_cooldown(column)
		elif plot.growth_stage == GrowthStage.MATURE:
			# MATURE 再次被水壶点击：结出果实并清空该地块，同样进入冷却
			if plot.plant_type != "":
				var plant_global_pos := _get_plant_global_center(column)
				fruit_spawned.emit(plant_global_pos, plot.plant_type)

			plot.plant_type = ""
			plot.growth_stage = GrowthStage.NONE
			plot.land_state = LandState.NORMAL
			_start_water_cooldown(column)

	_update_column_tiles(column)


func set_pot_following_mouse(value: bool) -> void:
	is_pot_following_mouse = value


func set_hoe_following_mouse(value: bool) -> void:
	is_hoe_following_mouse = value


func set_seed_following_mouse(following: bool, plant_type: String = "") -> void:
	is_seed_following_mouse = following
	following_seed_plant_type = plant_type


func _get_plant_global_center(column: int) -> Vector2:
	var cell_coords := Vector2i(column, PLANT_Y)
	var local_center: Vector2 = _tile_map.map_to_local(cell_coords)
	return _tile_map.to_global(local_center)


func _refresh_all_tiles() -> void:
	for x in range(GRID_WIDTH):
		_update_column_tiles(x)


func _update_column_tiles(column: int) -> void:
	var plot := _plots[column]

	# 刷新土地行 (y = 0)
	var land_atlas_coords := Vector2i.ZERO
	match plot.land_state:
		LandState.NORMAL:
			land_atlas_coords = Vector2i(0, 0)
		LandState.TILLED:
			land_atlas_coords = Vector2i(1, 0)
		_:
			land_atlas_coords = Vector2i(0, 0)

	_tile_map.set_cell(Vector2i(column, LAND_Y), LAND_SOURCE_ID, land_atlas_coords)

	# 刷新植物行 (y = -1)
	var plant_coords := Vector2i(column, PLANT_Y)

	if plot.growth_stage == GrowthStage.NONE or plot.plant_type == "":
		# 清空植物格子
		_tile_map.set_cell(plant_coords, -1)
		return

	if not CropDB.has_crop(plot.plant_type):
		# 未知植物类型，安全起见直接清空
		_tile_map.set_cell(plant_coords, -1)
		return

	var source_id: int = CropDB.get_tile_source_id(plot.plant_type)
	var atlas_coords := Vector2i.ZERO

	match plot.growth_stage: # 根据生长阶段设置植物行TileMap图层ID
		GrowthStage.SEED: 
			atlas_coords = Vector2i(0, 0) # 种子TileMap图层ID
		GrowthStage.SPROUT: 
			atlas_coords = Vector2i(2, 0) # 幼苗TileMap图层ID
		GrowthStage.MATURE:
			atlas_coords = Vector2i(7, 0) # 成熟TileMap图层ID
		_:
			# 兜底：清空
			_tile_map.set_cell(plant_coords, -1)
			return

	_tile_map.set_cell(plant_coords, source_id, atlas_coords)


# 处理果实生成信号
func _on_fruit_spawned(global_pos: Vector2, fruit_type: String) -> void:
	# 实例化果实场景
	var fruit_instance = FRUIT_SCENE.instantiate()
	
	# 设置果实位置（使用全局坐标）
	fruit_instance.global_position = global_pos
	
	# 根据 fruit_type 设置对应的动画，并存储类型供吸入谷仓时使用
	var anim_sprite: AnimatedSprite2D = fruit_instance.get_node("animation_fruits")
	if anim_sprite != null:
		# fruits.tscn 中的动画名称是 "carrot", "tomato", "wheat"
		if anim_sprite.sprite_frames.has_animation(fruit_type):
			anim_sprite.animation = fruit_type
		else:
			# 如果动画不存在，使用默认动画
			print("警告：找不到果实动画类型: ", fruit_type)
	fruit_instance.set_meta("fruit_type", fruit_type)
	
	# 将果实添加到场景树中（添加到 farming_system 节点下）
	add_child(fruit_instance)
	# 鼠标滑过果实时触发“吸入谷仓”（仅在未持工具时生效）
	fruit_instance.mouse_entered.connect(_on_fruit_mouse_entered.bind(fruit_instance))


# 鼠标进入果实：若当前未持工具/种子，则播放飞向谷仓的吸入动画并消失
func _on_fruit_mouse_entered(fruit_node: Node) -> void:
	if is_pot_following_mouse or is_hoe_following_mouse or is_seed_following_mouse:
		return
	if _barn == null:
		return
	# 同一果实只触发一次吸入
	if fruit_node.get_meta("collecting", false):
		return
	fruit_node.set_meta("collecting", true)

	# 冻结物理，避免飞行过程中被重力等影响
	if fruit_node is RigidBody2D:
		fruit_node.freeze = true

	var barn_global_pos: Vector2 = _barn.global_position
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(fruit_node, "global_position", barn_global_pos, collect_fly_duration)
	tween.parallel().tween_property(fruit_node, "scale", Vector2(0.5, 0.5), collect_fly_duration)
	tween.tween_callback(_on_fruit_arrived_at_barn.bind(fruit_node))


# 果实在飞行动画结束后到达谷仓：增加库存、生成金币反馈并移除果实节点
func _on_fruit_arrived_at_barn(fruit_node: Node) -> void:
	var fruit_type: String = fruit_node.get_meta("fruit_type", "")
	if fruit_type != "" and _barn != null and _barn.has_method("add_fruit"):
		_barn.add_fruit(fruit_type)

	# 生成 "+金额" 浮动图标并增加金币（先设置位置再 add_child，确保 _ready 中 tween 使用正确起点）
	var price: int = CropDB.get_fruit_price(fruit_type)
	if price > 0:
		var icon: Node2D = COIN_PLUS_ICON_SCENE.instantiate()
		icon.setup(price)
		icon.global_position = _barn.global_position + Vector2(0, -20)
		var root_node := get_parent().get_parent()
		if root_node != null:
			root_node.add_child(icon)
	if price > 0 and _money_system != null and _money_system.has_method("add_coins"):
		_money_system.add_coins(price)

	fruit_node.queue_free()
