extends CharacterBody2D

@onready var anim := $AnimatedSprite2D
@onready var collision = $CollisionShape2D

# 状态参数
var max_stamina: float = 100.0 #最大体力
var stamina = max_stamina
var is_working: bool = false #标记角色是否在工作
var is_exhausted: bool = false #标记角色是否疲惫状态
var is_burnout: bool = false #标记是否力竭
# 移动参数
var vel = Vector2.ZERO
var normal_speed = 150 # 正常速度
var tired_speed = 30 # 疲惫速度
var speed = normal_speed # 当前速度
# 动画状态
var last_direction = "right" #记录最后的朝向
var is_playing_work_animation = false #是否在播放工作动画
var is_playing_relax_animation = false #是否在播放休息动画
var is_palying_sit_animation = false # 是否正坐着
var is_palying_drink_animation = false # 是否在喝
# 交互系统
var screen_size
var near_repairable_object = null
var sdirection = "" # 记录动作的方向
# 体力消耗/恢复参数
var stamina_timer := 0.0 
var stamina_loss_rate := 0.5 # 每 1 秒扣 1 点
var work_stamina_cost: float = 20.0 #每次工作消耗量
var stamina_regen_rate: float = 25.0  # 每秒恢复体力量

func _ready() -> void:
	screen_size = get_viewport_rect().size
	add_to_group("player")
	update_speed()
	if not has_node("Interaction"):
		setup_interaction_area()
	anim.animation_finished.connect(_on_animation_finished)
	#hide()

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

func _process(_delta):
	# 层级
	z_index = clamp($ShelterBase.global_position.y, -1000, 10000)

func _physics_process(delta):
	# 体力系统更新
	update_stamina(delta)
	# 移动处理
	handle_movement(delta)
	# 碰撞处理
	handle_collisions()
	# 小物体推动处理
	push_few_item(delta)

# 自动工作/休息函数
func update_stamina(delta):
	if is_working:
		consume_stamina(delta, work_stamina_cost * delta)
		if stamina == 0:
			stop_work()
	elif is_playing_relax_animation:
		slow_relax_stamina(delta, stamina_regen_rate * delta)
		if stamina == max_stamina:
			stop_relax()

# 移动处理函数
func handle_movement(delta):
	var input_vector = Vector2.ZERO
	if not is_playing_work_animation and not is_playing_relax_animation:
		if not is_palying_sit_animation and not is_palying_drink_animation:
			input_vector.x = Input.get_action_strength("right") - Input.get_action_strength("left")
			input_vector.y = Input.get_action_strength("down") - Input.get_action_strength("up")
	if input_vector != Vector2.ZERO:
		consume_stamina(delta, 1)
	vel = input_vector.normalized() * speed
	position += vel * delta
	move_and_slide()
	# 更新动画
	update_animation(input_vector)

# 碰撞处理函数
func handle_collisions():
	for i in get_slide_collision_count():
		var collision1 = get_slide_collision(i)
		if collision1.get_collider().is_in_group("repairable"):
			# 轻微推开玩家防止重叠
			var push_force = vel.length() * 0.8  # 使用80%的当前速度作为推力
			position -= collision1.get_normal() * push_force * get_physics_process_delta_time()

# 动画处理函数
func update_animation(direction: Vector2):
	if is_playing_work_animation:
		$AnimatedSprite2D.animation = "beat"
		$AnimatedSprite2D.play()
		return
	elif is_playing_relax_animation:
		$AnimatedSprite2D.animation = "recover"
		$AnimatedSprite2D.play()
		return
	elif is_palying_sit_animation:
		var cartoon = "sit_%s" % sdirection
		$AnimatedSprite2D.animation = cartoon
		$AnimatedSprite2D.play()
		return
	elif is_palying_drink_animation:
		var cartoon = "drink_%s" % sdirection
		$AnimatedSprite2D.animation = cartoon
		$AnimatedSprite2D.play()
		return
	elif direction.length() > 0:
		handle_movement_animation(direction)
	else:
		handle_idle_animation()

# 移动动画处理函数
func handle_movement_animation(direction: Vector2):
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

# 静止动画处理函数
func handle_idle_animation():
	if is_exhausted or is_burnout:
		$AnimatedSprite2D.animation = "tired"
	else:
		match last_direction:
			"left":
				$AnimatedSprite2D.animation = "idle_left"
			"right":
				$AnimatedSprite2D.animation = "idle_right"

func set_animation_based_on_state(normal_anim: String, tired_anim: String):
	#if sdirection == "move":
		#$AnimatedSprite2D.animation = "transport_left"
	if is_exhausted or is_burnout:
		$AnimatedSprite2D.animation = tired_anim
	else:
		$AnimatedSprite2D.animation = normal_anim
	$AnimatedSprite2D.play()

# 进行的动作
func play_animation(condition, direction):
	sdirection = direction
	if condition == "sit":
		is_palying_sit_animation = true
	elif condition == "drink" or condition == "fridge":
		is_palying_drink_animation = true
	elif condition == "idle":
		is_palying_sit_animation = false
		is_palying_drink_animation = false
	else:
		print("特殊动作动画有问题")

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

# 工作/休息控制
func start_work():
	if is_burnout or is_working:
		return false
	is_working = true
	is_playing_work_animation = true
	return true

func stop_work():
	is_working = false
	is_playing_work_animation = false
	
func start_relax():
	if not is_working:
		is_playing_relax_animation = true

func stop_relax():
	is_playing_relax_animation = false

# 体力消耗
func consume_stamina(delta, amount: float):
	stamina_timer += delta
	if stamina_timer >= stamina_loss_rate:
		stamina_timer = 0.0
		stamina = max(stamina - amount, 0)
		update_states()

# 立即恢复一定的体力
func relax_stamina(amount: float):
	stamina = min(stamina + amount, max_stamina)
	update_states()

# 缓慢体力恢复
func slow_relax_stamina(delta, amount: float):
	stamina_timer += delta
	if stamina_timer >= stamina_loss_rate:
		stamina_timer = 0.0
		stamina = min(stamina + amount, max_stamina)
		update_states()

# 推动小物体
func push_few_item(delta):
	var push_vector = vel * delta * 2
	var pushed_items := []  # 存储已被推动的书，防止重复
	var queue := []         # 推动传播队列
	for body in get_slide_collision_count():
		var collision1 = get_slide_collision(body)
		var collider = collision1.get_collider()
		if collider and collider.is_in_group("dragers") and not collider.is_being_dragged:
			if collider.has_meta("item_type") and collider.get_meta("item_type") == "object":
				queue.append(collider)
	while not queue.is_empty():
		var item = queue.pop_front()
		if item in pushed_items:
			continue
		# 尝试推动前先模拟下一位置
		var simulated_pos = item.global_position + push_vector
		# 暂存当前位置信息
		var old_pos = item.global_position
		item.global_position = simulated_pos
		if item.judge_push_area():
			pass
		else:
			item.global_position = old_pos
		pushed_items.append(item)
		# 查找当前书碰到的其他书，也放入队列
		for other in get_tree().get_nodes_in_group("dragers"):
			if other.has_meta("item_type") and other.get_meta("item_type") == "object":
				if other == item or other.is_being_dragged or other in pushed_items:
					continue
				if item.get_put_rect().intersects(other.get_put_rect()):
					queue.append(other)

func _input(_event):
	# 进行工作事件
	if Input.is_action_just_pressed("work"):
		print("===== work按键触发 =====")
		print("当前near_repairable_object:", near_repairable_object)
		if near_repairable_object:
			print("可修复物体名称:", near_repairable_object.name)
			print("玩家体力:", stamina)
			print("物体状态 - player_in_range:", near_repairable_object.player_in_range)
			print("物体状态 - is_repairing:", near_repairable_object.is_repairing)
			print("物体状态 - health:", near_repairable_object.health)
			print("物体最大生命值:", near_repairable_object.max_health)
			if start_work():
				if near_repairable_object.start_repair(self):
					print("开始工作")
				else:
					stop_work()
			else:
				print("体力耗尽，无法工作")
	## 进行休息事件
	#if Input.is_action_just_pressed("relax") and stamina < max_stamina:
		#start_relax()
	#elif Input.is_action_just_pressed("relax") and stamina == max_stamina:
		#print("体力已满，无需休息")

# 信号连接函数
func _on_interaction_area_entered(body) -> void:
	#print("物体所属组:", body.get_groups())
	#print("进入交互区域，物体路径:", body.get_path())
	var repair_object = body.get_parent()
	if repair_object.is_in_group("repairable"):
		near_repairable_object = repair_object
		print("找到可修复物体:", near_repairable_object.name)
		print("根节点所属组:", repair_object.get_groups())

func _on_interaction_area_exited(body) -> void:
	var repair_object = body.get_parent()
	if repair_object == near_repairable_object:
		near_repairable_object = null
		stop_work()

func _unhandled_input(event):
	if event.is_action_pressed("Esc"):
		var settings_ui = get_tree().get_first_node_in_group("settings_ui")
		if settings_ui:
			settings_ui.toggle_visible()

func _on_animation_finished():
	if anim.animation == "drink_water" or anim.animation == "drink_drinks":
		is_palying_drink_animation = false
