extends StaticBody2D

@onready var sprite := $Sprite2D
@onready var mouse_area := $MouseArea
@onready var put_place = $PutPlace
@export var item_type: String = "object"  # 书是小物品
@onready var outline_sprite = $OutlineSprite # 用来实现触碰描边
var is_being_dragged := false  # 是否正在拖拽中
var drag_offset := Vector2.ZERO  # 拖拽偏移量
var is_area = false # 鼠标是否在物品的可拖拽范围内
var can_place := false  # 是否可以放置
var placed_on_surface := false # 是否在桌子上
var overlapping_furniture = null  # 记录叠放目标
var overlap_surfaces: Array = [] # 看是否有多个叠放区域
var overlap_put: Array = [] # 记录碰到的其他物品的放置区域
var is_overlapping = false # 是否还在叠放
var is_overlapping_type  # 叠放物品的类型
var one_dragging = false # 是否为拖拽出来的物品
var surface_z_index : int # 获取当前物品增加的层级
var change_seat  # 随物品在不同的区域进行转换
var item_data: Dictionary = { "id": "book", "name": "书", "price": 30, "icon": preload("res://art_resource/changjing/book.png") }

func _ready():
	var collision = $CollisionShape2D
	add_to_group("dragers")
	set_meta("item_type", "object")
	mouse_area.mouse_entered.connect(_on_area_mouse_entered)
	mouse_area.mouse_exited.connect(_on_area_mouse_exited)
	put_place.connect("area_entered", _on_area_entered)
	put_place.connect("area_exited", _on_area_exited)
	collision.disabled = false
	$OutlineSprite.visible = false
	call_deferred("_check_placeable_area")

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
		# 延迟清除标记，允许当前物品忽略，但下一次点击生效
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
				if can_place and judge_surface():
					is_being_dragged = false
					collision.disabled = false  # 拖拽结束恢复碰撞
					apply_outline()
					# 设置层级
					get_surface_z_index()
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
				collision.disabled = false
				DragManager.stop_drag()
				return_to_backpack()

func _process(_delta):
	var collision = $CollisionShape2D
	# 如果正在拖拽中：不断将物体的位置设置为当前鼠标位置 + 拖拽偏移值
	if is_being_dragged:
		global_position = get_global_mouse_position() + drag_offset
		_check_placeable_area()
		judge_collison()
		judge_color()
		collision.disabled = true
		if can_place and judge_surface(): #change_seat == "floor" or change_seat == "surface":
			z_index = get_surface_z_index()
		else:
			z_index = 2100
	else:
		z_index = get_surface_z_index()
		judge_surface()

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
	# 如果要叠放到另一物品上
	if overlapping_furniture != null and is_overlapping:# and is_not_overlapping
		# 叠放：设置父节点为对方书的 stack_container
		var container = overlapping_furniture.get_node_or_null("StackContainer")
		if container:
			var global_pos := global_position
			# 转移到叠放容器里
			get_parent().remove_child(self)
			container.add_child(self)
			global_position = global_pos
			#global_position = overlapping_book.get_node("StackPoint").global_position

			## 选择叠放位置，调整位置为 StackPoint
			#var stack_point = overlapping_book.get_node_or_null("StackPoint")
			#global_position = stack_point.global_position
			#z_index = overlapping_book.z_index + 2
			#print("叠放在物品上")
			#overlapping_book.is_not_overlapping = false
			#print(overlapping_book.is_not_overlapping)

# 判断是否可放置（包含只接触一个可放置桌面）
func judge_surface():
	if overlap_surfaces.is_empty():
		return judge_put()
	var mat_surfaces = []
	var furniture_surfaces = []
	for i in overlap_surfaces.size():
		var area = overlap_surfaces[i]
		var other = area.get_parent()
		if other.has_meta("item_type") and other.get_meta("item_type") == "surface_mat" and not other.is_being_dragged:
			mat_surfaces.append(area)
		if other.has_meta("item_type") and (other.get_meta("item_type") == "furniture" or other.get_meta("item_type") == "carton"):
			if not other.is_being_dragged or overlapping_furniture == other:
				furniture_surfaces.append(area)
	if mat_surfaces.is_empty():
		surface_z_index = 1
	else:
		surface_z_index = 2
	if furniture_surfaces.size() == 1:
		var other = overlap_surfaces[0].get_parent()
		overlapping_furniture = other  # 记录重叠对象
		return judge_put()
	else:
		overlapping_furniture = null
		return false

# 判断进入其他可放置区域后，是否可放置
func judge_put():
	if overlap_put.is_empty():
		return true
	if placed_on_surface:
		for i in overlap_put.size():
			var other = overlap_put[i].get_parent()
			if other.has_meta("item_type"):
				if other.get_meta("item_type") == "object":
					return false
				if other.get_meta("item_type") == "carton" and other.is_overlapping:
					return false
		return true
	return false

# 根据是否可放置，改变颜色或透明度等
func judge_color():
	if can_place and judge_surface():
		modulate = Color(1, 1, 1, 1)
	else:
		modulate = Color(1, 1, 1, 0.5)  # 半透明（非法放置）

# 根据放置的位置，调节碰撞
func judge_collison():
	var collision = $CollisionShape2D
	# 自动禁用碰撞体（放在桌面上时）
	collision.disabled = placed_on_surface
	# 若放在桌面上，清除碰撞层和遮罩（防止角色碰撞）
	if placed_on_surface:
		self.set_deferred("collision_layer", 0)
		self.set_deferred("collision_mask", 0)
	else:
		collision.disabled = false
		self.set_deferred("collision_layer", 1)
		self.set_deferred("collision_mask", 1)

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

# 判断所在区是否合理，防止被推出到不可控区
func judge_push_area():
	var put_rect = get_put_rect()
	for area in get_tree().get_nodes_in_group("put_place"):
		var other = area.get_parent()
		if other.has_meta("item_type") and (other.get_meta("item_type") == "furniture" or other.get_meta("item_type") == "carton"):
			# 检查当前区域是否与物体的碰撞体或区域重叠
			var area_shape := area.get_node("CollisionShape2D")
			var area_size = area_shape.shape.extents * 2 * area.global_scale
			var area_pos = area_shape.get_global_transform().origin - area_size * 0.5
			var area_rect := Rect2(area_pos, area_size)
			# 如果当前放置矩形完全被包含
			if area_rect.intersects(put_rect) and not is_being_dragged:
				return false
	for area in get_tree().get_nodes_in_group("placeable_floor"):
		# 检查当前区域是否与物体的碰撞体或区域重叠
		var area_shape := area.get_node("CollisionShape2D")
		var area_size = area_shape.shape.extents * 2 * area.global_scale
		var area_pos = area_shape.get_global_transform().origin - area_size * 0.5
		var area_rect := Rect2(area_pos, area_size)
		# 如果当前放置矩形完全被包含
		if area_rect.encloses(put_rect) and not is_being_dragged:
			return true
	return false

# 可放置区域判断
func _check_placeable_area():
	can_place = false
	var put_rect = get_put_rect()
	# 支持桌面区域
	placed_on_surface = false
	for area in get_tree().get_nodes_in_group("placeable_surface"):
		if not area is Area2D:
			continue
		var area_shape := area.get_node("CollisionShape2D")
		if area_shape == null or not area_shape.shape is RectangleShape2D:
			continue
		var area_size = area_shape.shape.extents * 2 * area.global_scale
		var area_pos = area_shape.get_global_transform().origin - area_size * 0.5
		var area_rect := Rect2(area_pos, area_size)
		if area_rect.encloses(put_rect):
			can_place = true
			placed_on_surface = true
			is_overlapping = true
			change_seat = "surface"
			return
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
			is_overlapping = false
			change_seat = "floor"
			return
	for area in get_tree().get_nodes_in_group("placeable_wall"):
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
			change_seat = "wall"
			return
	change_seat = null

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

# 动态地获取层级
func get_surface_z_index():
	if overlapping_furniture and is_overlapping:
		var oavr_marker = overlapping_furniture.get_node("Sprite2D").get_node("ShelterBase")
		var z_index_offset = 100 / (oavr_marker.global_position.y - $Sprite2D/ShelterBase.global_position.y) 
		return overlapping_furniture.z_index +  z_index_offset
	return $Sprite2D/ShelterBase.global_position.y

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

# 保存数据提取
func get_save_data():
	return {
		"id": item_data.get("id", ""),
		"position": position
	}

# 物品拖出时状态
func first_ex_drag():
	if DragManager.start_drag(self):
		is_being_dragged = true
		one_dragging = true
		DragManager.request_highlight(self)

# 开启/关闭描边
func apply_outline():
	outline_sprite.visible = true

func clear_outline():
	outline_sprite.visible = false

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
	var other = area.get_parent()
	# 若进入的区域也是可放置物品的区域
	if area.is_in_group("put_place") and other != self:  # 放置物品加个 group
		if not overlap_put.has(area):
			overlap_put.append(area)
	# 进入的区域是桌面类区域
	if area.is_in_group("placeable_surface"):
		if not overlap_surfaces.has(area):
			overlap_surfaces.append(area)

func _on_area_exited(area):
	if area.is_in_group("put_place"):
		overlap_put.erase(area)
	if area.is_in_group("placeable_surface"):
		overlap_surfaces.erase(area)
		if overlap_surfaces.is_empty() and not is_overlapping:
			overlapping_furniture = null
