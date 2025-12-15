extends StaticBody2D

@onready var sprite := $Sprite2D
@onready var mouse_area := $MouseArea
@onready var put_place = $PutPlace
@export var item_type: String = "surface_mat"  # 书是小物品
#@onready var outline_sprite = $OutlineSprite # 用来实现触碰描边
var is_being_dragged := false  # 是否正在拖拽中
var drag_offset := Vector2.ZERO  # 拖拽偏移量
var is_area = false # 鼠标是否在物品的可拖拽范围内
var can_place := false  # 是否可以放置
var overlapping_furniture = null  # 记录叠放目标
var overlapping_surfaces: Array = [] # 看是否有多个叠放区域
var overlap_put: Array = [] # 记录碰到的其他物品的放置区域
var is_overlapping_type  # 叠放物品的类型
var one_dragging = false # 是否为拖拽出来的物品
var change_seat  # 随物品在不同的区域进行转换
var is_been_dragged = false # 被动被拖拽
var is_overlapping = false # 是否在叠加
var is_functional := true  # 当前功能是否启用
var save_surface = 0 #用来记录保存垫子位于哪个家具上
var item_data: Dictionary = { "id": "tea_mat", "name": "茶垫", "price": 1, "icon": preload("res://art_resource/Fewobject/Tea mat.png") }

func _ready():
	add_to_group("dragers")
	set_meta("item_type", "surface_mat")
	mouse_area.mouse_entered.connect(_on_area_mouse_entered)
	mouse_area.mouse_exited.connect(_on_area_mouse_exited)
	put_place.connect("area_entered", _on_area_entered)
	put_place.connect("area_exited", _on_area_exited)
	self.set_deferred("collision_layer", 0)
	self.set_deferred("collision_mask", 0)
	#$OutlineSprite.visible = false
	call_deferred("_check_placeable_area")

# 预防放下时立马拖拽
func _clear_recent_drop():
	DragManager.recently_dropped = false

# 拖拽放置事件
func _input(event):
	if not DragManager.is_edit_mode:
		return  # 如果不在编辑模式，禁止响应拖拽操作
	if DragManager.current_hovered != self and not one_dragging:
		return  # 不是当前最高的悬停物体，不允许拖拽
	if DragManager.recently_dropped:
		# 延迟清除标记，允许当前物品忽略，但下一次点击生效
		call_deferred("_clear_recent_drop")
		return  # 放置刚刚发生，避免其他物体响应
	if event is InputEventMouseButton:
		# 检查是否是左键按下
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# 检测拖拽状态，进行切换
			if not is_being_dragged:
				if has_items_on_top():
					print("请先清除上面的物品")
					return
				# 用于感应鼠标是否在拖拽范围，并设为单一拖拽
				if is_area and DragManager.start_drag(self):
					is_being_dragged = true
					clear_outline()
					drag_offset = global_position - get_global_mouse_position()
					z_index = 2100
					DragManager.cur_item_id = item_data["id"]
			else:
				if can_place and judge_surface():
					is_being_dragged = false
					apply_outline()
					# 设置层级
					z_index = get_surface_z_index()
					DragManager.stop_drag() # 通知 DragManager 解除当前拖拽物体
					# 放下物体成功
					DragManager.recently_dropped = true
					print("摆放成功")
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
				DragManager.stop_drag()
				return_to_backpack()

func _process(_delta):
	# 如果正在拖拽中：不断将物体的位置设置为当前鼠标位置 + 拖拽偏移值
	if is_being_dragged:
		global_position = get_global_mouse_position() + drag_offset
		_check_placeable_area()
		judge_color()
		z_index = 2101
	else:
		z_index = get_surface_z_index()
		judge_surface()
		if overlapping_furniture != null:
			if overlapping_furniture.is_being_dragged:
				z_index = 2101

# 脱离物品叠放状态
func diastasis_overlapping():
	# 如果当前在桌子里的 StackContainer 中，需要移出
	if get_parent().name == "StackContainer":
		var main_scene = get_tree().get_first_node_in_group("editable")
		var world = main_scene.get_node_or_null("World")
		var global_pos = global_position
		get_parent().remove_child(self)
		world.add_child(self)
		global_position = global_pos

# 物品叠放
func overlapping_item():
	if get_parent().name == "StackContainer":
		return
	# 如果要叠放到另一物品上
	if overlapping_furniture != null and can_place:# and is_not_overlapping
		# 叠放：设置父节点为对方书的 stack_container
		var container = overlapping_furniture.get_node_or_null("StackContainer")
		if container:
			var global_pos := global_position
			# 转移到叠放容器里
			get_parent().remove_child(self)
			container.add_child(self)
			global_position = global_pos

# 成为子节点后关闭功能
func disable_all_functions():
	is_functional = false
	if has_node("MouseArea"):
		$MouseArea.set_deferred("monitoring", false)
		$MouseArea.set_deferred("mouse_filter", Control.MOUSE_FILTER_IGNORE)
	if has_node("PutPlace"):
		$PutPlace.set_deferred("monitoring", false)
		$PutPlace.set_deferred("mouse_filter", Control.MOUSE_FILTER_IGNORE)
	if has_node("SurfaceArea"):
		$SurfaceArea.set_deferred("monitoring", false)
		$SurfaceArea.set_deferred("mouse_filter", Control.MOUSE_FILTER_IGNORE)

# 脱离子节点后开启功能
func enable_all_functions():
	is_functional = true
	if has_node("MouseArea"):
		$MouseArea.set_deferred("monitoring", true)
		$MouseArea.set_deferred("mouse_filter", Control.MOUSE_FILTER_IGNORE)
	if has_node("PutPlace"):
		$PutPlace.set_deferred("monitoring", true)
		$PutPlace.set_deferred("mouse_filter", Control.MOUSE_FILTER_IGNORE)
	if has_node("SurfaceArea"):
		$SurfaceArea.set_deferred("monitoring", true)
		$SurfaceArea.set_deferred("mouse_filter", Control.MOUSE_FILTER_IGNORE)

# 判断是否可放置（包含只接触一个可放置桌面）
func judge_surface():
	if overlapping_surfaces.is_empty():
		return false
	var aaa = overlapping_surfaces.duplicate() #临时创建出来防止没完全遍历overlapping_surfaces
	var furniture_surface = []
	var carton_surface = []
	for area in aaa:
		var other = area.get_parent()
		if other.has_meta("item_type") and other.get_meta("item_type") == "furniture" :
			if other.is_being_dragged and other != overlapping_furniture:
				overlapping_surfaces.erase(area)
			else:
				furniture_surface.append(area)
		if other.has_meta("item_type") and  other.get_meta("item_type") == "carton":
			if other.is_being_dragged and other != overlapping_furniture:
				overlapping_surfaces.erase(area)
			else:
				carton_surface.append(area)
	if save_surface == 1 and furniture_surface.size() == 1:
		var other = furniture_surface[0].get_parent()
		if is_overlapping:
			overlapping_furniture = other  # 记录重叠对象
		save_surface = 0
	if overlapping_surfaces.size() == 1:
		var other = overlapping_surfaces[0].get_parent()
		if other.has_meta("item_type") and other.get_meta("item_type") == "furniture":
			if not other.is_being_dragged or overlapping_furniture == other:
				if is_overlapping:
					overlapping_furniture = other  # 记录重叠对象
				return judge_put()
	if furniture_surface.size() == 1:
		var area = furniture_surface[0]
		var other = area.get_parent()
		var put_rect = get_put_rect()
		var area_shape = area.get_node("CollisionShape2D")
		var area_rect = get_global_shape_rect(area_shape)
		if area_rect.encloses(put_rect):
			if is_overlapping:
				overlapping_furniture = other  # 记录重叠对象
			return judge_put()
	else:
		if is_being_dragged:
			overlapping_furniture = null
		return false

# 判断进入其他可放置区域后，是否可放置
func judge_put():
	if overlap_put.is_empty():
		return true
	for area in overlap_put:
		if not is_same_object(area):
			var other = area.get_parent()
			if other.has_meta("item_type"):
				if other.get_meta("item_type") == "surface_mat":
					return false
				if other.get_meta("item_type") == "object" and other.is_overlapping:
					return false
				if other.get_meta("item_type") == "carton" and other.is_overlapping:
					return false
	return true

# 根据是否可放置，改变颜色或透明度等
func judge_color():
	if can_place and judge_surface():
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
	# 支持桌面区域
	for area in get_tree().get_nodes_in_group("placeable_surface"):
		if is_same_object(area):
			break
		if not area is Area2D:
			continue
		var area_shape := area.get_node("CollisionShape2D")
		var area_rect = get_global_shape_rect(area_shape)
		if area_rect.encloses(put_rect):
			change_seat = "surface"
			can_place = true
			is_overlapping = true
			return
	is_overlapping = false

# 检查桌子上是否放了物体
func has_items_on_top() -> bool:
	var surface_area = get_node_or_null("MouseArea")
	if not surface_area or not surface_area is Area2D:
		return false
	for area in surface_area.get_overlapping_areas():
		if not is_same_object(area):
			var parent = area.get_parent()
			if parent.is_in_group("dragers"):  # 你的物品都在这个组
				if parent.has_meta("item_type") and parent.get_meta("item_type") == "object" or parent.get_meta("item_type") == "carton":
					if parent.is_overlapping:
						return true  # 检测到物体
	return false

# 把物品回收进背包
func return_to_backpack():
	if has_items_on_top():
		print("上面还有物品，无法收回")
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

# 动态地获取层级
func get_surface_z_index():
	if overlapping_furniture and can_place:
		var oavr_marker = overlapping_furniture.get_node("Sprite2D").get_node("ShelterBase")
		var z_index_offset = 50 / (oavr_marker.global_position.y - $Sprite2D/ShelterBase.global_position.y) 
		if overlapping_furniture.change_seat == "wall":
			return overlapping_furniture.z_index + 1 / scale.y
		return overlapping_furniture.z_index + z_index_offset / scale.y
	return -1900

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

#用来记录保存垫子位于哪个家具上
func save_surfaces():
	if overlapping_furniture.has_meta("item_type") and overlapping_furniture.get_meta("item_type") == "furniture":
		return 1

# 保存数据提取
func get_save_data():
	return {
		"id": item_data.get("id", ""),
		"position": position,
		"save_surface": save_surfaces()
	}

# 物品拖出时状态
func first_ex_drag():
	if DragManager.start_drag(self):
		is_being_dragged = true
		one_dragging = true
		DragManager.request_highlight(self)

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
	# 若进入的区域也是可放置物品的区域
	if area.is_in_group("put_place") and not is_same_object(area):  # 放置物品加个 group
		if not overlap_put.has(area):
			overlap_put.append(area)
	# 进入的区域是桌面类区域
	if area.is_in_group("placeable_surface") and not is_same_object(area):
		if not overlapping_surfaces.has(area):
			overlapping_surfaces.append(area)

func _on_area_exited(area):
	if area.is_in_group("put_place"):
		overlap_put.erase(area)
	if area.is_in_group("placeable_surface"):
		overlapping_surfaces.erase(area)
		if overlapping_surfaces.is_empty() and not can_place:
			overlapping_furniture = null
