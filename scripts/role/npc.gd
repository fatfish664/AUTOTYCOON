extends CharacterBody2D

# NPC的状态
enum NPCState {
	SLEEPING, #睡觉
	WORKING, #工作
	EATING, #吃饭
	IDLE, # 待机
	MOVING, #移动
	AVOIDING, #回避
	STUCK, #卡住
}

@export var home_position: Vector2 = Vector2(800, 200)
@export var detection_radius: float = 100.0
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var animation_player: AnimatedSprite2D = $AnimatedSprite2D
@onready var obstacle_detector: Area2D = $ObstacleDetector
@onready var interact: Area2D = $Interact
@onready var collision = $CollisionShape2D

# 移动参数
#var vel = Vector2.ZERO
var normal_speed = 100.0 # 正常速度
var tired_speed = 50.0 # 疲惫速度
var speed = normal_speed # 当前速度
# 避障相关
var nearby_obstacles: Array = [] # 障碍物集合
#var immediate_obstacle: Node2D = null 
var stuck_timer: float = 0.0  # 相同位置的停留时间
var last_position: Vector2 = Vector2.ZERO  # 之前的位置，用于判断是否在停留
var ignore_angle: float = 45.0  # 忽略角度阈值（度）
var target_dir # 目的地对于NPC的方位
# NPC作息表（字典）
var current_state: NPCState = NPCState.IDLE
var schedule = {
	# 格式: 开始时间: [状态, 持续时间(分钟), 目标位置(可选)]
	0: NPCState.SLEEPING,
	7: NPCState.WORKING,   # 7:00-11:00 工作
	11: NPCState.WORKING,    # 11:00-11:30 吃饭
	11.5: NPCState.SLEEPING,  # 11:30-14:00 休息
	14: NPCState.SLEEPING,  # 14:00-18:30 上班
	18.5: NPCState.WORKING,  # 18:30-19:00 吃饭
	19: NPCState.WORKING,    # 19:00-23:00 休闲
	23: NPCState.WORKING,   # 23:00-7:00 睡觉
	24: NPCState      # 因为逻辑问题，留下
}
# 进行活动参数
var next_state = null # 用于辅助确定下一个活动
var nearest_object # 离NPC最近的物品
var target_position: Vector2  # 目的地
var is_moving: bool = false  # 是否正在移动
var last_direction = "right" # 默认朝右
var is_being_work = false # 是否在进行行为动画
var interact_door = null # 用于交互的物品
# 状态参数
var max_stamina: float = 100.0 #最大体力
var stamina = max_stamina
var is_working: bool = false #标记角色是否在工作
var is_exhausted: bool = false #标记角色是否疲惫状态
var is_burnout: bool = false #标记是否力竭
# 体力消耗/恢复参数
var stamina_timer := 0.0 
var stamina_loss_rate := 1.0 # 每 1 秒扣 1 点
var work_stamina_cost: float = 20.0 #每次工作消耗量
var stamina_regen_rate: float = 25.0  # 每秒恢复体力量

func _ready():
	add_to_group("NPC")
	# 等待一帧确保 NavigationServer 就绪
	await get_tree().process_frame
	if not has_node("Interaction"):
		setup_interaction_area()
	# 行走过程运行的函数
	#navigation_agent.velocity_computed.connect(_on_velocity_computed)
	# 到达位置后，运行的函数
	navigation_agent.target_reached.connect(_on_target_reached)
	obstacle_detector.body_entered.connect(_on_obstacle_detected)
	obstacle_detector.body_exited.connect(_on_obstacle_exited)
	interact.area_entered.connect(_on_interact_entered)
	interact.area_exited.connect(_on_interact_exited)
	# 配置障碍物检测
	obstacle_detector.monitoring = true

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
	if next_activity == null:
		return
	if next_state != null and current_state == NPCState.STUCK:
		return
	if current_state == next_activity:
		return
	finish_activity()
	is_being_work = false
	current_state = next_activity

#完成活动后进行处理函数
func finish_activity():
	if not nearest_object:
		return
	if current_state == NPCState.WORKING:
		nearest_object.work_area.finish_work()
	if current_state == NPCState.SLEEPING:
		nearest_object.stand_up()
		nearest_object.sit_area._player_stand()

# 寻找目标
func find_target():
	if is_being_work:
		return
	var change_target = false
	if current_state == NPCState.SLEEPING:
		find_and_move_on_object("sofa")
		change_target = true
	if current_state == NPCState.WORKING:
		find_and_move_on_object("work_place")
		change_target = true
	if change_target:
		next_state = current_state
		current_state = NPCState.MOVING

# 根据状态移动到相应位置
func move_target(delta):
	is_moving = true
	if navigation_agent.is_navigation_finished():
		is_moving = false
		return
	var next_position = navigation_agent.get_next_path_position()
	var direction = (next_position - global_position).normalized()
	consume_stamina(delta, 1)
	velocity = direction * speed
	# 应用障碍物避让
	velocity = _apply_obstacle_avoidance(velocity)
	# 让导航系统处理最终速度
	navigation_agent.set_velocity(velocity)
	# 根据移动方向更新动画
	_update_movement_animation(direction)
	move_and_slide()
	# 检查前方障碍物
	#if _has_immediate_obstacle():
		#current_state = NPCState.AVOIDING
	if _is_stuck(delta):
		current_state = NPCState.STUCK

# 应用障碍物避让
func _apply_obstacle_avoidance(base_velocity: Vector2) -> Vector2:
	var avoidance_velocity = base_velocity
	# 动态避障：检查附近障碍物
	for obstacle in nearby_obstacles:
		if is_instance_valid(obstacle):
			target_dir = global_position.direction_to(target_position)
			var obstacle_dir = global_position.direction_to(obstacle.global_position)
			var distance = global_position.distance_to(obstacle.global_position)
			var target_distance = global_position.distance_to(target_position)
			# 3. 计算两个方向向量的夹角（弧度），再转换为度数
			var angle_rad = base_velocity.angle_to(obstacle_dir)  # 范围：-π ~ π 弧度
			var angle_deg = rad_to_deg(angle_rad)  # 转换为度数：-180 ~ 180 度
			if distance > target_distance:
				continue
			if angle_deg < -45 or angle_deg > 45:
				continue
			var optimal_dir = _get_optimal_avoidance_direction(obstacle_dir, angle_deg)
			var repulsion = optimal_dir * speed
			avoidance_velocity = repulsion
			return avoidance_velocity
	return base_velocity

# 确定避让方向函数
func _get_optimal_avoidance_direction(obstacle_dir, angle_deg):
	# 判断障碍物在路径的哪一侧
	if angle_deg < 0:
		# 障碍物在路径右侧，向左避让
		return Vector2(-obstacle_dir.y, obstacle_dir.x)
	else:
		# 障碍物在路径左侧，向右避让
		return Vector2(obstacle_dir.y, -obstacle_dir.x)

# 紧急避障模式（暂时没用到）
func _avoid_obstacles():
	# 紧急避障模式
	var avoidance_direction = Vector2.ZERO
	# 计算所有障碍物的合排斥方向
	for obstacle in nearby_obstacles:
		if is_instance_valid(obstacle):
			var to_obstacle = obstacle.global_position - global_position
			var distance = to_obstacle.length()
			if distance < detection_radius * 0.5:  # 近距离障碍物
				avoidance_direction -= to_obstacle.normalized() * (1.0 - distance / detection_radius)
	# 如果没有明显的排斥方向，尝试绕行
	if avoidance_direction.length() < 0.1:
		avoidance_direction = _calculate_bypass_direction()
	# 应用避障速度
	velocity = avoidance_direction.normalized() * speed
	move_and_slide()

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
	current_state = NPCState.MOVING

# 执行移动状态下的行为
func _execute_move_behavior(delta):
	match current_state:
		NPCState.MOVING:
			move_target(delta)
		#NPCState.AVOIDING:
			#_avoid_obstacles()
		NPCState.STUCK:
			_escape_stuck_position(delta)

# 行为动画运行函数
func _execute_state_behavior():
	if is_being_work:
		return
	match current_state:
		NPCState.SLEEPING:
			print("开始睡觉")
			if nearest_object:
				nearest_object.sit_down()
				nearest_object.sit_area._player_sit()
				is_being_work = true
		NPCState.WORKING:
			print("开始工作")
			if nearest_object:
				nearest_object.work_area.start_work()
				animation_player.play("work")
				is_being_work = true
		NPCState.EATING:
			print("开始吃饭")
			animation_player.play("recover")
			is_being_work = true
		NPCState.IDLE:
			print("开始放松")
			animation_player.play("idle_right")
			# 休闲时可以随机走动
			_set_random_leisure_position()

# 休息随意走动函数（暂时没用）
func _set_random_leisure_position():
	var random_offset = Vector2(randi_range(-100, 100), randi_range(-100, 100))
	target_position = home_position + random_offset
	navigation_agent.target_position = target_position
	#print("[DEBUG] 休闲目标位置: ", target_position)
	#print("[DEBUG] 导航代理当前目标: ", navigation_agent.target_position)
	#print("[DEBUG] 导航代理路径状态: ", navigation_agent.is_path_status())
 
# 移动动画播放函数
func _update_movement_animation(direction: Vector2):
	# 确定主要移动方向
	if abs(direction.x) < abs(direction.y):
		if direction.y < 0:
			set_animation_based_on_state("up", "tired_up")
		else:
			set_animation_based_on_state("down", "tired_down")
	else:
		if direction.x < 0:
			set_animation_based_on_state("left", "tired_left")
			last_direction = "left"
		else:
			set_animation_based_on_state("right", "tired_right")
			last_direction = "right"

func set_animation_based_on_state(normal_anim: String, tired_anim: String):
	if is_exhausted or is_burnout:
		$AnimatedSprite2D.animation = tired_anim
	else:
		$AnimatedSprite2D.animation = normal_anim
	$AnimatedSprite2D.play()

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
	if condition == "sit":
		var cartoon = "sit_%s" % direction
		$AnimatedSprite2D.animation = cartoon
		$AnimatedSprite2D.play()
	elif condition == "fridge":
		$AnimatedSprite2D.animation = "drink"
		$AnimatedSprite2D.play()
	elif condition == "work":
		$AnimatedSprite2D.animation = "work"
		$AnimatedSprite2D.play()
	elif condition == "idle":
		return
	else:
		print("特殊动作动画有问题")

# 体力消耗
func consume_stamina(delta, amount: float):
	stamina_timer += delta
	if stamina_timer >= stamina_loss_rate:
		stamina_timer = 0.0
		print(amount)
		stamina = max(stamina - amount, 0)
		update_states()

# 疲惫、力竭与常态转换函数
func update_states():
	if stamina == 0:
		is_burnout = true
		is_exhausted = false
	elif stamina < 20 and stamina > 0 and not is_exhausted:
		is_exhausted = true
		is_burnout = false
	elif stamina >= 20 and is_exhausted:
		is_exhausted = false
		is_burnout = false
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
	current_state = next_state
	print("NPC 已到达目标位置")
	# 这里可以触发到达目标后的行为
	pass

func _on_interaction_area_entered(_area):
	pass

func _on_interaction_area_exited(_area):
	pass

# 障碍物检测信号
func _on_obstacle_detected(body: Node2D):
	if body != self and body is StaticBody2D:  # 只检测静态障碍物
		if not body in nearby_obstacles:
			nearby_obstacles.append(body)

func _on_obstacle_exited(body: Node2D):
	if body in nearby_obstacles:
		nearby_obstacles.erase(body)

func _on_interact_entered(area):
	var parent = area.get_parent()
	if parent.is_in_group("in_door"):
		interact_door = parent

func _on_interact_exited(area):
	var parent = area.get_parent()
	if parent.is_in_group("in_door"):
		interact_door = null
