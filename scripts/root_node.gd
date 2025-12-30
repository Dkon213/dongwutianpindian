# 该脚本负责游戏整体的宏观管理
extends Node2D

# 全局变量集中声明
	# 管理主窗口的
var screen_width : int # 屏幕宽度变量
var screen_height : int # 屏幕高度变量
var viewport_width : int # 视口宽度
var viewport_height : int # 视口高度
var window_position : Vector2i # 游戏窗口的显示坐标，单位像素

	# 管理菜单的
var menu_show : bool # 菜单移动指令开关
var menu_left : Node  # 左菜单节点
var menu_right : Node # 左菜单节点
#var menu_left_middle_x : Node #左菜单剧中时候的横坐标位置，避免每次都帧运算
#var menu_right_middle_x : Node #右菜单剧中时候的横坐标位置，避免每次都帧运算

func _ready() -> void:
	
	var aspect_ratio : float # 用来表示宽高比的内部变量，主要目的是为了让窗口宽高比和视口保持一致，后面会用到
	
	# 【独立功能，不涉及外部交互】用来设置窗口缩放模式的模块
	get_window().set_content_scale_mode(Window.CONTENT_SCALE_MODE_VIEWPORT) #窗口大小跟着视口走，让窗口缩放与视口大小之间产生绑定关系。
	get_window().set_content_scale_aspect(Window.CONTENT_SCALE_ASPECT_EXPAND) #窗口始终会显示视口里看到的全部画面，如果尺寸极端，则会横向或纵向拓展
	# 【暂时弃用】 get_window().set_flag(Window.FLAG_ALWAYS_ON_TOP,true) # 窗口始终在最上层显示

	# 【独立功能，不涉及外部交互】用来把游戏背景变透明的模块。需在项目设置中同步开启：窗口透明、像素级透明、根视口透明
	get_viewport().transparent_bg = true #在游戏过程中，把【视口】变成透明背景。视口涵盖当前节点（根节点）下的各场景。
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true) #把【窗口】背景变成透明背景。窗口是游戏的总体视口。
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true) #把【窗口栏】变成透明的（其实是直接变成无边框）。现在窗口是无边框全透明了。
	
	# 用来设置游戏主窗口初始位置及大小的模块
	screen_width = DisplayServer.screen_get_usable_rect().size.x # 屏幕可用空间宽度，防止有的电脑窗口栏在侧面
	screen_height = DisplayServer.screen_get_usable_rect().size.y # 屏幕可用空间高度，用来表示排除了窗口栏之后的屏幕高度
	viewport_width = ProjectSettings.get_setting("display/window/size/viewport_width") #读取视口宽度，赋值给对应变量（视口大小是在项目设置里写死的）
	viewport_height = ProjectSettings.get_setting("display/window/size/viewport_height") #读取视口高度，赋值给对应变量（视口大小是在项目设置里写死的）
	aspect_ratio = float(viewport_width) / viewport_height # 临时变量，用来记录视口宽高比，后面调整窗口大小要用
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED) # 把游戏运行方式设置为窗口运行
	DisplayServer.window_set_size(Vector2i(screen_width,int(screen_width/aspect_ratio))) # 把游戏窗口尺寸设置为：与屏幕同宽，然后按照视口宽高比来调整窗口高度
	#【暂时弃用】DisplayServer.window_set_max_size(Vector2i(screen_width,screen_height/3)) # 把游戏窗口最大尺寸设置为：与屏幕同宽，高度是屏幕四分之一
	#【暂时弃用】DisplayServer.window_set_min_size(Vector2i(screen_width,150)) # 把游戏窗口最小尺寸设置为：宽1000，高150（建议最小宽度不小于视口宽度，不然会纵向扩展）
	
	window_position = Vector2i(0,screen_height - int(screen_width/aspect_ratio)) # 表示窗口位置的变量，横坐标是0，纵坐标是屏幕高度-窗口高度
	DisplayServer.window_set_position(window_position) # 把上面的变量赋值给窗口位置（显示在屏幕底端）
	
	
	# 用来设置【左】菜单的：位置、大小、缩放。不要直接设置固定数值，不然电脑分辨率调整后游戏比例会失调
	menu_left = $menu_left # 菜单窗口
	#【暂时弃用】menu_left.size = Vector2(screen_width/2,viewport_height) #左菜单大小，如果启用的话记得尽量用viewport的宽高来表示
	menu_left.position = Vector2(-menu_left.size.x-300,0) #左菜单位置
		
	# 用来设置【右】菜单的：位置、大小、缩放。不要直接设置固定数值，不然电脑分辨率调整后游戏比例会失调
	menu_right = $menu_right # 菜单窗口
	#【暂时弃用】menu_right.size = Vector2(screen_width/2,viewport_height) #右菜单大小，如果启用的话记得尽量用viewport的宽高来表示
	menu_right.position = Vector2(viewport_width + 300,0) #右菜单位置
	
	# 初始设定不展示菜单
	menu_show = false
	

# 每帧运行的函数大类
func _process(_delta: float) -> void:

	# 用来弹出和收起菜单
	if menu_show == true: # 点了按钮之后menu_show变成true，执行接下来的操作
		if menu_left.position.x < viewport_width/2.0-menu_left.size.x : # 在【左菜单】的【最右点】抵达屏幕【中间】之前
			menu_left.position += Vector2(50,0)  # 每帧向右50像素
		else :  # 抵达屏幕中间之后
			menu_left.position = Vector2(viewport_width/2.0-menu_left.size.x,0) # 横坐标跑到屏幕中间，纵坐标0
		# 和上面同理
		if menu_right.position.x > viewport_width/2.0: # 在【右菜单】的【最左点】抵达屏幕【中点】之前
			menu_right.position += Vector2(-50,0) # 每帧向左50像素
		else :
			menu_right.position = Vector2(viewport_width/2.0,0) # 横坐标跑到屏幕中间，纵坐标0
	else:
		if menu_left.position.x > -menu_left.size.x-300: # 在【左菜单】的【最左点】抵达屏幕x轴【-300】之前
			menu_left.position += Vector2(-50,0)  # 每帧向左50像素
		else:
			menu_left.position = Vector2(-menu_left.size.x-300,0) # 把位置固定在横坐标-300，纵坐标0
		# 和上面同理
		if menu_right.position.x < viewport_width+300: # 在【右菜单】的【最左点】抵达屏幕【屏幕外300像素】之前
			menu_right.position += Vector2(50,0) # 每帧向右50像素
		else :
			menu_right.position = Vector2(viewport_width+300,0) # 把位置固定在横坐标超屏幕300，纵坐标0

# 用来弹出和收起菜单的函数，接收到信号后自动调用
func _show_menu() -> void:
	
	if menu_show == true: # 点了按钮之后menu_show变成true，执行接下来的操作
		menu_show = false

	else:
		menu_show = true

# 退出游戏函数，点击退出按钮后调用
func _quit_game() -> void:
	get_tree().quit()
