extends CharacterBody2D

# 创建一个枚举，包含了鸡翅的所有动作，用来形成后面的状态机
enum AnimState 
{ 
	IDLE_FRONT, # 正面待机
	IDLE_SIDE, # 侧面待机
	WALK_SMALL, # 小走
	WALK_BIG, # 大走
	RUN, # 跑
	TURN_FRONT_TO_SIDE, # 正转侧
	TURN_SIDE_TO_FRONT, # 侧转正 # 待确认，需不需要，还是复用正转侧
	TURN_SIDE_LEFT_RIGHT, # 侧转侧
	PREPARE_REST, # 准备休息
	RESTING, # 休息中
	FINISH_REST # 休息结束
}

# 定义全局变量
# ↓定义一个【当前状态】变量，这个变量的数据类型是刚才定义的【AnimState】枚举，默认赋值先给枚举里的【正面待机】
var current_state: AnimState = AnimState.IDLE_FRONT
var target_pos: Vector2 = Vector2.ZERO # 【目标地点】变量，二维向量，默认状态下是（0，0）
var is_moving: bool = false # 【是否在移动】
var click_count: int = 0 # 【鼠标点击计数器】
var auto_action_enabled: bool = true # 【自动行为许可】，初始是true，意思是允许待机动画

#定义节点变量。初始化结束，ready函数执行之前，创建这些变量。这样相对稳妥可以保障其他节点已经准备好了
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D # 动画精灵节点
@onready var auto_timer: Timer = $AutoActionTimer # 计时器节点，用于待机动作的计时
@onready var click_timer: Timer = $ClickCountTimer # 计时器节点，用于鼠标连点的计时

func _ready() -> void:# 初始化：播放侧面待机，启动计时器
	#初始化：播放侧面待机，启动计时器
	play_anim(AnimState.IDLE_SIDE) # 调用咱自创的动画播放函数，把正面待机作为入参，也就是开始播放正面待机动画
	setup_auto_action_timer()
	# 监听动画结束信号（仅非循环动画触发！AnimatedSprite2D的关键区别）
	anim_sprite.animation_finished.connect(_on_animation_finished)
	click_timer.timeout.connect(_on_click_count_timeout)
	

# 定义一个play_anim函数，这个函数的入参是target_state，要求是AnimState类型的变量
#target_state作为入参，主要的作用是对各种动作统一管理，避免每个动作都需要一个执行函数
func play_anim(target_state: AnimState): 
	anim_sprite.stop() # 动画精灵节点先停止播放当前的动画
	current_state = target_state # 把target_state这个入参，赋值给自己定义的current_state当前状态变量
	var anim_name: String = "" # 内部变量，用来放动画名称，变量类型是字符串，默认赋空值
	var is_rest_anim: bool = false # 内部变量，用来判断是否是休息动画，默认为否 
	
	# 对target_state这个参数建立一个匹配树，匹配到对应情况就执行对应代码
	# 我初步感觉，这里需要加入“动画反向播放”和“动画纹理反转”两类标记
	match target_state: 
		AnimState.IDLE_FRONT: #如果入参是IDLE_FRONT，就把anim_name变量赋值成idle_front，跟动画名称对应。
			anim_name = "idle_front" # 以下同理
		AnimState.IDLE_SIDE:
			anim_name = "idle_side"
		AnimState.WALK_SMALL:
			anim_name = "walk_small"
		AnimState.WALK_BIG:
			anim_name = "walk_big"
		AnimState.RUN:
			anim_name = "run"
		AnimState.TURN_FRONT_TO_SIDE:
			anim_name = "turn_front_to_side"
		AnimState.TURN_SIDE_TO_FRONT:
			anim_name = "turn_side_to_front"
		AnimState.TURN_SIDE_LEFT_RIGHT:
			anim_name = "turn_side_left_right"
		AnimState.PREPARE_REST:  # 休息动画比较特殊，除了匹配动画之外还要标记休息状态，因为后面要调整大小
			anim_name = "prepare_rest"
			is_rest_anim = true
		AnimState.RESTING: 
			anim_name = "resting"
			is_rest_anim = true
		AnimState.FINISH_REST: 
			anim_name = "finish_rest"
			is_rest_anim = true

	#如果是休息动画，就调整缩放模式、是否居中、偏移量，这个后续调试
	if is_rest_anim: 
		anim_sprite.scale = Vector2(1,1)
		anim_sprite.centered = true 
		anim_sprite.offset = Vector2.ZERO
	else: # 如果不是休息动画，就用默认比例播放，(0.32,0.32)是调好的比例
		anim_sprite.scale = Vector2(0.32,0.32)
		anim_sprite.centered = true 
		anim_sprite.offset = Vector2.ZERO
	
	#动画匹配上了，休息状态判定完了，大小调好了，就开始播放动画
	anim_sprite.animation = anim_name # anim_name是根据函数入参已经调好的，把它赋值给动画精灵要播放的动画
	# 动画策略确定了以后，如果代码里的名称和真实动画名称不一样的话（比如正转侧对应多个动画），看一下这里是不是需要修改
	anim_sprite.play() # 动画精灵执行播放动作
