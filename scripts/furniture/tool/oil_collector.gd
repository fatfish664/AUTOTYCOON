extends StaticBody2D

@onready var sprite := $Sprite2D
@onready var animated := $AnimatedSprite2D
@onready var mouse_area := $MouseArea
@onready var put_place = $PutPlace
@onready var taking_area = $TakingArea
@onready var marker = $Marker2D
@export var item_type: String = "furniture"  # 物品类型（如桌子是家具）
@export var animation_positions: Dictionary = {
	"left-front": [Vector2(11.5,-0.5), Vector2(5,-7), Vector2(0,-11), Vector2(0,-11)],
	"left-back": [Vector2(11.5,-0.5), Vector2(8,5), Vector2(0,7), Vector2(0,7)],
	"right-front": [Vector2(-11.5,-0.5), Vector2(-8,-5), Vector2(0,-11), Vector2(0,-11)],
	"right-back": [Vector2(-11.5,-0.5), Vector2(-12,3), Vector2(0,7), Vector2(0,7)],
	"front-left": [Vector2(0,-11), Vector2(0,-11), Vector2(0,-11), Vector2(5,-7)],
	"front-right": [Vector2(0,-11), Vector2(0,-11), Vector2(0,-11), Vector2(-8,-5)],
	"back-left": [Vector2(0,7), Vector2(0,7), Vector2(0,7), Vector2(8,5)],
	"back-right": [Vector2(0,7), Vector2(0,7), Vector2(0,7), Vector2(-12,3)],
	}

var is_being_dragged := false  # 是否正在拖拽中
var drag_offset := Vector2.ZERO  # 拖拽偏移量
var is_area = false # 鼠标是否在区域内
var can_place := false  # 是否可以放置
var overlap_put: Array = [] # 记录碰到的其他物品的放置区域
var one_dragging = false # 是否是刚拖出来
var is_occupy = false # 是否在被使用
var change_seat  # 随物品在不同的区域进行转换(其他脚本有判定，不能删)
var item_direction: String = "front" # 记录当前物品的方向
var item_data: Dictionary = { "id": "oil_collector" }

func _ready():
	var collision = $CollisionShape2D
	add_to_group("dragers")
	add_to_group("oil_collector")
	set_meta("item_type", "furniture")
	mouse_area.mouse_entered.connect(_on_area_mouse_entered)
	mouse_area.mouse_exited.connect(_on_area_mouse_exited)
	put_place.connect("area_entered", _on_area_entered)
	put_place.connect("area_exited", _on_area_exited)
	animated.frame_changed.connect(_update_marker_position)
	animated.animation_finished.connect(_on_animation_finished)
	collision.disabled = false

# 预防放下时立马拖拽
func _clear_recent_drop():
	DragManager.recently_dropped = false

# 拖拽放置事件
func _input(event):
	@warning_ignore("shadowed_variable")
	var collision = $CollisionShape2D
	if not DragManager.is_edit_mode:
		return  # 如果不在编辑模式，禁止响应拖拽操作
	if DragManager.current_hovered != self and not one_dragging:
		return  # 不是当前最高的悬停物体，不允许拖拽
	if DragManager.recently_dropped:
		call_deferred("_clear_recent_drop")
		return  # 放置刚刚发生，避免其他物体响应
	if event is InputEventMouseButton:
		# 检查是否是左键按下
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# 检测拖拽状态，进行切换
			if not is_being_dragged:
				# 用于感应鼠标是否在拖拽范围，并设为单一拖拽
				if is_area and DragManager.start_drag(self):
					is_being_dragged = true
					collision.disabled = true  # 拖拽时关闭碰撞
					clear_outline()
					drag_offset = global_position - get_global_mouse_position()
					z_index = 2100
					DragManager.cur_item_id = item_data["id"]
			else:
				if can_place and judge_put():
					is_being_dragged = false
					collision.disabled = false  # 拖拽结束恢复碰撞
					apply_outline()
					# 设置层级
					get_surface_z_index()
					DragManager.stop_drag() # 通知 DragManager 解除当前拖拽物体
					# 放下物体成功
					DragManager.recently_dropped = true
					print("摆放成功")
					DragManager.current_z = -INF
					if one_dragging:
						DragManager.request_highlight(self)
						again_drag_put()
						one_dragging = false
				else:
					print("非法区域，禁止摆放")
		# 右键点击取消放置，进行回收
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if (is_area or is_being_dragged) and not DragManager.has_been_recycled:
				DragManager.has_been_recycled = true # 标记已回收
				#print("右键取消拖动，物品回收")
				is_being_dragged = false
				collision.disabled = false
				DragManager.stop_drag()
				return_to_backpack()

func _process(_delta):
	var collision = $CollisionShape2D
	# 如果正在拖拽中：不断将物体的位置设置为当前鼠标位置 + 拖拽偏移值
	if is_being_dragged:
		global_position = get_global_mouse_position() + drag_offset
		_check_placeable_area()
		judge_color()
		collision.disabled = true
		if can_place and judge_put():
			z_index = get_surface_z_index()
		else:
			z_index = 2100
	else:
		z_index = get_surface_z_index()

# 进行动画播放（外部调用）
func play_animation(ahead_direction, direction):
	if item_direction != ahead_direction:
		print("在OilCollector的脚本中，工具车的当前朝向和角色脚本中记录的不一致在")
		return
	var cartoon = ahead_direction + "-" + direction
	animated.play(cartoon)

# 进行旋转换场景的函数
func replace_with_rotated_version(new_direction):
	var scene_path := "res://scenes/furnitures/tools/oil_collector_%s.tscn" % new_direction
	var new_scene = load(scene_path).instantiate()
	# 添加到主场景
	var world = get_tree().get_first_node_in_group("editable").get_node("World")
	world.add_child(new_scene)
	new_scene.item_direction = new_direction
	new_scene.item_data = self.item_data
	new_scene.z_index = self.z_index
	if self.taking_area.is_using:
		new_scene.taking_area.is_using = true
		var player_marker = taking_area.player_ref.get_node("TakingCart").get_node(new_direction)
		var offset = new_scene.global_position - new_scene.taking_area.marker.global_position
		new_scene.global_position = player_marker.global_position + offset
		new_scene.taking_area.player_ref = self.taking_area.player_ref
		self.taking_area.player_ref.work_tool = new_scene
		self.queue_free()
		return
	new_scene.global_position = self.global_position
	new_scene.is_being_dragged = true
	new_scene.one_dragging = true
	DragManager.clear_if_hovered(self)
	DragManager.request_highlight(new_scene)
	# 交给 DragManager
	DragManager.active_item = new_scene
	# 删除旧节点
	self.queue_free()

# 判断进入其他可放置区域后，是否可放置
func judge_put():
	for area in overlap_put:
		var item = area.get_parent()
		if item.has_meta("item_type") and item.get_meta("item_type") == "object":
			if item.placed_on_surface:
				overlap_put.erase(area)
		if item.has_meta("item_type") and item.get_meta("item_type") == "surface_mat":
			if item.can_place:
				overlap_put.erase(area)
		if item.has_meta("item_type") and item.get_meta("item_type") == "carton":
			if item.is_overlapping:
				overlap_put.erase(area)
	if overlap_put.is_empty():
		return true
	return false

# 根据是否可放置，改变颜色或透明度等
func judge_color():
	if can_place and judge_put():
		modulate = Color(1, 1, 1, 1)
	else:
		modulate = Color(1, 1, 1, 0.5)  # 半透明（非法放置）

# 获取自身的可可放置区域
func get_put_rect():
	var put_shape = put_place.get_node("CollisionShape2D")
	if put_shape == null or not put_shape.shape is RectangleShape2D:
		print("PutPlace 缺失或形状类型不对")
		return
	# 拿到 put_place 的世界矩形
	var put_size: Vector2 = put_shape.shape.extents * 2 * put_place.global_scale
	var put_pos = put_shape.get_global_transform().origin - put_size * 0.5
	var put_rect := Rect2(put_pos, put_size)
	return put_rect

# 获取相应的区域的形状
func get_global_shape_rect(shape_node: CollisionShape2D) -> Rect2:
	if shape_node.shape is RectangleShape2D:
		var size = shape_node.shape.extents * 2
		var global_pos = shape_node.get_global_transform().origin
		var offset = size * 0.5 * shape_node.global_scale
		return Rect2(global_pos - offset, size * shape_node.global_scale)
	return Rect2()

# 可放置区域判断
func _check_placeable_area():
	can_place = false
	var put_rect = get_put_rect()
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
		# 如果当前放置矩形完全被包含
		if area_rect.encloses(put_rect):
			can_place = true
			return

# 动态地获取层级
func get_surface_z_index():
	return $Sprite2D/ShelterBase.global_position.y

# 把物品回收进背包
func return_to_backpack():
	var backpack = get_tree().get_first_node_in_group("Backpack")
	# 通知背包系统回收此物品
	if item_data.has("id"):
		backpack.return_item(item_data["id"])
	elif backpack.return_item(DragManager.cur_item_id):
		pass
	else:
		print("无法识别 item_data，无法回收")
	# 重置全局标记（防止一次右键点击回收多件物品）
	# 添加延迟是为了等回收动作完成后再解锁下一次
	await get_tree().create_timer(0.2).timeout
	DragManager.has_been_recycled = false
	DragManager.clear_if_hovered(self)
	# 也可以播放动画再销毁
	queue_free()
	#DragManager.cur_item_id = "empty"

# 数量没耗尽，再次拖放
func again_drag_put():
	var backpack = get_tree().get_first_node_in_group("Backpack")
	var remaining = backpack.get_item_count(item_data["id"])
	if remaining <= 0:
		DragManager.shift_auto_drag_mode = false  # 没了也停掉
		print("物品耗尽")
	else:
		if DragManager.shift_auto_drag_mode:
			# 还有剩余，继续拖拽新物品（你可以自动从背包拖出新物品）
			backpack.auto_drag_item(item_data["id"])

# 物品拖出时状态
func first_ex_drag():
	if DragManager.start_drag(self):
		is_being_dragged = true
		z_index = 2100
		one_dragging = true
		DragManager.request_highlight(self)

# 保存数据提取
func get_save_data():
	return {
		"id": item_data.get("id", ""),
		"position": position,
		"direction": item_direction
	}

# 开启/关闭描边
func apply_outline():
	pass
	#outline_sprite.visible = true

func clear_outline():
	pass
	#outline_sprite.visible = false

# 是否正在被使用
func is_occupied():
	return is_occupy

# 判断两个区域是不是来自同一个物体
func is_same_object(area: Area2D) -> bool:
	return area.get_owner() == self or area.get_parent() == self

# 链接鼠标等区域
func _on_area_mouse_entered():
	is_area = true
	if DragManager.is_edit_mode and not is_being_dragged:
		DragManager.request_highlight(self)

func _on_area_mouse_exited():
	is_area = false
	if not is_being_dragged:
		DragManager.clear_if_hovered(self)

func _on_area_entered(area):
	if is_same_object(area):
		return  # 忽略自身
	# 若进入的区域也是可放置物品的区域
	if area.is_in_group("put_place"):  # 放置物品加个 group
		if is_being_dragged:
			if not overlap_put.has(area):
				overlap_put.append(area)

func _on_area_exited(area):
	if is_same_object(area):
		return  # 忽略自身
	if area.is_in_group("put_place"):
		if is_being_dragged:
			overlap_put.erase(area)

func _on_animation_finished():
	var current_anim = animated.animation
	taking_area.marker.position = animation_positions[current_anim][0]
	match current_anim:
		"front-left":
			replace_with_rotated_version("left")
		"front-right":
			replace_with_rotated_version("right")
		"back-left":
			replace_with_rotated_version("left")
		"back-right":
			replace_with_rotated_version("right")
		"left-front":
			replace_with_rotated_version("front")
		"left-back":
			replace_with_rotated_version("back")
		"right-front":
			replace_with_rotated_version("front")
		"right-back":
			replace_with_rotated_version("back")

# 使对应位置点跟随动画播放而改变
func _update_marker_position():
	var anim = animated.animation
	var frame = animated.frame
	if animation_positions.has(anim) and frame < animation_positions[anim].size():
		taking_area.marker.position = animation_positions[anim][frame]
