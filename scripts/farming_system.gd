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


func _ready() -> void:
	_init_plots()
	_refresh_all_tiles()
	set_process_unhandled_input(true)


func _init_plots() -> void:
	_plots.clear()
	_plots.resize(GRID_WIDTH)
	for x in range(GRID_WIDTH):
		_plots[x] = FarmPlot.new()


func _unhandled_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	var global_pos: Vector2 = mouse_event.position

	# 限制在 PanelContainer 的可见范围内
	var rect := _container.get_global_rect()
	if not rect.has_point(global_pos):
		return

	var local_on_tilemap := _tile_map.to_local(global_pos)
	var cell: Vector2i = _tile_map.local_to_map(local_on_tilemap)

	if cell.x < MIN_X or cell.x > MAX_X:
		return
	if cell.y < PLANT_Y or cell.y > LAND_Y:
		return

	_on_column_clicked(cell.x)


func _on_column_clicked(column: int) -> void:
	if column < MIN_X or column > MAX_X:
		return

	var plot := _plots[column]

	# 状态机：NORMAL → TILLED → SEED → SPROUT → MATURE → 收获并清空
	if plot.land_state == LandState.NORMAL and plot.growth_stage == GrowthStage.NONE:
		plot.land_state = LandState.TILLED
	elif plot.land_state == LandState.TILLED and plot.growth_stage == GrowthStage.NONE:
		# 目前只默认种 carrot
		plot.plant_type = "carrot"
		plot.growth_stage = GrowthStage.SEED
	elif plot.growth_stage == GrowthStage.SEED:
		plot.growth_stage = GrowthStage.SPROUT
	elif plot.growth_stage == GrowthStage.SPROUT:
		plot.growth_stage = GrowthStage.MATURE
	elif plot.growth_stage == GrowthStage.MATURE:
		# 收获
		if plot.plant_type != "":
			var plant_global_pos := _get_plant_global_center(column)
			fruit_spawned.emit(plant_global_pos, plot.plant_type)

		# 重置为无植物 & 普通土地
		plot.plant_type = ""
		plot.growth_stage = GrowthStage.NONE
		plot.land_state = LandState.NORMAL

	_update_column_tiles(column)


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

