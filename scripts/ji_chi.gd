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
var target_x: float = 0 # 这里本来是个二维坐标，不过角色不会纵向移动，所以只留了X轴
var click_count: int = 0 # 【鼠标点击计数器】
var auto_action_enabled: bool = true # 【自动行为许可】，初始是true，意思是允许待机动画
var is_moving : bool = false # 【是否移动】该变量主要用于判断帧函数是否要触发。因此跑步和大小走等涉及位移的全都算是在移动
var anim_backwards: bool # 用来记录当前动画是否倒放的状态变量。之所以是全局的，主要是为了在动画播放函数和转身函数之间传递消息
var anim_flip_h : bool # 用来记录当前动画是否翻转的状态变量

# 为了便于调试设置的外显变量
@export var walk_small_speed: float = 50.0  #小走移速
@export var walk_big_speed: float = 100.0 # 大走移速
@export var run_speed: float = 200.0 # 跑步移速
@export var auto_action_interval_min: float  # 待机动画间隔最小值（此处只代表数值，没有时间单位）
@export var auto_action_interval_max: float  # 待机动画间隔最小值（此处只代表数值，没有时间单位）
@export var click_count_timeout: float = 0.5 # 计算点击次数的单位时间
@export var walk_small_range: float = 100.0 # 单次小走的最远距离
@export var rest_scale: Vector2 # 休息类大动作的缩放比
@export var rest_position: Vector2 # 休息类动作的偏移量,默认（85，-45）
@export var default_scale: Vector2 = Vector2(0.32, 0.32) # 其他动作的默认缩放比
@export var default_position: Vector2 # 其他动作的默认偏移量,默认（0，7）

#定义节点变量。初始化结束，ready函数执行之前，创建这些变量。这样相对稳妥可以保障其他节点已经准备好了
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D # 动画精灵节点
@onready var auto_timer: Timer = $AutoActionTimer # 计时器节点，用于待机动作的计时
@onready var click_timer: Timer = $ClickCountTimer # 计时器节点，用于鼠标连点的计时



#---------------------------------------------开始函数--------------------------------------------------------
func _ready() -> void:# 初始化：播放侧面待机，启动计时器
	setup_auto_action_timer() # 激活自动待机倒计时



#--------------------------------------------物理帧函数--------------------------------------------------------
func _physics_process(_delta: float):
	# 第一，如果允许自主行动（也就是在待机状态），那就直接返回，节省性能
	if is_moving == false:
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
	var dir = target_x - global_position.x # 目标位置横坐标减去当前位置横坐标。这里的【global_position】是Node2D节点自带的全局位置属性
	var is_left_move : bool # 声明一个【是否向左】变量，如果【dir】小于零，那就是向左
	if dir < 0:
		is_left_move = true
	else:
		is_left_move = false
		
	#第四，定动画
	# 让bool类型的【is_left_move】来决定动画播放器要不要翻转
	# 由于走跑动画都是向右的，所以向左就是开反转
	anim_sprite.flip_h = is_left_move

	#第五，移动角色。这里的【velocity】是【characterBody2D】自带的速度属性，【move_and_slide】也是其自带的移动方法
	velocity = Vector2(dir,0).normalized() * move_speed # 【velocity】二维速度，赋的值是标准向量（决定方向） * 当前速度
	move_and_slide() #  开始按照指定的方向和速度移动

	#第六，判定啥时候停止
	if abs(global_position.x - target_x) < 5.0: # 如果当前位置横坐标距离目标位置横坐标小于5像素
		# 先保存当前朝向，避免后续状态改变时丢失
		var saved_flip_h = anim_sprite.flip_h
		# 立即停止移动，避免下一帧继续处理
		is_moving = false
		auto_action_enabled = true # 允许自由活动，且下一帧就不会再进入行动，直接返回了
		velocity = Vector2.ZERO # 速度变成0向量，停下了
		# 停下以后，默认切回侧待机，此处入参1-侧待机，入参2-不倒放，入参3-保持当前朝向
		play_anim(AnimState.IDLE_SIDE, false, saved_flip_h)
		setup_auto_action_timer() # 重置制动动作计时
		return # 立即返回，避免后续代码执行



#-------------------------------------------自动动作计时器--------------------------------------------------------
# 计时函数，生成一个计时器，来代表执行待机动作的时长
# 这个计时器是所有待机动作共用的，计时结束了就会开始随机下一个待机动画
func setup_auto_action_timer():
	#【auto_timer】变量对应的是动作计时器节点，给其设置一个要计的时间，时间范围是【待机动画间隔最小值】到【最大值】
	auto_timer.wait_time = randf_range(auto_action_interval_min, auto_action_interval_max)
	auto_timer.start() #根据刚才设定好的随机时间，开始计时



#-------------------------------------信号触发-自动动作计时器计时结束后函数--------------------------------------------------------
#待机计时器倒计时结束以后
#这里的所有内容，都仅限于管理自动待机动画，跟点鼠标后的行为没关系
func _on_auto_action_timer_timeout():
	
	# 如果自动行为被禁用，那就不执行待机动作，或者如果正在走路，那也不待机（小走也不待机，小走完了自己会把is_moving关掉的）
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
			play_anim(AnimState.IDLE_SIDE, false, anim_sprite.flip_h) # 保持当前朝向
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
			anim_name = "idel_front"# 以下同理
		AnimState.IDLE_SIDE:
			anim_name = "idel_side"
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
	if is_rest_anim == true : 
		anim_sprite.scale = rest_scale # 这个rest_scale变量是暴露在外的，可以直接在检查器赋值
		anim_sprite.centered = true 
		anim_sprite.position = rest_position # 同上，管理偏移，检查器赋值
	else: # 如果不是休息动画，就用默认比例播放，(0.32,0.32)是调好的比例
		anim_sprite.scale = default_scale
		anim_sprite.centered = true 
		anim_sprite.position = default_position # 外显的默认偏移量
	
	#动画匹配上了，休息状态判定完了，大小调好了，就开始播放动画
	anim_sprite.flip_h = is_flip_h # 这里的【is_flip_h】是bool类型的入参，只有是否两个值，在这里是给真正的翻转操作下指令
	anim_sprite.animation = anim_name # anim_name是根据函数入参已经调好的，把它赋值给动画精灵要播放的动画
	if is_backwards == true: #如果入参里的【is_backwards】是true，那就倒放，否则就正常
		anim_backwards = true
		anim_sprite.play_backwards() # 动画精灵执行播放动作
	else:
		anim_backwards = false
		anim_sprite.play() # 动画精灵执行播放动作

#--------------------------------------------转身播放函数---------------------------------------------------------------
# 入参1-turn_type: 转身类型（TURN_SMALL/TURN_BIG）
# 入参2-from_dir: 起始方向（left/front/right）
# 入参3-to_dir: 目标方向（left/front/right）
func play_turn_anim(turn_type: AnimState, from_dir: String, to_dir: String):

	match turn_type: # 转向类型匹配（类型只有大转或者小转，是这个函数的入参1）
		AnimState.TURN_SMALL: # 如果是小转
			if from_dir == "left" and to_dir == "front": # 如果是【左前】，那就【不倒放】+【不翻转】
				anim_backwards = false
				anim_flip_h = false
			elif from_dir == "front" and to_dir == "left":  # 如果是【前左】，那就【倒放】+【不翻转】
				anim_backwards = true
				anim_flip_h = false
			elif from_dir == "right" and to_dir == "front": # 如果是【右前】，那就【不倒放】+【翻转】
				anim_backwards = false
				anim_flip_h = true
			elif from_dir == "front" and to_dir == "right": # 如果是【前右】，那就【倒放】+【翻转】
				anim_backwards = true
				anim_flip_h = true
		AnimState.TURN_BIG: # 如果是大转
			if from_dir == "left" and to_dir == "right": # 如果是【左右】，那就【不倒放】+【不翻转】
				anim_backwards = false  
				anim_flip_h = false
			elif from_dir == "right" and to_dir == "left": # 如果是【右左】，那就【倒放】+【不翻转】
				anim_backwards = true   
				anim_flip_h = false
	#入参调整好，直接调用动画播放函数
	play_anim(turn_type, anim_backwards, anim_flip_h)



#----------------------------------------------硬编码接收触发-输入事件函数---------------------------------------------------------------
#godot自带函数，有输入事件时会被调用。输入事件会沿节点树向上传播，直到有节点将其消耗。
#这里给了一个evevt入参，入参是自带类：inputEvevt
func _input(event: InputEvent):
	#如果输入的事件是【鼠标操作】，而且是【鼠标按下】，而且是【鼠标左键】（总的来说就是：如果点了以下鼠标左键）
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		target_x = get_global_mouse_position().x # 首先获取目标位置，坐标就是鼠标点击的地方
		click_count += 1 # 点击计数器+1
		click_timer.stop() # 点击计时器停止，这里的作用是让时间先归零
		click_timer.start(click_count_timeout) # 计时器重新开始一次计时
		auto_action_enabled = false # 自动行为许可被关闭



#----------------------------------------------信号触发-点鼠标计时器到期---------------------------------------------------------------
# 这个函数会在点击计时器倒数结束后触发
func _on_click_count_timeout() -> void:
	# 如果当前正在跑步，无论点击次数多少，都继续保持跑步状态（不能降级）
	if current_state == AnimState.RUN:
		start_move(AnimState.RUN) # 继续跑步到新目标点
	# 如果当前正在走路，且连点次数>=3，则可以升级为跑步
	elif current_state == AnimState.WALK_BIG and click_count >= 3:
		start_move(AnimState.RUN) # 从走路升级为跑步
	# 如果当前正在走路，且单击，则保持走路但更新目标点（直接切换状态即可）
	elif current_state == AnimState.WALK_BIG:
		start_move(AnimState.WALK_BIG) # 继续走路到新目标点
	# 如果当前不在移动状态（待机），则根据点击次数决定
	elif click_count >= 3: # 如果这时候连点大于等于3次
		start_move(AnimState.RUN) # 那就执行跑步
	else: #没到3次
		start_move(AnimState.WALK_BIG) # 就只是走路
	click_count = 0 # 无论哪种情况，都要重置点击计数器



#----------------------------------------------开始移动函数---------------------------------------------------------------
#入参-目标状态，类型是动画状态枚举
func start_move(target_state: AnimState):
	# 停止并重置点击计时器，避免在移动过程中计时器到期导致状态切换
	click_timer.stop()
	click_count = 0
	
	# 防止从跑步状态降级为走路状态（只能升级，不能降级）
	if current_state == AnimState.RUN and target_state == AnimState.WALK_BIG:
		target_state = AnimState.RUN # 强制保持跑步状态
	
	# 首先，如果在休息，先处理休息结束
	if current_state in [AnimState.PREPARE_REST, AnimState.RESTING]: #这里有个问题，准备休息不能直接切休息结束，看是不是先进入休息状态，或者出个打断休息的动画
		play_anim(AnimState.FINISH_REST)  # 播放休息结束
		anim_sprite.set_meta("post_rest_state", target_state) # 给动画播放器节点塞个元数据，数据名称是【休息后的动作】，数据值是入参的目标状态
	#其次，只有当前确实是"正面待机"时，才需要执行"先转身再跑"的逻辑
	elif current_state == AnimState.IDLE_FRONT: 
		var is_left: bool = (target_x - global_position.x) < 0 # 声明一个【是否向左】变量，如果【目标位置】-【当前位置】小于零 那就向左
		play_turn_anim(AnimState.TURN_SMALL, "front", "left" if is_left else "right") # 根据是否向左的情况播放小转动画
		anim_sprite.set_meta("post_turn_state", target_state) # 给动画播放器节点塞个元数据，数据名称是【转身后的动作】，数据值是入参的目标状态
	#再其次，其他情况（侧面待机、正在走路、正在跑步），直接切换到目标移动状态
	# _physics_process 会自动处理 flip_h (左右翻转)，所以这里不需要操心朝向
	else:
		play_anim(target_state) 
	is_moving = true # 开启物理移动



#----------------------------------------------信号触发-单次动画结束函数---------------------------------------------------------------
# 只有不循环动画结束后，才会触发这个函数，目前的不循环动画分别是：大转、小转、休息准备、休息结束
# 【这个函数在待机、手动状态下都会被触发】
func _on_animation_finished() -> void:
	match current_state: # 首先对当前状态进行匹配
		AnimState.TURN_SMALL: # 如果正在执行的小转，那要么转完开始移动，要么转完继续待机
			if anim_sprite.has_meta("post_turn_state") == true: # 如果这时候有元数据，那就是移动
				var post_state = anim_sprite.get_meta("post_turn_state") #这里把刚才塞给动画节点的元数据拿出来，里面【转身后动作】不出意外就是移动
				play_anim(post_state) # 执行这个【转身后动作】
				anim_sprite.remove_meta("post_turn_state") # 执行完了把元数据删掉，下次用了再加
			# 如果这时候没元数据，那就是待机
			elif anim_backwards == false: # 首先如果当前转身动画【不是】倒放的，那无论如何都是转向正面
				play_anim(AnimState.IDLE_FRONT, false, false) # 所以直接播放正面待机
			elif anim_sprite.flip_h == true: # 如果是倒放，那就是往两边转，这时候如果镜像打开，那就是向右转
				play_anim(AnimState.IDLE_SIDE, false, false) # 这时候待机动画反而不用开反转，因为天生就是向右转【这个动画方向我下次一定画成一致的 = =！】
			else: # 这时候就剩一种情况了，就是没倒放，往左转
				play_anim(AnimState.IDLE_SIDE, false, true)
		AnimState.TURN_BIG: # 如果是大转，那就播放侧面待机
			play_anim(AnimState.IDLE_SIDE, false, anim_backwards) # 播放动画 侧面待机 不倒放 是否翻转根据之前的【anim_backwards】赋值决定（只能是倒放值，不能是翻转值）
		AnimState.PREPARE_REST: # 如果当前准备休息，那下个动作就是休息
			play_anim(AnimState.RESTING)
		AnimState.FINISH_REST: # 如果当前休息结束，那看情况执行待机或者行动
			var post_state = anim_sprite.get_meta("post_rest_state", AnimState.IDLE_SIDE) # 这里根据之前塞的元数据来决定这个【休息后动作】是啥
			if post_state != AnimState.IDLE_SIDE: # 如果不是侧面待机，那就执行开始移动函数
				start_move(post_state)
			else:
				play_anim(AnimState.IDLE_SIDE, false, true) # 如果是侧面待机，那就待机，然后计时，然后删除元数据。休息结束之后只能是左侧待机
				setup_auto_action_timer()
			anim_sprite.remove_meta("post_rest_state")

#-----------------------------------------------生成小走目标---------------------------------------------------------------
# 这个函数会在待机动作随机到【小走】的时候触发
func generate_walk_small_target():
	# 先生成一个随机二维方向，x轴都是-1到1的随机浮点数，y轴是0，然后标准化变成标准向量
	var temp_array = [-1, 1] # 先给个随机数组，只有-1和1两个值
	var random_dir = temp_array.pick_random() # 然后在这两个值里面随机选一个，赋值给【随机方向】
	# 小走的目标X坐标，就是当前全局位置X坐标 + (随机方向 * 随机长度），这个随机长度区间是【0】到【小走极限范围】
	target_x = global_position.x + random_dir * randf_range(0, walk_small_range)
	play_anim(AnimState.WALK_SMALL, false, true if random_dir < 0 else false)# 逻辑保底，切换当前状态为小走，否则 physics_process 里没有速度
	auto_action_enabled = true 
	is_moving = true
