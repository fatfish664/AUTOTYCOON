extends CharacterBody2D

# NPC的状态
enum NPCState {
	SLEEPING, # 睡觉
	CLOCKIN, # 上班打卡
	WORKING, # 工作
	CLOCKOUT, # 下班打卡
	EATING, # 吃饭
	DRINKING, # 喝水
	IDLE, # 暂时休息
	WAITING,  # 待机
	MOVING, # 移动
	ROTATE, # 转向
	AVOIDING, # 回避
	STUCK, # 卡住
}

@export var home_position: Vector2 = Vector2(800, 200)
@export var detection_radius: float = 100.0
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var animation_player: AnimatedSprite2D = $AnimatedSprite2D
@onready var wigwag_detector: Area2D = $WigwagDetector
@onready var sway_detector: Area2D = $SwayDetector
@onready var interact: Area2D = $Interact
@onready var collision = $CollisionShape2D
@onready var taking = $Taking
@export var animation_positions: Dictionary = {
	"left-front": [Vector2(-15,5), Vector2(-18,6), Vector2(0,13), Vector2(0,13)],
	"left-back": [Vector2(-15,5), Vector2(-13,-6), Vector2(0,-6), Vector2(0,-6)],
	"right-front": [Vector2(15,5), Vector2(15,8), Vector2(0,13), Vector2(0,13)],
	"right-back": [Vector2(15,5), Vector2(10,-6), Vector2(0,-6), Vector2(0,-6)],
	"front-left": [Vector2(0,13), Vector2(0,13), Vector2(0,13), Vector2(-18,6)],
	"front-right": [Vector2(0,13), Vector2(0,13), Vector2(0,13), Vector2(15,8)],
	"back-left": [Vector2(0,-6), Vector2(0,-6), Vector2(0,-6), Vector2(-13,-6)],
	"back-right": [Vector2(0,-6), Vector2(0,-6), Vector2(0,-6), Vector2(10,-6)],
	}

# 移动参数
var normal_speed = 80.0 # 正常速度
var tired_speed = 50.0 # 疲惫速度
var speed = normal_speed # 当前速度
var ahead_direction = ""  # 上一个方向
var last_direction = "right" # 最后的方向（默认朝右）
var is_moving: bool = false  # 是否正在移动
# 特殊移动 或 转弯相关
var item_direction = ""   # 携带物品的方向
var move_state = ""  # 移动时所携带的物品或进入的状态
var direction_taking  # 移动相关方向的位置
var anim_rotate  # 当前的转弯的名称
# 避障相关
var is_being_avoidance = false  #  是否在规避障碍物
var optimal_dir    # 用来记录当前的避让方向
var wigwag_obstacles: Array = [] # 前后的障碍物集合
var sway_obstacles: Array = [] # 左右的障碍物集合
var forward_obstacles = []  # 基于前进方向来判断前方的障碍物
# 特殊避障
var side_obstacles = []  # 基于侧面方向来判断是否绕过障碍物
var is_being_avoiding = false  # 是否处于待规避状态
var avoiding_direction = ""   # 特殊避障，完成转弯后的方向
var avoiding_item  = null   # 记录要规避的障碍物
var finish_swing    # 是否完成特殊避障转弯
# 卡顿相关
var stuck_timer: float = 0.0  # 相同位置的停留时间
var last_position: Vector2 = Vector2.ZERO  # 之前的位置，用于判断是否在停留
var target_dir   # 目的地对于NPC的方位
# NPC作息表（字典）
var current_state: NPCState = NPCState.IDLE   # 目前的状态
var schedule = {
	# 格式: 开始时间: [状态, 持续时间(分钟), 目标位置(可选)]
	0: NPCState.CLOCKIN,   # 因为逻辑问题，留下(必须设置状态，玩家没特意设置，则于为上一天最后的状态)
	2: NPCState.WORKING,   # 7:00-11:00 工作
	#11: NPCState.EATING,    # 11:00-11:30 吃饭
	#11.5: NPCState.SLEEPING,  # 11:30-14:00 休息
	#14: NPCState.WORKING,  # 14:00-18:30 上班
	#18.5: NPCState.EATING,  # 18:30-19:00 吃饭
	#19: NPCState.IDLE,    # 19:00-23:00 休闲
	#22: NPCState.CLOCKOUT,   # 23:00-7:00 睡觉
	24: NPCState      # 因为逻辑问题，留下(不可以设置状态，空置)
}
# 进行活动参数
var next_state = null # 用于辅助确定下一个活动
var nearest_object   # 离NPC最近的物品
var target_position: Vector2  # 目的地
var is_being_action = false # 是否在进行行为动画
var interact_door = null # 用于交互的物品
# 状态参数
var max_stamina: float = 100.0 #最大体力
var stamina = max_stamina
var is_relaxing = false   # 角色是否在休息
var is_exhausted: bool = false  # 标记角色是否疲惫状态
var is_burnout: bool = false   # 标记是否力竭
# 工作相关的参数
var is_being_mufit = false  # 角色是否处于常服状态（没上班处于常服态）
var is_working = false   # 标记角色是否在工作
var contine_working = false  # 判断角色是否在持续工作状态，使其不乱走
var work_tool  # 工作时要用的工具
var enginery = null  # 汽车停放的车位
# 工作测试
var test_count = 0   # 用于记录测试了几项
var points = []  # 检查点位置集
var current_marker_index: int = 0
#var is_viewing: bool = false
# 工作维修
var is_need_maintain = false   # 是否要保养维修
var maintain_count = 0   # 用于记录维修了几项
# 工作修理
var is_need_repair = false    # 是否要修理车辆
# 等待相关的函数
var wait_timer: Timer
var wait_duration: float = 2.0  # 等待2秒
# 体力消耗/恢复参数
var stamina_timer := 0.0 
var stamina_loss_rate := 1.0 # 每 1 秒扣 1 点
var work_stamina_cost: float = 20.0 #每次工作消耗量
var stamina_regen_rate: float = 25.0  # 每秒恢复体力量
# 装备栏参数
var is_have_bottle = false  # 是否带着水瓶

func _ready():
	add_to_group("NPC")
	# 等待一帧确保 NavigationServer 就绪
	await get_tree().process_frame
	if not has_node("Interaction"):
		setup_interaction_area()
	wait_time()
	# 行走过程运行的函数
	#navigation_agent.velocity_computed.connect(_on_velocity_computed)
	# 到达位置后，运行的函数
	navigation_agent.target_reached.connect(_on_target_reached)
	wigwag_detector.body_entered.connect(_on_wigwag_detected)
	wigwag_detector.body_exited.connect(_on_wigwag_exited)
	sway_detector.body_entered.connect(_on_sway_detected)
	sway_detector.body_exited.connect(_on_sway_exited)
	interact.area_entered.connect(_on_interact_entered)
	interact.area_exited.connect(_on_interact_exited)
	animation_player.animation_finished.connect(_on_animation_finished)
	animation_player.frame_changed.connect(_update_marker_position)
	# 配置障碍物检测
	wigwag_detector.monitoring = true
	# 确保网格管理器已初始化
	if GridManager.grid_map.is_empty():
		var world_size = get_viewport().get_visible_rect().size
		GridManager.initialize_grid(world_size)

# 对检测交互区域的设置
func setup_interaction_area():
	var area = Area2D.new()
	area.name = "Interaction"
	var shape = CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 60
	area.add_child(shape)
	add_child(area)
	area.area_entered.connect(_on_interaction_area_entered)
	area.area_exited.connect(_on_interaction_area_exited)

# 创建等待计时器
func wait_time():
	wait_timer = Timer.new()
	wait_timer.one_shot = true
	wait_timer.timeout.connect(_on_wait_finished)
	add_child(wait_timer)

func _physics_process(delta):
	if TimeSystem:
		# 初始化状态
		_on_time_updated(TimeSystem.hours, TimeSystem.minutes)
	find_target()
	_execute_move_behavior(delta)
	if not is_moving:
		_execute_state_behavior()
	z_index = clamp($ShelterBase.global_position.y, -1000, 10000)

# 时间转换函数（如 6时30分 → 6.5）
func _on_time_updated(hour: int, minute: int):
	var raw_time = hour + minute / 60.0
	var current_time = round(raw_time * 2) / 2
	_update_schedule(current_time)

# 更新行动函数
func _update_schedule(current_time: float):
	if is_relaxing or is_working:
		return
	# 找到下一个活动
	var next_activity = null
	var time2 = null # 记录之前的时间（辅助查找当前NPC该做的事）
	# 查找下一个计划的活动
	for time in schedule.keys():
		if time2 != null and time2 <= current_time:
			if time > current_time:
				next_activity = schedule[time2]
				break
		time2 = time
	# 更新状态，准备进行行为
	if judge_update_schedule(next_activity):
		print("活动改变")
		finish_activity()
		is_being_action = false
		current_state = next_activity

# 判断是否要进行活动更新 
func judge_update_schedule(next_activity):
	if current_state == NPCState.ROTATE or current_state == NPCState.WAITING:
		return false
	if next_activity != null:
		if current_state != NPCState.STUCK:
			if current_state == NPCState.MOVING:
				if next_state != next_activity:
					return true
			else:
				if current_state != next_activity:
					return true
	return false

# 根据状态改变下次行动的函数
func body_update_state():
	if stamina <= 40:
		current_state = NPCState.DRINKING
		is_relaxing = true

#完成活动后进行处理函数
func finish_activity():
	if not nearest_object:
		return
	if current_state == NPCState.WORKING:
		contine_working = false
		#nearest_object.work_area.finish_work()
	if current_state == NPCState.SLEEPING:
		nearest_object.stand_up()
		nearest_object.sit_area._player_stand()
	if current_state == NPCState.EATING:
		nearest_object.close_refrigerator()
		nearest_object.re_area._player_stop()

# 寻找目标
func find_target():
	if is_being_action or is_working:
		return
	var change_target = false
	if current_state == NPCState.CLOCKIN:
		find_and_move_on_object("wardrobe")
		change_target = true
	if current_state == NPCState.CLOCKOUT:
		find_and_move_on_object("wardrobe")
		change_target = true
	if current_state == NPCState.SLEEPING:
		find_and_move_on_object("sofa")
		change_target = true
	if current_state == NPCState.WORKING:
		if contine_working:
			# 如果完成一个工作后再进行下一个工作要缓冲可以在这里加函数
			return
		find_and_move_on_object("car")
		change_target = true
	if current_state == NPCState.EATING:
		find_and_move_on_object("refrigerator")
		change_target = true
	if current_state == NPCState.DRINKING:
		find_and_move_on_object("dispenser")
		change_target = true
	if change_target:
		print("目的地改变，状态改变")
		next_state = current_state
		current_state = NPCState.MOVING

## 根据状态移动到相应位置(弃用，已经改为以格子的方式寻路)
#func move_target(delta):
	#is_moving = true
	#if navigation_agent.is_navigation_finished():
		#is_moving = false
		## 微调位置使Marker2D与目标位置重合
		#var position_offset = target_position - $SitPlace.global_position
		#global_position += position_offset
		#return
	#var next_position = navigation_agent.get_next_path_position()
	#var direction = (next_position - global_position).normalized()
	## 优先左右移动：如果水平方向移动足够，就保持水平移动
	### 但是一旦进行了绕路之后，就改变移动逻辑，优先进行上下移动
	#var horizontal_component = Vector2(direction.x, 0).normalized()
	#if abs(direction.x) > 0.03:  # 水平方向有显著移动时优先水平
		#direction = horizontal_component
	#if abs(direction.x) <= 0.03:
		#is_being_avoiding = true
	## 否则使用原始方向（包含垂直移动）
	#consume_stamina(delta, 1)
	## 应用障碍物避让
	#direction = _apply_obstacle_avoidance(direction)
	#velocity = direction * speed
	## 根据移动方向和状态更新动画
	#make_direction(direction)
	#move_and_slide()
	### 碰到障碍物时，NPC的横坐标与目标的横坐标已经相同的情况
	##if need_swing_by():
		##current_state = NPCState.AVOIDING
	## 是否卡住
	#if _is_stuck(delta):
		#current_state = NPCState.STUCK

func move_target(delta):
	is_moving = true
	consume_stamina(delta, 1)
	# 是否卡住
	if _is_stuck(delta):
		current_state = NPCState.STUCK

# 应用障碍物避让
func _apply_obstacle_avoidance(base_direction: Vector2) -> Vector2:
	if is_being_avoidance:
		if avoiding_item in forward_obstacles:
			return optimal_dir
		# 特殊的避障，NPC的横坐标与目标的横坐标已经相同的情况
		if is_being_avoiding:
			if avoiding_item in side_obstacles:
				finish_swing = true
			if finish_swing:
				if not avoiding_item in side_obstacles:
					finish_swing = false
					avoiding_item = null
					avoiding_direction = ""
					is_being_avoidance = false
					return base_direction
			return avoiding_direction
	# 基于前进方向来判断前方的障碍物
	if abs(base_direction.x) > 0.9:
		forward_obstacles = sway_obstacles
		side_obstacles = wigwag_obstacles
	if abs(base_direction.y) > 0.9:
		forward_obstacles = wigwag_obstacles
		side_obstacles = sway_obstacles
	#if forward_obstacles == []:
		#print("在JackMiller的脚本中，NPC进行了避让")
	# 动态避障：检查附近障碍物
	for obstacle in forward_obstacles:
		if obstacle == work_tool and work_tool.taking_area.is_using:
			continue
		if is_instance_valid(obstacle):
			target_dir = global_position.direction_to(target_position)
			var obstacle_dir = global_position.direction_to(obstacle.global_position)
			# 防止NPC背后的物品阻碍判断
			var angle_ob = base_direction.angle_to(obstacle_dir)  # 范围：-π ~ π 弧度
			var angle_dob = rad_to_deg(angle_ob)  # 转换为度数：-180 ~ 180 度
			if abs(angle_dob) > 45:
				continue
			# 3. 计算两个方向向量的夹角（弧度），再转换为度数
			# 用于判断目标相对角色在哪边
			var angle_rad = base_direction.angle_to(target_dir)  # 范围：-π ~ π 弧度
			var angle_deg = rad_to_deg(angle_rad)  # 转换为度数：-180 ~ 180 度
			optimal_dir = _get_avoidance_direction(base_direction, angle_deg)
			avoiding_item = obstacle
			is_being_avoidance = true
			avoiding_direction = base_direction
			return optimal_dir
	avoiding_item = null
	avoiding_direction = ""
	is_being_avoidance = false
	return base_direction

# 确定避让方向函数
func _get_avoidance_direction(base_direction, angle_deg):
	# 判断障碍物在路径的哪一侧
	if angle_deg > 0:
		# 目标在右径侧，向右避让
		return Vector2(-base_direction.y, base_direction.x)
	else:
		# 目标在左径侧，向左避让
		return Vector2(base_direction.y, -base_direction.x)

# 碰到障碍物时，NPC的横坐标与目标的横坐标已经相同的情况（已通过其他方式解决，暂时没用到）
func need_swing_by():
	if is_being_avoiding and avoiding_item in side_obstacles:
		return true
	return false

# 特殊避障模式（暂时没用到）
func _avoid_obstacles():
	print(333)
	is_moving = true

# 尝试左右绕行（暂时没用到）
func _calculate_bypass_direction():
	pass
	## 尝试左右绕行
	#var forward = global_position.direction_to(navigation_agent.get_next_path_position())
	#var right = Vector2(forward.y, -forward.x)  # 垂直向量
	#var left = -right
	## 检查左右方向是否可行
	#var right_ray = _cast_direction_ray(right)
	#var left_ray = _cast_direction_ray(left)
	#if not right_ray.is_colliding():
		#return right
	#elif not left_ray.is_colliding():
		#return left
	#else:
		## 两个方向都有障碍，后退
		#return -forward

# 检查是否卡住
func _is_stuck(delta: float) -> bool:
	var position_change = global_position.distance_to(last_position)
	last_position = global_position
	if position_change < 1.0:  # 2像素内认为卡住
		stuck_timer += delta
		return stuck_timer > 2.0  # 卡住2秒以上
	else:
		stuck_timer = 0.0
		return false

# 卡住时的逃脱策略
func _escape_stuck_position(_delta):
	if interact_door != null:
		if not  interact_door.is_open:
			interact_door.is_open = !interact_door.is_open
			interact_door._update_door_visuals()
	print("因为卡顿改变为移动状态")
	current_state = NPCState.MOVING

# 执行移动状态下的行为
func _execute_move_behavior(delta):
	match current_state:
		NPCState.MOVING:
			move_target(delta)
		NPCState.AVOIDING:
			_avoid_obstacles()
		NPCState.STUCK:
			_escape_stuck_position(delta)

# 行为动画运行函数
func _execute_state_behavior():
	if is_being_action or is_working:
		return
	match current_state:
		NPCState.SLEEPING:
			print("开始睡觉")
			if nearest_object:
				nearest_object.sit_down()
				nearest_object.sit_area._player_sit()
				is_being_action = true
		NPCState.CLOCKIN:
			if nearest_object:
				nearest_object.open()
				animation_player.play("open_wardrobe")
				is_being_action = true
		NPCState.CLOCKOUT:
			if nearest_object:
				nearest_object.open()
				animation_player.play("open_wardrobe")
				is_being_action = true
		NPCState.WORKING:
			#print("开始工作")
			if nearest_object:
				if is_need_maintain:
					maintain_car()
					return
				if is_need_repair:
					repair_breakdown()
					return
				test_breakdown()
		NPCState.EATING:
			print("开始吃饭")
			if nearest_object:
				nearest_object.re_area.drink_item = "back"
				nearest_object.open_refrigerator()
				nearest_object.re_area._player_drink()
				is_being_action = true
		NPCState.DRINKING:
			print("开始恢复体力")
			if nearest_object:
				nearest_object.drink_area.drink_item = "left"
				nearest_object.drink_area._player_drink()
				is_being_action = true
		NPCState.IDLE:
			print("开始放松")
			animation_player.play("idle_right")
			# 休闲时可以随机走动
			_set_random_leisure_position()

# 检测汽车故障的原因
func test_breakdown():
	contine_working = true
	match test_count:
		6:
			open_close_hood()
		5:
			animation_player.play("check_left")
			is_working = true
		4:
			point_inspection_side()
		0:
			operate_enginery()
		1:
			point_inspection_under()
		2:
			judge_question()

# 判断车是否有问题，是否要保养和维修
func judge_question():
	if nearest_object:
		is_need_maintain = true
	if nearest_object:
		is_need_repair = true
	test_count = 0

# 汽车的维修保养
func maintain_car():
	contine_working = true
	match maintain_count:
		0:
			eliminate_oil()
		1:
			var tool_position = work_tool.marker.global_position
			var enginery_position = enginery.tool_place.global_position
			if put_toolcar(tool_position, enginery_position):
				return
			maintain_count += 1
		2:
			operate_enginery()
		3:
			pass


# 修理汽车的故障
func repair_breakdown():
	contine_working = true
	if nearest_object.need_open_hood:
		open_close_hood()
		return
	if nearest_object.need_add_oil:
		add_oil()
		return
	if nearest_object.need_replace_tires:
		return
	if nearest_object.need_repair_brake:
		return 

# 用于判断是否需要角色移动位置工作
func need_move_workplace(target):
	if $SitPlace.global_position != target:
		target_position = target
		navigation_agent.target_position = target_position
		print("need_move_workplace中的状态改变")
		next_state = current_state
		current_state = NPCState.MOVING
		return true
	return false

# 打开车前盖
func open_close_hood():
	var hood_position = nearest_object.car_upper.get_node("Marker2D").global_position
	if need_move_workplace(hood_position):
		return
	is_working = true
	if nearest_object.is_open_hood:
		# 这个if 正常用不到（暂时没想到用的地方），加个保险
		if nearest_object.need_open_hood:
			nearest_object.need_open_hood = false
			# 出现的可能有 没关车盖却需要打开车盖 或者 有想要关闭车盖行为却在任然需要打开车盖维修
			print("在JackMiller代码中，move_open_close_hood()函数里")
			return
		nearest_object.close_hood()
		animation_player.play("close_hood_left")
	else:
		nearest_object.open_hood()
		animation_player.play("open_hood_left")

# 运行相关机器
func operate_enginery():
	var renginery = null
	var objects = get_tree().get_nodes_in_group("switch")
	for ob in objects:
		if ob.link_item == nearest_object.parking_area.parking_item:
			renginery = ob
			break
	if renginery == null:
		print("operate_enginery()函数中的问题")
	var enginery_position = renginery.marker.global_position
	if need_move_workplace(enginery_position):
		return
	is_working = true
	animation_player.play("press_back")
	renginery.start_item()

# 进行定点检查车的侧面
func point_inspection_side():
	if points != []:
		_move_to_next_marker()
		return
	for child in nearest_object.check_points.get_children():
		if child is Marker2D:
			points.append(child)
	current_marker_index = 0
	_move_to_next_marker()

# 进行定点检查车底
func point_inspection_under():
	if points != []:
		_move_to_next_marker()
		return

	var objects = get_tree().get_nodes_in_group("parking")
	for ob in objects:
		if ob == nearest_object.parking_area.parking_item:
			enginery = ob
			break
	for child in enginery.check_points.get_children():
		if child is Marker2D:
			points.append(child)
	current_marker_index = 0
	_move_to_next_marker()

# 前往下一个检查点检查
func _move_to_next_marker():
	if current_marker_index >= points.size():
		# 所有标记点查看完成
		points = []
		test_count += 1
		print("查看完成")
		return
	var m_position = points[current_marker_index].global_position
	if need_move_workplace(m_position):
		return
	is_working = true
	animation_player.play("check")

# 把工具车放到指定位置
func put_toolcar(tool_position, enginery_position):
	if not work_tool.taking_area.is_using and need_move_workplace(tool_position):
		return true
	work_tool.taking_area.start_work()
	if need_move_workplace(enginery_position):
		return true
	if ahead_direction != "left":
		rotate_animation("left", "transport")
		return true
	work_tool.taking_area.finish_work()
	return false
		 
# 用接油器处理旧油
func eliminate_oil():
	work_tool = _find_nearest_object("oil_collector")
	var tool_position = work_tool.marker.global_position
	var enginery_position = enginery.eliminate_oil.global_position
	if put_toolcar(tool_position, enginery_position):
		return
	is_working = true
	animation_player.play("fix_under_car")


# 为汽车加油
func add_oil():
	var add_position = nearest_object.car_upper.get_node("Marker2D").global_position
	if need_move_workplace(add_position):
		return
	is_working = true
	animation_player.play("repair_add_oil_left")
	nearest_object.need_add_oil = false

# 休息随意走动函数（暂时没用,有点问题）
func _set_random_leisure_position():
	var random_offset = Vector2(randi_range(-100, 100), randi_range(-100, 100))
	target_position = home_position + random_offset
	navigation_agent.target_position = target_position
	#print("[DEBUG] 休闲目标位置: ", target_position)
	#print("[DEBUG] 导航代理当前目标: ", navigation_agent.target_position)
	#print("[DEBUG] 导航代理路径状态: ", navigation_agent.is_path_status())

# 确定移动的方向 
func make_direction(direction):
	if abs(direction.x) < abs(direction.y):
		if direction.y > 0:
			last_direction = "front"
		else:
			last_direction = "back"
	else:
		if direction.x < 0:
			last_direction = "left"
		else:
			last_direction = "right"
	if is_being_mufit:
		mufit_movement(last_direction)
		return
	_update_movement_animation(last_direction, move_state)

# 常服状态移动
func mufit_movement(direction):
	var cartoon = "walk_mufit_%s" % direction
	animation_player.animation = cartoon
	animation_player.play()

# 移动动画播放函数
func _update_movement_animation(direction, special_item):
	var cartoon
	match special_item:
		"":
			cartoon = "walk_%s" % direction
			animation_player.animation = cartoon
		"exhausted":
			cartoon = "tired_walk_%s" % direction
			animation_player.animation = cartoon
		"caryy":
			if rotate_animation(direction, special_item):
				return
			cartoon = "carry_%s" % direction
			animation_player.animation = cartoon
		"drink":
			synch_stuff_animation("walk", direction)
			cartoon = "drink_walk_%s" % direction
			animation_player.animation = cartoon
		"drinking":
			cartoon = "drinking_walk_%s" % direction
			animation_player.animation = cartoon
		"jack":
			cartoon = "jack_transport_walk_%s" % direction
			animation_player.animation = cartoon
		"transport":
			if rotate_animation(direction, special_item):
				return
			cartoon = "transport_%s" % direction
			animation_player.animation = cartoon
		"run":
			cartoon = "run_%s" % direction
			animation_player.animation = cartoon
	animation_player.play()

# 协同物品移动动画播放函数
func synch_stuff_animation(condition, direction):
	taking.play_animation(condition, direction)

# 是否与当前方向相对
func _is_opposite_direction(direction):
	# 检查两个方向是否相反（上下左右四个方向）
	return (ahead_direction == "left" and direction == "right") or \
		(ahead_direction == "right" and direction == "left") or \
		(ahead_direction == "front" and direction == "back") or \
		(ahead_direction == "back" and direction == "front")

# 特殊移动转向函数
func rotate_animation(direction, special_item):
	if ahead_direction == "" or ahead_direction == direction:
		ahead_direction = direction
		return false
	var cartoon
	if _is_opposite_direction(direction):
		print("进行播放与实际前进方向相反")
		cartoon = special_item + "_" + ahead_direction
		animation_player.play(cartoon)
		return true
	current_state = NPCState.ROTATE
	match special_item:
		"caryy":
			cartoon = "carry_rotate_" + ahead_direction + "-" + direction
			work_tool.play_animation(ahead_direction, direction)
			animation_player.animation = cartoon
		"transport":
			cartoon = "transport_rotate_" + ahead_direction + "-" + direction
			work_tool.play_animation(ahead_direction, direction)
			animation_player.animation = cartoon
	animation_player.play()
	ahead_direction = direction
	return true

# 寻找并移动到最近指定物品
func find_and_move_on_object(object):
	nearest_object = _find_nearest_object(object)
	if nearest_object:
		_move_to_target(nearest_object)
	else:
		print("没有找到可用的" + object)

# 查找指定的最近物品
func _find_nearest_object(object):
	var objects = get_tree().get_nodes_in_group(object)
	var nearest_ob: StaticBody2D = null # 最近的物品
	var min_distance: float = INF # 暂存的最小距离
	for ob in objects:
		# 检查物品是否已被占用
		if ob.has_method("is_occupied") and ob.is_occupied():
			continue
		var distance = global_position.distance_to(ob.global_position)
		if distance < min_distance:
			min_distance = distance
			nearest_ob = ob
	return nearest_ob

# 使角色移动到目标位置
func _move_to_target(target: StaticBody2D):
	# 设置导航目标（如沙发前方一点的位置）
	var sit_position = target.marker.global_position # 物品前前位置
	target_position = sit_position
	navigation_agent.target_position = sit_position

# 进行的动作（用于让其他交互物脚本调用）
func play_animation(condition, direction):
	var cartoon
	if condition == "sit":
		cartoon = "sit_%s" % direction
		animation_player.animation = cartoon
		animation_player.play()
	elif condition == "fridge":
		cartoon = "fridge_%s" % direction
		synch_stuff_animation(condition, direction)
		animation_player.animation = cartoon
		animation_player.play()
	elif condition == "work":
		cartoon = "repair_%s" % direction
		animation_player.animation = cartoon
		animation_player.play()
	elif condition == "transport":
		ahead_direction = direction
		item_direction = direction
		move_state = condition
	elif condition == "drink":
		if is_have_bottle:
			cartoon = "drinkwater_bottle_%s" % direction
		else:
			cartoon = "drinkwater_%s" % direction
		animation_player.animation = cartoon
		animation_player.play()
	elif condition == "idle":
		move_state = ""
		return
	else:
		print("特殊动作动画有问题")

# 开始等待
func start_waiting(style, duration):
	next_state = current_state
	current_state = NPCState.WAITING
	wait_duration = duration
	# 播放等待动画
	animation_player.play(style)
	# 启动计时器
	wait_timer.start(wait_duration)

# 体力消耗
func consume_stamina(delta, amount: float):
	stamina_timer += delta
	if stamina_timer >= stamina_loss_rate:
		stamina_timer = 0.0
		print(amount)
		stamina = max(stamina - amount, 0)
		update_states()

# 立即恢复一定的体力
func relax_stamina(amount: float):
	stamina = min(stamina + amount, max_stamina)
	update_states()

# 疲惫、力竭与常态转换函数
func update_states():
	if stamina == 0:
		is_burnout = true
		is_exhausted = false
	elif stamina < 20 and stamina > 0 and not is_exhausted:
		is_exhausted = true
		is_burnout = false
		move_state = "exhausted"
	elif stamina >= 20 and is_exhausted:
		is_exhausted = false
		is_burnout = false
		move_state = ""
	update_speed()

# 更新当前速度
func update_speed():
	if is_burnout or is_exhausted:
		speed = tired_speed
	else:
		speed = normal_speed

# 连接信号函数
func _on_velocity_computed(_safe_velocity: Vector2):
	pass
	## 应用安全速度（已避开障碍物）
	#velocity = safe_velocity
	#move_and_slide()

func _on_target_reached():
	print("到达目的地，进行状态改变")
	current_state = next_state
	next_state = null
	is_being_avoiding = false
	# 这里可以触发到达目标后的行为
	pass

func _on_interaction_area_entered(_area):
	pass

func _on_interaction_area_exited(_area):
	pass

# 障碍物检测信号
func _on_wigwag_detected(body: Node2D):
	if body != self and body is StaticBody2D:  # 只检测静态障碍物
		if not body in wigwag_obstacles:
			wigwag_obstacles.append(body)

func _on_wigwag_exited(body: Node2D):
	if body in wigwag_obstacles:
		wigwag_obstacles.erase(body)

func _on_sway_detected(body: Node2D):
	if body != self and body is StaticBody2D:  # 只检测静态障碍物
		if not body in sway_obstacles:
			sway_obstacles.append(body)

func _on_sway_exited(body: Node2D):
	if body in sway_obstacles:
		sway_obstacles.erase(body)

func _on_interact_entered(area):
	var parent = area.get_parent()
	if parent.is_in_group("in_door"):
		interact_door = parent

func _on_interact_exited(area):
	var parent = area.get_parent()
	if parent.is_in_group("in_door"):
		interact_door = null

# 等待结束，回到空闲状态或执行其他行动
func _on_wait_finished():
	print("等待结束，进行状态改变")
	current_state = next_state
	next_state = null
	## 可以在这里触发后续行动
	#_on_wait_completed()

# 一段动画播完后的行为函数
func _on_animation_finished():
	var current_anim = animation_player.animation
	if is_need_maintain or is_need_repair:
		maintain_paly_finished(current_anim)
	else:
		test_paly_finished(current_anim)
	if current_anim.begins_with("drinkwater_"):
		is_relaxing = false
	if "rotate" in current_anim: 
		direction_taking.position = animation_positions[anim_rotate][0]
		print("转弯结束，状态改变")
		current_state = NPCState.MOVING
	if "repair" in current_anim:
		is_working = false
	match current_anim:
		"fridge_back":
			# 拿取完饮料后播放动画
			synch_stuff_animation("fridge", "back_end_left")
			animation_player.play("fridge_back_end_left")
		"fridge_back_end_left":
			move_state = "drink"
		"open_wardrobe":
			if current_state == NPCState.CLOCKIN:
				animation_player.play("strip_mufit")
			if current_state == NPCState.CLOCKOUT: 
				animation_player.play("strip")
		"strip_mufit":
			animation_player.play("dressing")
		"strip": 
			animation_player.play("dressing_mufit")
		"dressing":
			nearest_object.close()
			if current_state == NPCState.CLOCKIN:
				animation_player.play("close_wardrobe")
				is_being_mufit = false
			if current_state == NPCState.CLOCKOUT: 
				animation_player.play("close_wardrobe")
				is_being_mufit = true

# 测试相关的动画播放后的行为函数
func test_paly_finished(current_anim):
	if current_anim.begins_with("open_hood_"):
		test_count += 1
		is_working = false
	if current_anim.begins_with("close_hood_"):
		test_count += 2
		is_working = false
	if current_anim.begins_with("check_"):
		test_count -= 1
		is_working = false
	if current_anim.begins_with("press_"):
		test_count += 1
		is_working = false
	if current_anim == "check":
		current_marker_index += 1
		is_working = false

# 维修相关的动画播放后的行为函数
func maintain_paly_finished(current_anim):
	if current_anim == "fix_under_car":
		maintain_count += 1
		is_working = false
		start_waiting("repair_idle_left", 7)

# 使对应位置点跟随动画播放而改变
func _update_marker_position():
	var anims = animation_player.animation
	if not "-" in anims:
		return
	anim_rotate = anims.rsplit("_", true, 1)[1]  # 最后一个下滑线后的内容
	var frame = animation_player.frame
	if animation_positions.has(anim_rotate) and frame < animation_positions[anim_rotate].size():
		direction_taking = self.get_node("TakingCart").get_node(item_direction)
		direction_taking.position = animation_positions[anim_rotate][frame]
		print(direction_taking.position)
