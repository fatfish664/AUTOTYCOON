extends StaticBody2D

@onready var sprite := $Sprite2D
@onready var put_place = $PutPlace
var is_being_dragged := false  # 是否正在拖拽中
var drag_offset := Vector2.ZERO  # 拖拽偏移量
var is_area = false
var can_place := false  # 是否可以放置
var is_not_overlap = true  # 是否重叠
var item_data: Dictionary = { "id": "cup", "name": "杯子", "price": 1, "icon": preload("res://art_resource/Fewobject/Cup.png") }

func _ready():
	var collision = $CollisionShape2D
	add_to_group("dragers")
	mouse_entered.connect(_on_area_mouse_entered)
	mouse_exited.connect(_on_area_mouse_exited)
	put_place.connect("area_entered", _on_area_entered)
	put_place.connect("area_exited", _on_area_exited)
	collision.disabled = false

func _input(event):
	var collision = $CollisionShape2D
	if event is InputEventMouseButton:
		# 检查是否是左键按下
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# 检测拖拽状态，进行切换
			if not is_being_dragged:
				# 用于感应鼠标是否在拖拽范围，并设为单一拖拽
				if is_area and DragManager.start_drag(self):
					is_being_dragged  = true
					collision.disabled = true  # 拖拽时关闭碰撞
					set_process(true)  # 启用_process
					drag_offset = global_position - get_global_mouse_position()
					z_index = 2100
					DragManager.cur_item_id = item_data["id"]
			else:
				if can_place and is_not_overlap:
					is_being_dragged = false
					collision.disabled = false  # 拖拽结束恢复碰撞
					set_process(false)
					z_index = 0
					DragManager.stop_drag() # 通知 DragManager 解除当前拖拽物体
					print("摆放成功")
				else:
					print("非法区域，禁止摆放")
		# 右键点击取消放置，进行回收
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if is_area or is_being_dragged:
				print("右键取消拖动，物品回收")
				is_being_dragged = false
				set_process(false)
				collision.disabled = false
				DragManager.stop_drag()
				return_to_backpack()

func _process(_delta):
	var collision = $CollisionShape2D
	# 如果正在拖拽中：不断将物体的位置设置为当前鼠标位置 + 拖拽偏移值
	if is_being_dragged:
		global_position = get_global_mouse_position() + drag_offset
		_check_placeable_area()
		collision.disabled = true

func _check_placeable_area():
	can_place = false
	var put_shape = put_place.get_node("CollisionShape2D")
	if put_shape == null or not put_shape.shape is RectangleShape2D:
		print("PutPlace 缺失或形状类型不对")
		return
	# 拿到 put_place 的世界矩形
	var put_size: Vector2 = put_shape.shape.extents * 2 * put_place.global_scale
	var put_pos = put_shape.get_global_transform().origin - put_size * 0.5
	var put_rect := Rect2(put_pos, put_size)
	# 获取场景中所有加入"placeable_area"组的节点
	for area in get_tree().get_nodes_in_group("placeable_floor"):
		# 检查当前区域是否与物体的碰撞体或区域重叠
		if not area is Area2D:
			continue
		var area_shape := area.get_node("CollisionShape2D")
		if area_shape == null or not area_shape.shape is RectangleShape2D:
			continue
		var area_size = area_shape.shape.extents * 2 * area.global_scale
		var area_pos = area_shape.get_global_transform().origin - area_size * 0.5
		var area_rect := Rect2(area_pos, area_size)
		#print("Put Rect: ", put_rect)
		#print("Area Rect: ", area_rect)
		# 如果当前放置矩形完全被包含
		if area_rect.encloses(put_rect):
			can_place = true
			break
	# 根据是否可放置，改变颜色或透明度等
	if can_place:
		sprite.modulate = Color(1, 1, 1, 1)  # 白色/正常
	else:
		sprite.modulate = Color(1, 1, 1, 0.5)  # 半透明（非法放置）

func return_to_backpack():
	var backpack = get_tree().get_first_node_in_group("Backpack")
	if item_data.has("id"):
		print(item_data["id"])
	print(DragManager.cur_item_id)
	print(item_data)
	# 通知背包系统回收此物品
	if item_data.has("id"):
		backpack.return_item(item_data["id"])
		print(item_data)
	elif backpack.return_item(DragManager.cur_item_id):
		print(8)
	else:
		print("无法识别 item_data，无法回收")
	# 也可以播放动画再销毁
	queue_free()

func first_ex_drag():
	is_being_dragged = true
	z_index = 2100

func get_save_data():
	return {
		"id": item_data.get("id", ""),
		"position": position
	}

func _on_area_mouse_entered():
	is_area = true

func _on_area_mouse_exited():
	is_area = false

func _on_area_entered(area):
	# 若进入的区域也是可放置物品的区域
	if area.get_parent().is_in_group("dragers"):  # 放置物品加个 group
		is_not_overlap = false
		modulate = Color(1, 1, 1, 0.5)

func _on_area_exited(area):
	if area.get_parent().is_in_group("dragers"):
		is_not_overlap = true
		modulate = Color(1, 1, 1, 1)
