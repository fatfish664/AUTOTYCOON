extends StaticBody2D
var max_health: float = 100.0
var repair_amount: int = 10  # 每次修理恢复的生命值
var repair_one_time: float = 2.0  # 一次修理需要的时间
var stamina_cost: float = 20.0 # 每次修理消耗的体力
var health: float
var player_in_range: bool = false # 玩家是否在范围内
var is_repairing: bool = false # 是否正在修复

# 生命条相关变量
var health_bar: TextureProgressBar = null
var repair_progress_bar: TextureProgressBar = null
var ui_container: Control = null

func _ready():
	health = max_health / 2.0
	init_health_ui()
	update_health_display()
	# 创建碰撞体
	var collision = CollisionShape2D.new()
	collision.shape = RectangleShape2D.new()
	collision.shape.extents = Vector2(20, 20)
	add_child(collision)
	if not has_node("Interaction"):
		setup_interaction_area()
	add_to_group("repairable")
	print("可修复物体已加入组:", get_groups())

func setup_interaction_area():
	# 创建交互区域（比碰撞体稍大）
	var area = Area2D.new()
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.extents = Vector2(25, 25)
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_interaction_area_entered)
	area.body_exited.connect(_on_interaction_area_exited)
	
func _process(delta):
	update_ui_position()
	if is_repairing:
		repair(repair_amount * delta)
		update_health_display()
		if health == max_health:
			complete_repair()
		if repair_progress_bar:
			repair_progress_bar.visible = true
			repair_progress_bar.value += delta
	else:
		if repair_progress_bar:
			repair_progress_bar.visible = false

# 修复流程控制
func start_repair(player):
	if player_in_range and not is_repairing and health < max_health:
		if player.stamina >= stamina_cost:
			is_repairing = true
			return true
	return false

# 进行修复函数
func repair(amount: float):
	health = min(health + amount, max_health)

#修复完成函数
func complete_repair():
	is_repairing = false
	get_tree().call_group("player", "stop_work")
	print("修理完成")

# 修理中断函数
func interrupt_repair():
	is_repairing = false
	get_tree().call_group("player", "stop_work")
	print("修理中断")

func init_health_ui():
	"""初始化生命条UI，确保节点存在"""
	# 如果没有UI节点，创建一个
	if not has_node("UI"):
		create_health_ui()
	if has_node("UI"):
		ui_container = $UI
		ui_container.visible = true  # 确保UI可见     
		if has_node("UI/HealthBar"):
			health_bar = $UI/HealthBar
			health_bar.max_value = 100
			health_bar.visible = true
	else:
		print("警告：未找到UI节点，生命条无法显示")
	
	if has_node("UI/RepairProgressBar"):
		repair_progress_bar = $UI/RepairProgressBar
		repair_progress_bar.max_value = repair_one_time
		repair_progress_bar.visible = false

func create_health_ui():
	var ui = Control.new()
	ui.name = "UI"
	add_child(ui)
	health_bar = TextureProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.vertical = false
	health_bar.rect_size = Vector2(100, 10)
	health_bar.value = 50
	ui.add_child(health_bar)

# UI 更新逻辑
func update_health_display():
	"""更新生命条显示"""
	if health_bar:
		var percentage = (health / max_health) * 100
		health_bar.value = percentage
		# 根据生命值改变颜色
		if health < max_health * 0.3:
			health_bar.modulate = Color(1, 0, 0)  # 红色
		elif health < max_health * 0.7:
			health_bar.modulate = Color(1, 0.8, 0)  # 黄色
		else:
			health_bar.modulate = Color(0, 1, 0)  # 绿色

func update_ui_position():
	"""更新UI位置，使其跟随物体"""
	if ui_container:
		# 将世界坐标转换为视口坐标
		var viewport = get_viewport()
		var screen_pos = viewport.get_canvas_transform().affine_inverse() * global_position
		ui_container.position = screen_pos + Vector2(0, -40)  # 偏移到物体上方

# 显示/隐藏UI
func show_health_bar():
	if ui_container:
		ui_container.visible = true

func hide_health_bar():
	if ui_container:
		ui_container.visible = false

# 范围检测（信号处理）
func _on_interaction_area_entered(body) -> void:
	var repair_object = body.get_parent()
	if repair_object.is_in_group("player"):
		player_in_range = true
		show_health_bar()

func _on_interaction_area_exited(body) -> void:
	var repair_object = body.get_parent()
	if repair_object.is_in_group("player"):
		player_in_range = false
		hide_health_bar()
		if is_repairing:
			interrupt_repair()
