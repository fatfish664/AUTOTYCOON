extends StaticBody2D

#const SNAP_MARGIN = 8  # 吸附阈值，单位像素（距离边缘这么近就吸附）
@onready var sprite := $Sprite2D
@onready var mouse_area := $MouseArea
@onready var put_place = $PutPlace
@export var item_type: String = "furniture"  # 桌子是家具
#@onready var outline_sprite = $OutlineSprite # 用来实现触碰描边
var is_being_dragged := false  # 是否正在拖拽中
var drag_offset := Vector2.ZERO  # 拖拽偏移量
var is_area = false # 鼠标是否在区域内
var can_place := false  # 是否可以放置
var overlap_put: Array = [] # 记录碰到的其他物品的放置区域
var surface_item: Array = [] # 记录放在上面的物品
var sur : Array = [] #拖拽时临时记录放在上面的物品
var other_surface_item: Array = [] # 其他物体上的物体
var is_other_item = false # 检测桌面区是否碰到其他物体上的物体
var one_dragging = false # 是否是刚拖出来
var change_seat  # 随物品在不同的区域进行转换(其他脚本有判定，不能删)
var is_been_dragged = false # 被动被拖拽
var item_data: Dictionary = { "id": "tea_table", "name": "茶桌", "price": 1, "icon": preload("res://art_resource/Fewobject/Tea table.png") }

func _ready():
	var collision = $CollisionShape2D
	add_to_group("dragers")
	set_meta("item_type", "furniture")
	mouse_area.mouse_entered.connect(_on_area_mouse_entered)
	mouse_area.mouse_exited.connect(_on_area_mouse_exited)
	put_place.connect("area_entered", _on_area_entered)
	put_place.connect("area_exited", _on_area_exited)
	$SurfaceArea.area_entered.connect(_on_surface_area_entered)
	$SurfaceArea.area_exited.connect(_on_surface_area_exited)
	collision.disabled = false
	#$OutlineSprite.visible = false

# 预防放下时立马拖拽
func _clear_recent_drop():
	DragManager.recently_dropped = false

# 拖拽放置事件
func _input(event):
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
				if can_place and judge_put() and judge_wall_furniture_place() and not is_other_item:
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
	# 让被放置的物品一起移动
	joint_diast_item()
	# 如果正在拖拽中：不断将物体的位置设置为当前鼠标位置 + 拖拽偏移值
	if is_being_dragged:
		global_position = get_global_mouse_position() + drag_offset
		_check_placeable_area()
		judge_color()
		collision.disabled = true
		if can_place and judge_put() and judge_wall_furniture_place() and not is_other_item:
			z_index = get_surface_z_index()
		else:
			z_index = 2100
	else:
		z_index = get_surface_z_index()
		detect_surface()

# 把桌面上的物品加入/移出子节点
func joint_diast_item():
	if is_being_dragged and not is_been_dragged:
		sur = surface_item.duplicate()
		sur.sort_custom(func(a, b): return a.z_index < b.z_index)
		for area in sur:
			if area.is_functional:
				area.overlapping_item()
				area.disable_all_functions()
		is_been_dragged = true
	elif not is_being_dragged and is_been_dragged:
		for area in sur:
			if not area.is_functional:
				area.diastasis_overlapping()
				area.enable_all_functions()
		is_been_dragged = false
		sur = []

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
	if can_place and judge_put() and judge_wall_furniture_place() and not is_other_item:
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

# 判断是否与墙上家具碰撞
func judge_wall_furniture_place():
	var put_rect = get_put_rect()
	var body_shape = mouse_area.get_node("CollisionShape2D")
	var body_rect = get_global_shape_rect(body_shape)
	for area in get_tree().get_nodes_in_group("put_place"):
		var other := area.get_parent()
		if  other.has_method("shadow_in"):
			if other.shadow_instance == null:
				return true
			var shadow_shape = other.shadow_instance.get_node("CollisionShape2D")
			var other_shape = other.get_node_or_null("MouseArea").get_node_or_null("CollisionShape2D")
			var shadow_rect := get_global_shape_rect(shadow_shape)
			var other_rect := get_global_shape_rect(other_shape)
			var shadow_overlap := put_rect.intersects(shadow_rect)
			var wall_overlap := body_rect.intersects(other_rect)
			if shadow_overlap and wall_overlap:
				return false  # 两个都重叠，冲突，不能放置
	return true  # 没有冲突，可以放置

# 检测桌面区域的物品
func detect_surface():
	var surface_area = get_node_or_null("SurfaceArea")
	if not surface_area or not surface_area is Area2D:
		return false
	for area in surface_area.get_overlapping_areas():
		if not is_same_object(area):
			var parent = area.get_parent()
			if not parent in surface_item and parent.get_parent().name != "StackContainer":
				if parent.is_in_group("dragers"):  # 你的物品都在这个组
					if parent.has_meta("item_type") and parent.get_meta("item_type") != "furniture":
						if  parent.is_overlapping and parent.overlapping_furniture == self:
							surface_item.append(parent)

# 检查桌子上是否放了物体
func has_items_on_top() -> bool:
	var surface_area = get_node_or_null("SurfaceArea")
	if not surface_area or not surface_area is Area2D:
		return false
	for area in surface_area.get_overlapping_areas():
		if not is_same_object(area):
			var parent = area.get_parent()
			if parent.is_in_group("dragers"):  # 你的物品都在这个组
				if parent.has_meta("item_type") and parent.get_meta("item_type") == "surface_mat":
					if parent.can_place:
						return true  # 检测到物体
				if parent.has_meta("item_type") and parent.get_meta("item_type") == "object":
					if parent.is_overlapping:
						return true  # 检测到物体
				if parent.has_meta("item_type") and parent.get_meta("item_type") == "carton":
					if parent.is_overlapping:
						return true  # 检测到物体
	return false

# 动态地获取层级
func get_surface_z_index():
	return $Sprite2D/ShelterBase.global_position.y

# 把物品回收进背包
func return_to_backpack():
	if has_items_on_top():
		print("桌子上还有物品，无法收回")
		DragManager.has_been_recycled = false
		return
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
		"position": position
	}

# 开启/关闭描边
func apply_outline():
	#outline_sprite.visible = true
	pass

func clear_outline():
	#outline_sprite.visible = false
	pass

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

func _on_surface_area_entered(area: Area2D):
	if is_same_object(area):
		return  # 忽略自身
	var item = area.get_parent()
	# 若进入的区域也是可放置物品的区域
	if area.is_in_group("put_place"):  # 放置物品加个 group
		if item.has_meta("item_type") and (item.get_meta("item_type") == "object" or item.get_meta("item_type") == "carton"):
			if item.has_method("disable_all_functions") and item.overlapping_furniture != null:
				if !is_instance_valid(item.overlapping_furniture) || \
				(item.overlapping_furniture != self && 
				(is_instance_valid(item.overlapping_furniture.overlapping_furniture) && 
				item.overlapping_furniture.overlapping_furniture != self)):
					if is_being_dragged and item.is_overlapping:
						other_surface_item.append(area)
						is_other_item = true

func _on_surface_area_exited(area: Area2D):
	if is_same_object(area):
		return  # 忽略自身
	# 获取其对应的物体父节点
	var item = area.get_parent()
	if item in surface_item:
		surface_item.erase(item)
	if area in other_surface_item:
		other_surface_item.erase(area)
	if other_surface_item.is_empty():
		is_other_item = false
