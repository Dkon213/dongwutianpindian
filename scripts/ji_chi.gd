extends CharacterBody2D

# 创建一个枚举，包含了鸡翅的所有动作，用来形成后面的状态机
enum AnimState 
{ 
	IDLE_FRONT, # 正面待机
	IDLE_SIDE, # 侧面待机
	WALK_SMALL, # 小走
	WALK_BIG, # 大走
	RUN, # 跑
	TURN_SMALL, # 小转身，对应正左、正右、左正、右正
	TURN_BIG, # 大转身，对应左右、右左
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

# 为了便于调试设置的外显变量
@export var walk_small_speed: float = 50.0  #小走移速
@export var walk_big_speed: float = 100.0 # 大走移速
@export var run_speed: float = 200.0 # 跑步移速
@export var auto_action_interval_min: float = 3.0 # 待机动画间隔最小值（此处只代表数值，没有时间单位）
@export var auto_action_interval_max: float = 5.0 # 待机动画间隔最小值（此处只代表数值，没有时间单位）
@export var click_count_timeout: float = 0.5 # 计算点击次数的单位时间
@export var walk_small_range: float = 100.0 # 单次小走的最远距离
@export var rest_scale: Vector2 = Vector2(1.5, 1.5) # 休息类大动作的缩放比
@export var rest_offset: Vector2 = Vector2(-10, -20) # 休息类动作的偏移量
@export var default_scale: Vector2 = Vector2(0.32, 0.32) # 其他动作的默认缩放比


#定义节点变量。初始化结束，ready函数执行之前，创建这些变量。这样相对稳妥可以保障其他节点已经准备好了
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D # 动画精灵节点
@onready var auto_timer: Timer = $AutoActionTimer # 计时器节点，用于待机动作的计时
@onready var click_timer: Timer = $ClickCountTimer # 计时器节点，用于鼠标连点的计时

func _ready() -> void:# 初始化：播放侧面待机，启动计时器
	#初始化：播放侧面待机，启动计时器
	play_anim(AnimState.IDLE_SIDE) # 调用咱自创的动画播放函数，把正面待机作为入参，也就是开始播放正面待机动画
	setup_auto_action_timer()
	# 监听动画结束信号（仅非循环动画触发！AnimatedSprite2D的关键区别）
	#anim_sprite.animation_finished.connect(_on_animation_finished)
	#click_timer.timeout.connect(_on_click_count_timeout)
	

#定义一个play_anim函数，这个函数的入参是target_state，要求是AnimState类型的变量
#target_state作为入参，主要的作用是对各种动作统一管理，避免每个动作都需要一个执行函数
#is_backwards入参，判断本次播放要不要倒放
#is_flip_h入参，判断本次播放要不要翻转
func play_anim(target_state: AnimState , is_backwards: bool = false , is_flip_h: bool = false): 
	
	var anim_name: String = "" # 内部变量，用来放动画名称，变量类型是字符串，默认赋空值
	var is_rest_anim: bool = false # 内部变量，用来判断是否是休息动画，默认为否 
	
	anim_sprite.stop() # 动画精灵节点先停止播放当前的动画
	current_state = target_state # 把target_state这个入参，赋值给自己定义的current_state当前状态变量
	
	# 对target_state这个参数建立一个匹配树，匹配到对应情况就执行对应代码
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
		AnimState.TURN_SMALL:
			anim_name = "turn_small"
		AnimState.TURN_BIG:
			anim_name = "turn_big"
		AnimState.PREPARE_REST:  # 休息动画比较特殊，除了匹配动画之外还要标记休息状态，因为后面要调整大小 # 动画还没加进来
			anim_name = "prepare_rest"
			is_rest_anim = true
		AnimState.RESTING: 
			anim_name = "resting"
			is_rest_anim = true
		AnimState.FINISH_REST: 
			anim_name = "finish_rest"
			is_rest_anim = true

	#如果是休息动画，就调整缩放模式、是否居中、偏移量，这个后续调试
	if is_rest_anim == true : 
		anim_sprite.scale = rest_scale # 这个rest_scale变量是暴露在外的，可以直接在检查器赋值
		anim_sprite.centered = true 
		anim_sprite.offset = rest_offset # 同上，管理偏移，检查器赋值
	else: # 如果不是休息动画，就用默认比例播放，(0.32,0.32)是调好的比例
		anim_sprite.scale = default_scale
		anim_sprite.centered = true 
		anim_sprite.offset = Vector2.ZERO # 没设置外显的默认偏移，因为大概率用不上
	
	#动画匹配上了，休息状态判定完了，大小调好了，就开始播放动画
	anim_sprite.flip_h = is_flip_h # 这里的【is_flip_h】是bool类型的入参，只有是否两个值，在这里是给真正的翻转操作下指令
	anim_sprite.animation = anim_name # anim_name是根据函数入参已经调好的，把它赋值给动画精灵要播放的动画
	if is_backwards == true: #如果入参里的【is_backwards】是true，那就倒放，否则就正常
		anim_sprite.play_backwards() # 动画精灵执行播放动作
	else:
		anim_sprite.play() # 动画精灵执行播放动作


# 计时函数，生成一个计时器，来代表执行待机动作的时长
func setup_auto_action_timer():
	#【auto_timer】变量对应的是动作计时器节点，给其设置一个要计的时间，时间范围是【待机动画间隔最小值】到【最大值】
	auto_timer.wait_time = randf_range(auto_action_interval_min, auto_action_interval_max)
	auto_timer.start() #根据刚才设定好的随机时间，开始计时
	
#待机计时器倒计时结束以后
func _on_auto_action_timer_timeout():
	
	# 如果正在移动，或者如果自动行为被禁用，那就不执行待机动作，同时重置计时（小走不算移动）
	if is_moving or not auto_action_enabled: 
		setup_auto_action_timer()
		return
		
	#如果没在移动，那就执行接下来的动作（不需要单独else，因为在移动就直接跳过函数了）
	var candidate_states: Array[AnimState] = [] # 定义一个【备选状态】变量，类型是数组，且数组只能是【AnimState】枚举里的值，然后初始给个空值
	match current_state: # 根据【current_state】也就是当前状态来做匹配
		AnimState.IDLE_FRONT: # 如果当前动作是正面待机，那就先向左或者向右转，然后等一会
			var random_dir = "left" if randi() % 2 == 0 else "right" # 声明一个【随机方向】变量，赋一个左或右的随机值
			#↑【randi() % 2】是一个随机非负整数除以二的余数，所以只能是1或者0，如果0就往左，1就往右
			play_turn_anim(AnimState.TURN_SMALL, "front", random_dir) #调用转向动画函数，入参是：小转向、从前开始，向左或向右取决于刚才的随机结果
			setup_auto_action_timer() # 再次计时，时间到就该播放下一个动画了，在此之前一直是侧面待机不动
			return #本次函数执行结束
		AnimState.IDLE_SIDE: # 如果这时候已经是侧面待机了，那就随机执行小转、大转、小走、准备休息
			candidate_states = [  # 先给之前的备选动作数组赋值，里面是备选的动作
				AnimState.TURN_SMALL, 
				AnimState.TURN_BIG,  
				AnimState.WALK_SMALL,
				AnimState.PREPARE_REST
			]
		# 这里有个bug，这时不知道小走是往左还是往右，因此侧面待机也不知道该往哪个方向待机
		AnimState.WALK_SMALL:  #  如果当前是小走，那就侧面待机
			play_anim(AnimState.IDLE_SIDE)
			setup_auto_action_timer()
			return
		AnimState.RESTING: # 如果当前是休息中，那就休息结束
			play_anim(AnimState.FINISH_REST)
			setup_auto_action_timer()
			return
		_: # 逻辑兜底，如果是其他情况那就仅重置计时，不进行其他操作
			setup_auto_action_timer()
			return
