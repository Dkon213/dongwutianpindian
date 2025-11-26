extends Area2D

var tile_textures : Array = [] # 表达砖块纹理的数组
@onready var tile_size: Vector2 = get_node("CollisionShape2D").get_position() * 2 #  声明一个变量，该变量赋值的是碰撞体的长和宽（中心点坐标*2） 
@onready var sprite: Sprite2D = get_node("Sprite2D") # 声明一个变量，用来装sprite2D节点

signal tile_selected(tile)

func _ready():
	
	sprite.centered = false # 让砖块纹理不要剧中对其，以左上角为0,0坐标
	
	# 给砖块纹理数组加载5种不同的纹理，分别加载到tile_textures这个数组里
	tile_textures.append(preload( "res://assets/Match_three_game/blue.png"))
	tile_textures.append(preload( "res://assets/Match_three_game/green.png"))
	tile_textures.append(preload( "res://assets/Match_three_game/red.png"))
	tile_textures.append(preload( "res://assets/Match_three_game/yellow.png"))
	tile_textures.append(preload( "res://assets/Match_three_game/purple.png"))
	
	# 初始化一个随机的颜色
	set_random_texture()

# 每次调用该函数，就会给砖块一个随机纹理
func set_random_texture():
	var random_index = randi() % tile_textures.size() # 生成一个随机整数，其值介于0~数组成员数量之间
	sprite.texture = tile_textures [random_index] # 把数组里面对应这个编号的颜色赋值给sprite2D的纹理选项
	
func selected():
	return
