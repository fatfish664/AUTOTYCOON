extends Area2D

#@onready var sofa_sit_place = $SitPlace
var player_in_range := false # 判断角色是否靠近
var player_ref: Node = null # 记录角色的节点
#@export var move_distance: float = 10.0   # 向上移动的距离
#@export var move_duration: float = 2.0     # 移动所需时间（秒）
var is_moving := false

func _ready():
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)

func _process(_delta):
	if not DragManager.is_edit_mode:
		if player_in_range and Input.is_action_just_pressed("interact"):
			if is_moving:
				finish_work()
			else:
				start_work()

# 开始/结束工作函数
func start_work():
	var parent = get_parent()
	var pit_have_car = parent.pit_have_car
	var car = parent.car
	var car_tire = parent.car_tire
	var car_tire2 = parent.car_tire2
	if is_moving:
		return
	parent.is_occupy = true
	is_moving = true
	# 安全获取节点引用
	# 创建主 Tween 序列
	var main_tween = create_tween()
	main_tween.set_parallel(false)  # 顺序执行
	# 第一阶段：pit_have_car 上移9像素（1秒）
	main_tween.tween_property(pit_have_car, "position",
	pit_have_car.position + Vector2(0, -9), 1.0)
	# 第二阶段：延迟1秒后，car和pit_have_car同时上移2像素（0.2秒）
	main_tween.tween_interval(1.0)  # 使用tween间隔替代await timer
	main_tween.tween_callback(_create_parallel_tween.bind([
		{"node": car, "offset": Vector2(0, -2), "duration": 0.2},
		{"node": pit_have_car, "offset": Vector2(0, -2), "duration": 0.2}
	]))
	# 第三阶段：延迟0.2秒后，所有元素上移8像素（1.8秒）
	main_tween.tween_interval(0.2)
	main_tween.tween_callback(_create_parallel_tween.bind([
		{"node": car_tire, "offset": Vector2(0, -8), "duration": 1.8},
		{"node": car_tire2, "offset": Vector2(0, -8), "duration": 1.8},
		{"node": car, "offset": Vector2(0, -8), "duration": 1.8},
		{"node": pit_have_car, "offset": Vector2(0, -8), "duration": 1.8}
	]))

func finish_work():
	var parent = get_parent()
	var pit_have_car = parent.pit_have_car
	var car = parent.car
	var car_tire = parent.car_tire
	var car_tire2 = parent.car_tire2
	if not is_moving:
		return
	is_moving = false
	parent.is_occupy = false
	# 创建主 Tween 序列（反向执行工作动画）
	var return_tween = create_tween()
	return_tween.set_parallel(false)
	# 第一阶段：所有元素下移8像素（1.8秒） - 对应工作阶段的第三阶段
	return_tween.tween_callback(_create_parallel_tween.bind([
		{"node": car_tire, "offset": Vector2(0, 8), "duration": 1.8},
		{"node": car_tire2, "offset": Vector2(0, 8), "duration": 1.8},
		{"node": car, "offset": Vector2(0, 8), "duration": 1.8},
		{"node": pit_have_car, "offset": Vector2(0, 8), "duration": 1.8}
	]))
	# 第二阶段：延迟0.2秒后，car和pit_have_car下移2像素（0.2秒）
	return_tween.tween_interval(0.2)
	return_tween.tween_callback(_create_parallel_tween.bind([
		{"node": car, "offset": Vector2(0, 2), "duration": 0.2},
		{"node": pit_have_car, "offset": Vector2(0, 2), "duration": 0.2}
	]))
	
	# 第三阶段：延迟1秒后，pit_have_car下移9像素（1秒）回到完全原始位置
	return_tween.tween_interval(1.0)
	return_tween.tween_property(pit_have_car, "position", 
		pit_have_car.position + Vector2(0, 18), 1.0) # 还有点问题，没移到原位
	
	# 最终阶段：所有元素完全回到原始位置

# 创建并行动画组
func _create_parallel_tween(animations: Array):
	var parallel_tween = create_tween()
	parallel_tween.set_parallel(true)  # 并行执行
	for anim_data in animations:
		if is_instance_valid(anim_data.node):
			var target_position = anim_data.node.position + anim_data.offset
			parallel_tween.tween_property(anim_data.node,
			"position", target_position, anim_data.duration)

# 信号连接，进入/进出函数
func _on_body_entered(body):
	if body.name == "Player":
		player_in_range = true
		player_ref = body

func _on_body_exited(body):
	if body.name == "Player":
		player_in_range = false
		player_ref = null
