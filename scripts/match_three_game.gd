#临时笔记
#setup_grid函数只加入了网格的初始设置，还没有消除初始匹配




extends Control

# 游戏配置
const MARGIN = 32  # 边距
var game_active = false # 用来表示游戏状态是否激活的变量
var grid = []  # 游戏网格数据
var selected_tile = null  # 当前选中的砖块
@onready var grid_container : GridContainer = $GridContainer # 把GridContainer砖块容器节点赋值给grid_container变量，方便后续调用
@onready var tile_size : Vector2 = get_node("Area2D").tile_size # 把砖块代码里的砖块尺寸数据同步过来
@export var grid_numbers = Vector2i(8, 15)  # 网格的行数和列数，之所以不用直接8，是因为赋值常量后这里可以宏观更改网格设定

func _ready():
	setup_grid()
	start_game()


func start_game():
	game_active = true



# 设置游戏网格
func  setup_grid():
	# 设置网格大小
	grid_container.set_columns(grid_numbers.x	) # #用来设置网格有多少列。GRID_SIZE是(8,8)所以GRID_SIZE.x是8，将其赋值给grid_container节点的columns列数。用【=】或者set赋值都行
	grid_container.set_size(Vector2(grid_numbers.x * tile_size.x + MARGIN * 2, grid_numbers.y * tile_size.y + MARGIN * 2)) # 用来设置网格最小尺寸。横纵方向分别设置为【网格数*砖块尺寸，加上2倍边距】
	
	#用方块来填充设置好的网格
	for y in range(grid_numbers.y):  # 遍历该网格的每一行
		var row = []  # 每一行声明一个row变量，该变量的生命周期仅限该行，因此多行不会冲突
		for x in range(grid_numbers.x):  # 遍历该行的每一列
			var tile = create_tile(x, y) # 由于create_tile函数的返回值是一个砖块节点，因此这里是把该函数返回的砖块赋值给tile变量。另外，这里的tile变量和create_tile函数里的tile变量不冲突
			row.append(tile) # 把这个被赋值后的tile变量加入到row序列里
		grid.append(row) # 把被填充完成的row序列加入到grid序列里，grid是全局变量，所以哪怕循环结束了也仍然有效
	
	
# 创建砖块实例
func create_tile(x: int, y: int): # 该函数会返回一个area2D节点
	var tile = preload("res://scenes/tile.tscn").instantiate() # 声明tile_scene变量，将其实例化，然后把实例化以后的tile场景赋值给它，现在的状态是已具备实例，但还没上台
	tile.position = Vector2(tile_size.x*x, tile_size.y*y) # 确定该实例化砖块加入主场景的位置，前面的tile_size.x是砖块宽度，后面的x是网格坐标
	tile.tile_selected.connect(_on_tile_selected) # tile节点的代码里已经声明过tile_selected信号了，现在把它的信号捆绑到_on_tile_selected(tile)函数
	get_tree().current_scene.add_child.call_deferred(tile) # 把实例化之后的砖块变成主场景的子节点，正式上台了
	return tile

# 处理#砖块选择
func _on_tile_selected(tile):
	return
