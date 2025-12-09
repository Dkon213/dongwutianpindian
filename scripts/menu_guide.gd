extends Node2D
signal menu_button_pressed #自定义一个新的信号，这个信号用来表示menu按钮被按下。这个信号是该场景根节点直接发出的，不是从button发出
var animation_player : Node # 这个变量用来装路牌的animation player节点
var lupai_show : bool # 这个变量用来控制路牌的正反面显示，true是正，false是反
var is_animating : bool # 这个变量用来表示动画是否正在播放

func _ready() -> void:
	animation_player = $LuPai/AnimatedSprite2D #把动画节点赋值给这个变量
	lupai_show = true # 初始状态下，路牌是正面
	is_animating = false # 初始状态下， 动画没在播放


func _on_button_up() -> void: # 点击路牌按钮以后会发送信号，接收到信号就开始执行这个函数
	#这是该函数做的第一件事，用来向外发信号，用来让根节点唤起菜单
	emit_signal("menu_button_pressed") #发送刚才自定义的信号，发到哪里取决于在信号列表选择了哪里。这里对接的是主场景的脚本
	
	#这是该函数做的第二件事，用来控制路牌动画播放
	if lupai_show == true: # 如果路牌是正面（初始情况就是正面）执行接下来的操作
		animation_player.play(&"fanzhuan") # 首先开始播放翻转动画
		is_animating = true # 因为动画已经开始播放了，所以这时候是“正在播放”状态
		if is_animating == false: # 如果动画播完了
			animation_player.play(&"fan") # 牌子显示的画面切换到反面
		lupai_show = false # 把变量也标记成反面
		print("现在是反面")
	else: # 如果路牌是反面
		animation_player.play_backwards(&"fanzhuan") # 首先播放路牌“转回来”的动画
		is_animating = true # 因为动画已经开始播放了，所以这时候是“正在播放”状态
		if is_animating == false: # 如果动画播完
			animation_player.play(&"zheng") # 牌子显示的画面切换到正面
		lupai_show = true # 把变量也标记成正面
		print("现在是正面")


func _fanzhuan_animation_finished() -> void: # 这个函数是动画播放完成以后触发的
	#if animation_player.animation == "fanzhuan" :
	is_animating = false
		
	
