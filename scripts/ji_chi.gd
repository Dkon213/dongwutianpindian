extends CharacterBody2D

#---------------------------------------------前期准备-------------------------------------------------------------------
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



#---------------------------------------------开始函数--------------------------------------------------------
func _ready() -> void:# 初始化：播放侧面待机，启动计时器
	setup_auto_action_timer() # 激活自动待机倒计时



#--------------------------------------------物理帧函数--------------------------------------------------------
func _physics_process(delta: float):
	# 第一，如果角色不是正在运动状态，就直接返回，节省性能
	if not is_moving:
		return
	
	# 第二，定速度
	#如果是正在运行状态，那首先定义一个移速变量，赋初始值0。这个【move_speed】是内部变量，目的是直接把开头@export的变量赋值进来
	var move_speed: float = 0.0
	match current_state: #匹配当前状态
		AnimState.WALK_SMALL: move_speed = walk_small_speed #如果当前状态是小走，那就给【move_speed】赋值小走的移速，以下同理
		AnimState.WALK_BIG: move_speed = walk_big_speed
		AnimState.RUN: move_speed = run_speed
		_: return # 逻辑兜底，啥也不是就直接return，保持当前状态不变
	
	# 第三，定方向
	# 声明一个方向变量，变量值是【目标坐标】减去【当前坐标】然后标准化。标准化的作用是让这个向量严格等于1或者-1，变成一个标准向量
	var dir = (target_pos - global_position).normalized() # 这里的【global_position】是Node2D节点自带的全局位置属性
	var is_left_move : bool # 声明一个【是否向左】变量，如果方向变量小于零，那就是向左
	if dir.x < 0:
		is_left_move = true
	else:
		is_left_move = false
		
	#第四，定动画
	# 让bool类型的【is_left_move】来决定动画播放器要不要翻转
	# 由于走跑动画都是向右的，所以向左就是开反转
	anim_sprite.flip_h = is_left_move

	#第五，移动角色。这里的【velocity】是【characterBody2D】自带的速度属性，【move_and_slide】也是其自带的移动方法
	velocity = dir * move_speed # 【velocity】二维速度，赋的值是标准向量（决定方向） * 当前速度
	move_and_slide() #  开始按照指定的方向和速度移动

	#第六，判定啥时候停止
	if global_position.distance_to(target_pos) < 5.0: # 如果当前位置距离目标位置小于5像素
		is_moving = false # 【is_moving】状态变成否，也就是说下一帧就不会再进入行动，直接返回了
		velocity = Vector2.ZERO # 速度变成0向量，停下了
		# 停下以后，默认切回侧待机，此处入参1-侧待机，入参2-不倒放，入参3-如果是向左那就翻转，向右就不翻转
		play_anim(AnimState.IDLE_SIDE, false, is_left_move)
		auto_action_enabled = true # 自由活动许可打开
		setup_auto_action_timer() # 重置制动动作计时



#-------------------------------------------自动动作计时器--------------------------------------------------------
# 计时函数，生成一个计时器，来代表执行待机动作的时长
# 这个计时器是所有待机动作共用的，计时结束了就会开始随机下一个待机动画
func setup_auto_action_timer():
	#【auto_timer】变量对应的是动作计时器节点，给其设置一个要计的时间，时间范围是【待机动画间隔最小值】到【最大值】
	auto_timer.wait_time = randf_range(auto_action_interval_min, auto_action_interval_max)
	auto_timer.start() #根据刚才设定好的随机时间，开始计时



#-------------------------------------信号触发-自动动作计时器计时结束后函数--------------------------------------------------------
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
			
	# 只有之前已经是侧面待机状态了，才能走到这一步
	# 首先生成一个随机整数，除以【candidate_states】数组的长度（4），余数是一个0-4的数，然后用【candidate_states】排这个位置的动画给【random_state】赋值
	var random_state = candidate_states[randi() % candidate_states.size()]
	if random_state == AnimState.TURN_SMALL: # 如果随机到的动作是小转，那就转向正面
		# 这里调用转身动画函数，入参1是小转身，入参2是【如果当前侧面待机反转了，那就从左开始，否则就从右开始】，入参3是往前
		play_turn_anim(AnimState.TURN_SMALL, "left" if anim_sprite.flip_h else "right", "front")
	elif random_state == AnimState.TURN_BIG: # 不是小转的话，那如果是大转，就转到另一边
		# 同上，转身函数，入参1是大转，入参2是【如果当前侧面待机反转了，那就从左开始，否则就从右开始】，入参3同理，终点是另一边
		play_turn_anim(AnimState.TURN_BIG, "left" if anim_sprite.flip_h else "right", "right" if anim_sprite.flip_h else "left")
	else: # 如果既不是大转也不是小转，那只能是走路或者休息了
		play_anim(random_state) # 这里的【random_state】是刚才定义的变量，变量值是【candidate_states】数组的其中一个

	if random_state == AnimState.WALK_SMALL:
		generate_walk_small_target()
		
	setup_auto_action_timer() # 最后走完了，重启计时



#--------------------------------------------动画播放函数---------------------------------------------------------------
#定义一个play_anim函数，这个函数有3个入参
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

#--------------------------------------------转身播放函数---------------------------------------------------------------
# 入参1-turn_type: 转身类型（TURN_SMALL/TURN_BIG）
# 入参2-from_dir: 起始方向（left/front/right）
# 入参3-to_dir: 目标方向（left/front/right）
func play_turn_anim(turn_type: AnimState, from_dir: String, to_dir: String):
	var is_backwards = false # 初始赋值，不倒放
	var is_flip_h = false # 初始赋值，不翻转

	match turn_type: # 转向类型匹配（类型只有大转或者小转，是这个函数的入参1）
		AnimState.TURN_SMALL: # 如果是小转
			if from_dir == "left" and to_dir == "front": # 如果是【左前】，那就【不倒放】+【不翻转】
				is_backwards = false
				is_flip_h = false
			elif from_dir == "front" and to_dir == "left":  # 如果是【前左】，那就【倒放】+【不翻转】
				is_backwards = true
				is_flip_h = false
			elif from_dir == "right" and to_dir == "front": # 如果是【右前】，那就【不倒放】+【翻转】
				is_backwards = false
				is_flip_h = true
			elif from_dir == "front" and to_dir == "right": # 如果是【前右】，那就【倒放】+【翻转】
				is_backwards = true
				is_flip_h = true
		AnimState.TURN_BIG: # 如果是大转
			if from_dir == "left" and to_dir == "right": # 如果是【左右】，那就【不倒放】+【不翻转】
				is_backwards = false  
				is_flip_h = false
			elif from_dir == "right" and to_dir == "left": # 如果是【右左】，那就【倒放】+【不翻转】
				is_backwards = true   
				is_flip_h = false
	#入参调整好，直接调用动画播放函数
	play_anim(turn_type, is_backwards, is_flip_h)



#----------------------------------------------开始移动函数---------------------------------------------------------------
#入参-目标状态，类型是动画状态枚举
func start_move(target_state: AnimState):
	# 首先，如果入参的目标状态是【准备休息】或者【休息中】
	if current_state in [AnimState.PREPARE_REST, AnimState.RESTING]:  #这里有个问题，准备休息不能直接切休息结束，看是不是先进入休息状态，或者出个打断休息的动画
		play_anim(AnimState.FINISH_REST) # 播放休息结束
		anim_sprite.set_meta("post_rest_state", target_state) # 给动画播放器节点塞个元数据，数据名称是【休息后的动作】，数据值是入参的目标状态
	elif current_state != AnimState.IDLE_SIDE: # 否则，如果目标状态不是侧面待机（也就是除了休息和待机的情况外）
		var is_left: bool = (target_pos.x - global_position.x) < 0 # 声明一个【是否向左】变量，如果【目标位置】-【当前位置】小于零 那就向左
		play_turn_anim(AnimState.TURN_SMALL, "front", "left" if is_left else "right") # 根据是否向左的情况播放小转动画
		anim_sprite.set_meta("post_turn_state", target_state) # 给动画播放器节点塞个元数据，数据名称是【转身后的动作】，数据值是入参的目标状态
	else: # 其他情况下，也就是侧面待机情况下
		play_anim(target_state) # 已在侧面，直接播放移动动画（方向由后续_physics_process判定）
	is_moving = true  #最后统一把【移动中】变成【是】，开始移动了



#----------------------------------------------信号触发-开始移动函数---------------------------------------------------------------
# 只有不循环动画结束后，才会触发这个函数，目前的不循环动画分别是：大转、小转、休息准备、休息结束
func _on_animation_finished() -> void:
	match current_state: # 首先对当前状态进行匹配
		AnimState.TURN_SMALL: # 如果正在执行的小转，那转完就该移动了
			#这里把刚才塞给动画节点的元数据拿出来，里面【转身后动作】不出意外就是移动
			var post_state = anim_sprite.get_meta("post_turn_state", AnimState.IDLE_SIDE)
			play_anim(post_state) # 执行这个【转身后动作】
			anim_sprite.remove_meta("post_turn_state") #执行完了把元数据删掉，下次用了再加
		AnimState.TURN_BIG: #如果是大转，那就播放侧面待机（为啥？）
			play_anim(AnimState.IDLE_SIDE, false, anim_sprite.flip_h) # 播放动画 侧面待机 不倒放 是否翻转根据之前的赋值决定
		AnimState.PREPARE_REST: # 如果当前准备休息，那下个动作就是休息
			play_anim(AnimState.RESTING)
		AnimState.FINISH_REST: # 如果当前休息结束，那看情况执行待机或者行动
			# 这里根据之前塞的元数据来决定这个【休息后动作】是啥
			var post_state = anim_sprite.get_meta("post_rest_state", AnimState.IDLE_SIDE)
			if post_state != AnimState.IDLE_SIDE: # 如果不是侧面待机，那就执行开始移动函数
				start_move(post_state)
			else:
				play_anim(AnimState.IDLE_SIDE) # 如果是侧面待机，那就待机，然后计时，然后删除元数据
				setup_auto_action_timer()
			anim_sprite.remove_meta("post_rest_state")



#----------------------------------------------硬编码接收触发-开始移动函数---------------------------------------------------------------
#godot自带函数，有输入事件时会被调用。输入事件会沿节点树向上传播，直到有节点将其消耗。
#这里给了一个evevt入参，入参是自带类：inputEvevt
func _input(event: InputEvent):
	#如果输入的事件是【鼠标操作】，而且是【鼠标按下】，而且是【鼠标左键】（总的来说就是：如果点了以下鼠标左键）
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		target_pos = get_global_mouse_position() # 首先获取目标位置，坐标就是鼠标点击的地方
		click_count += 1 # 点击计数器+1
		click_timer.stop() # 点击计时器停止，这里的作用是让时间先归零
		click_timer.start(click_count_timeout) # 计时器重新开始一次计时
		auto_action_enabled = false # 自动行为许可被关闭



#----------------------------------------------信号触发-点鼠标计时器到期---------------------------------------------------------------
# 这个函数会在点击计时器倒数结束后触发
func _on_click_count_timeout() -> void:
	if click_count >= 3: # 如果这时候连点大于等于3次
		start_move(AnimState.RUN) # 那就执行跑步
	else: #没到3次
		start_move(AnimState.WALK_BIG) # 就只是走路
		click_count = 0 # 顺便重置计时



#-----------------------------------------------生成小走目标---------------------------------------------------------------
# 这个函数会在待机动作随机到【小走】的时候触发
func generate_walk_small_target():
	# 先生成一个随机二维方向，（xy轴都是-1到1的随机浮点数，然后标准化变成标准向量）这里注意，要把Y轴归零
	var random_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	# 小走的目标点位，就是当前全局位置+随机方向的随机长度，这个随机长度区间是【0】到【小走极限范围】
	target_pos = global_position + random_dir * randf_range(0, walk_small_range)
	is_moving = true # 直觉告诉我这里是bug，小走不能算移动
