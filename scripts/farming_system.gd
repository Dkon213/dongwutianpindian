extends Node2D

signal fruit_spawned(global_pos: Vector2, fruit_type: String)

enum LandState {
	NORMAL,
	TILLED,
}

enum GrowthStage {
	NONE,
	SEED,
	SPROUT,
	MATURE,
}

class FarmPlot:
	var land_state: int
	var plant_type: String       
	var growth_stage: int

	func _init() -> void:
		land_state = LandState.NORMAL
		plant_type = ""
		growth_stage = GrowthStage.NONE

const GRID_WIDTH := 41
const MIN_X := 0
const MAX_X := GRID_WIDTH - 1
const LAND_Y := 0
const PLANT_Y := -1

const LAND_SOURCE_ID := 0

const PlantDB := {
	"carrot": 1,
	"tomato": 2,
	"wheat": 3,
}

@onready var _container: PanelContainer = $farming_tile_map_container
@onready var _tile_map: TileMapLayer = $farming_tile_map_container/farming_tile_map
@onready var _pot_controller: Node = $"../pot"
@onready var _hoe_controller: Node = $"../hoe"
@onready var _barn: Node2D = $"../barn"

var _plots: Array[FarmPlot] = []

# 果实飞向谷仓的吸入动画时长（秒）
@export var collect_fly_duration: float = 0.4

# 上一帧鼠标所在的果实（用于 _process 中“进入”检测，避免重复触发）
var _last_fruit_under_mouse: Node = null

# 标记水壶/锄头是否正在跟随鼠标移动
var is_pot_following_mouse: bool = false
var is_hoe_following_mouse: bool = false

# 长按重复：鼠标按住时每隔该秒数执行一次浇水/耕地
var _mouse_held_for_farming: bool = false # 标记鼠标是否按住
var _hold_repeat_timer: Timer # 长按重复计时器
@export var hold_repeat_interval: float = 0.2 # hoe和pot长按状态下执行浇水/耕地操作的间隔时间（秒）

# 预加载果实场景
const FRUIT_SCENE = preload("res://scenes/fruits.tscn")

#开始函数
func _ready() -> void:
	_init_plots() #先初始化地块
	_refresh_all_tiles() #再刷新所有地块
	# 设置 PanelContainer 不拦截鼠标事件，让事件能传递到 _input 函数
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 连接信号，当果实被收获时自动实例化
	fruit_spawned.connect(_on_fruit_spawned)

	# 长按重复计时器：单次 0.5 秒，超时后执行一次操作并再次启动
	_hold_repeat_timer = Timer.new() #创建计时器
	_hold_repeat_timer.one_shot = true #单次模式
	_hold_repeat_timer.wait_time = hold_repeat_interval #设置间隔时间
	_hold_repeat_timer.timeout.connect(_on_hold_repeat_timeout) #连接超时信号
	add_child(_hold_repeat_timer) #添加到场景树

# 当未持工具时，用物理检测鼠标下的果实并触发“吸入”（解决 Control 遮挡导致 mouse_entered 不触发的问题）
func _process(_delta: float) -> void:
	if is_pot_following_mouse or is_hoe_following_mouse:
		_last_fruit_under_mouse = null
		return
	if _barn == null:
		return
	var params := PhysicsPointQueryParameters2D.new()
	params.position = get_global_mouse_position()
	params.collide_with_bodies = true
	params.collide_with_areas = false
	var space := get_world_2d().direct_space_state
	var results := space.intersect_point(params)
	var fruit_under_mouse: Node = null
	for r in results:
		var collider = r["collider"]
		if is_instance_valid(collider) and collider.get_parent() == self:
			fruit_under_mouse = collider
			break
	if fruit_under_mouse != null and fruit_under_mouse != _last_fruit_under_mouse:
		_on_fruit_mouse_entered(fruit_under_mouse)
	_last_fruit_under_mouse = fruit_under_mouse


#初始化地块
func _init_plots() -> void:
	_plots.clear() #清空地块数组
	_plots.resize(GRID_WIDTH) #重新分配地块数组大小
	for x in range(GRID_WIDTH): #遍历地块数组
		_plots[x] = FarmPlot.new() #创建地块

#处理输入事件（使用 _input 而不是 _unhandled_input，因为 PanelContainer 会拦截事件）
func _input(event: InputEvent) -> void:
	# 只有当有工具在跟随鼠标时，才允许处理地块输入
	if not is_pot_following_mouse and not is_hoe_following_mouse:
		return

	var mouse_event := event as InputEventMouseButton # 把事件转换为鼠标按钮事件
	if mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT: # 如果事件为空或者按钮不是左键，则返回
		return

	# 左键松开：停止长按重复
	if not mouse_event.pressed:
		_mouse_held_for_farming = false # 停止长按重复
		_hold_repeat_timer.stop() # 停止计时器
		return

	# 左键按下：在当前鼠标位置执行一次浇水/耕地，并开启长按每 0.5 秒重复
	if not _do_farming_action_at_mouse(): # 如果执行失败，则返回
		return
	get_viewport().set_input_as_handled() # 设置输入为已处理
	_mouse_held_for_farming = true # 开启长按重复
	_hold_repeat_timer.start(hold_repeat_interval) # 启动计时器


# 在当前鼠标位置执行一次浇水（pot）或耕地（hoe），若位置无效则返回 false
func _do_farming_action_at_mouse() -> bool:
	var global_pos: Vector2 = get_global_mouse_position() # 获取鼠标全局位置
	var rect := _container.get_global_rect()
	if not rect.has_point(global_pos):
		return false # 如果鼠标位置不在地块范围内，则返回false

	# 根据当前跟随的工具播放使用动画
	if is_pot_following_mouse and _pot_controller and _pot_controller.has_method("play_use_animation"):
		_pot_controller.play_use_animation()
	elif is_hoe_following_mouse and _hoe_controller and _hoe_controller.has_method("play_use_animation"):
		_hoe_controller.play_use_animation()

	var local_on_tilemap := _tile_map.to_local(global_pos)
	var cell: Vector2i = _tile_map.local_to_map(local_on_tilemap)
	if cell.x < MIN_X or cell.x > MAX_X or cell.y < PLANT_Y or cell.y > LAND_Y:
		return false # 如果鼠标位置不在地块范围内，则返回false

	_on_column_clicked(cell.x)
	return true # 如果鼠标位置在地块范围内，则返回true


func _on_hold_repeat_timeout() -> void:
	if not _mouse_held_for_farming: # 如果鼠标没有按住，则返回
		return
	# 长按期间仍用当前鼠标位置执行一次操作
	_do_farming_action_at_mouse()
	_hold_repeat_timer.start(hold_repeat_interval)


func _on_column_clicked(column: int) -> void:
	if column < MIN_X or column > MAX_X:
		return

	var plot := _plots[column]

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
	if is_pot_following_mouse:
		# 只有已经被锄头耕过的土地才响应水壶
		if plot.land_state != LandState.TILLED:
			_update_column_tiles(column)
			return

		if plot.growth_stage == GrowthStage.NONE:
			# 第一次浇水：播种 + 变为 SEED（默认 carrot）
			plot.plant_type = "carrot"
			plot.growth_stage = GrowthStage.SEED
		elif plot.growth_stage == GrowthStage.SEED:
			# SEED → SPROUT
			plot.growth_stage = GrowthStage.SPROUT
		elif plot.growth_stage == GrowthStage.SPROUT:
			# SPROUT → MATURE
			plot.growth_stage = GrowthStage.MATURE
		elif plot.growth_stage == GrowthStage.MATURE:
			# MATURE 再次被水壶点击：直接结出果实并清空该地块
			if plot.plant_type != "":
				var plant_global_pos := _get_plant_global_center(column)
				fruit_spawned.emit(plant_global_pos, plot.plant_type)

			plot.plant_type = ""
			plot.growth_stage = GrowthStage.NONE
			plot.land_state = LandState.NORMAL

	_update_column_tiles(column)


func set_pot_following_mouse(value: bool) -> void:
	is_pot_following_mouse = value


func set_hoe_following_mouse(value: bool) -> void:
	is_hoe_following_mouse = value


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

	if not PlantDB.has(plot.plant_type):
		# 未知植物类型，安全起见直接清空
		_tile_map.set_cell(plant_coords, -1)
		return

	var source_id: int = PlantDB[plot.plant_type]
	var atlas_coords := Vector2i.ZERO

	match plot.growth_stage:
		GrowthStage.SEED:
			atlas_coords = Vector2i(0, 0)
		GrowthStage.SPROUT:
			atlas_coords = Vector2i(2, 0)
		GrowthStage.MATURE:
			atlas_coords = Vector2i(7, 0)
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
	
	# 根据 fruit_type 设置对应的动画
	var anim_sprite: AnimatedSprite2D = fruit_instance.get_node("animation_fruits")
	if anim_sprite != null:
		# fruits.tscn 中的动画名称是 "carrot", "tomato", "wheat"
		if anim_sprite.sprite_frames.has_animation(fruit_type):
			anim_sprite.animation = fruit_type
		else:
			# 如果动画不存在，使用默认动画
			print("警告：找不到果实动画类型: ", fruit_type)
	
	# 将果实添加到场景树中（添加到 farming_system 节点下）
	add_child(fruit_instance)
	# 鼠标滑过果实时触发“吸入谷仓”（仅在未持工具时生效）
	fruit_instance.mouse_entered.connect(_on_fruit_mouse_entered.bind(fruit_instance))


# 鼠标进入果实：若当前未持工具，则播放飞向谷仓的吸入动画并消失
func _on_fruit_mouse_entered(fruit_node: Node) -> void:
	if is_pot_following_mouse or is_hoe_following_mouse:
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
	tween.tween_callback(fruit_node.queue_free)
