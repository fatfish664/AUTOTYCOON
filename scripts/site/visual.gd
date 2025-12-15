extends Camera2D

#@export var target_node: Node2D  # 要跟随的目标（玩家）
@export var ZOOM_MIN: float = 1
@export var ZOOM_MAX: float = 4.0
@export var ZOOM_SPEED: float = 0.5

var current_zoom: float = 1.0

func _ready():
	# 设置相机为当前激活相机
	make_current()
	_zoom_camera(GameManager.dev_zoom)

#func _process(delta):
	#if target_node:
		## 计算合适的跟随权重（确保在0-1之间）
		#var follow_weight = clamp(target_node.speed * delta / 50.0, 0.01, 0.5)
		## 平滑跟随目标(跟随速度为目标移速)
		#global_position = global_position.lerp(
			#target_node.global_position,
			#follow_weight
			#)
		#global_position = global_position.round()

func _input(event):
	if event is InputEventMouseButton:
		if is_shop_open():
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(-ZOOM_SPEED)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(ZOOM_SPEED)

func _zoom_camera(amount: float):
	var new_zoom = clamp(zoom.x + amount, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2.ONE * new_zoom
	current_zoom = new_zoom
	GameManager.dev_zoom = current_zoom - ZOOM_MIN

#func set_follow_target(new_target: Node2D):
	#target_node = new_target

# 判断商店是否打开
func is_shop_open() -> bool:
	var shop = get_tree().get_first_node_in_group("shop_ui")
	return shop != null and shop.visible
