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

var _plots: Array[FarmPlot] = []

# 标记水壶/锄头是否正在跟随鼠标移动
var is_pot_following_mouse: bool = false
var is_hoe_following_mouse: bool = false

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
	# 注意：_input 函数不需要 set_process_unhandled_input，它会自动被调用

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

	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	# 在 Godot 4 中，mouse_event.position 是画布坐标，需要转换为全局坐标
	# 使用 get_global_mouse_position() 获取全局鼠标位置
	var global_pos: Vector2 = get_global_mouse_position()

	# 限制在 PanelContainer 的可见范围内
	var rect := _container.get_global_rect()
	if not rect.has_point(global_pos):
		return

	# 将全局坐标转换为 TileMapLayer 的本地坐标，再转换为网格坐标
	var local_on_tilemap := _tile_map.to_local(global_pos)
	var cell: Vector2i = _tile_map.local_to_map(local_on_tilemap)


	# 检查网格坐标是否在有效范围内
	if cell.x < MIN_X or cell.x > MAX_X:
		return
	if cell.y < PLANT_Y or cell.y > LAND_Y:
		return

	# 只有在有效范围内才标记事件已处理，防止被其他节点处理（比如角色移动）
	get_viewport().set_input_as_handled()
	_on_column_clicked(cell.x)


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
