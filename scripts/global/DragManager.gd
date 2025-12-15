extends Node

var is_edit_mode := false # 是否进入编辑模式
var shift_auto_drag_mode := false # 是否进入连续拖拽模式
var active_item :Node= null  # 当前正在被拖动的物体
var cur_item_id : String = "empty"# 建立一个临时的id，保存当前拖拽的物品id，方便拾取回收
var has_been_recycled := false  # 控制是否已被回收(保证一次回收一个物品)
var recently_dropped = false # 延缓拖拽，避免放下拿起在同一次按下触发
var current_hovered = null # 目前鼠标指向的目标
var current_z = -INF # 目前最大的层级
var cur_point_items = [] # 目前鼠标指向的物品集

# 比较鼠标区域物品的层级，层级高的高亮
func request_highlight(target_node: Node2D):
	if not is_edit_mode or target_node == null:
		return
	if not target_node in cur_point_items:
		cur_point_items.append(target_node)
	if target_node.z_index > current_z and active_item == null:
		# 清除旧的高亮
		if current_hovered and current_hovered != target_node:
			current_hovered.clear_outline()
			if current_hovered.has_method("has_gplate"):
				current_hovered.gplate_sprite.visible = false
		# 设定新的高亮目标
		current_hovered = target_node
		current_z = target_node.z_index
		target_node.apply_outline()

func clear_if_hovered(node: Node2D):
	cur_point_items.erase(node)
	current_z = -INF
	node.clear_outline()
	if node == current_hovered:
		if cur_point_items.is_empty():
			current_hovered = null
		else:
			for item in cur_point_items:
				if is_instance_valid(item):
					request_highlight(item)
				else:
					cur_point_items.erase(item)

# 限制一次只能抓取一只物品
func start_drag(item):
	if active_item != null:
		return false  # 已有拖动中，禁止开始新的
	active_item = item
	return true

func stop_drag():
	active_item = null

# 是否启动连续拖拽模式（按住shift启动）
func _unhandled_input(event):
	if event is InputEventKey and event.keycode == KEY_SHIFT:
		if event.pressed:
			shift_auto_drag_mode = true
		else:
			shift_auto_drag_mode = false

# 物体旋转事件
func _input(_event):
	if Input.is_action_just_pressed("rotate_left") and active_item != null:
		if active_item.has_method("replace_with_rotated_version"):
			print(1234)
			if active_item.item_direction == "front":
				active_item.replace_with_rotated_version("left")
				return
			if active_item.item_direction == "left":
				active_item.replace_with_rotated_version("back")
				return
			if active_item.item_direction == "back":
				active_item.replace_with_rotated_version("right")
				return
			if active_item.item_direction == "right":
				active_item.replace_with_rotated_version("front")
				return
	if Input.is_action_just_pressed("rotate_right") and active_item != null:
		if active_item.has_method("replace_with_rotated_version"):
			if active_item.item_direction == "front":
				active_item.replace_with_rotated_version("right")
				return
			if active_item.item_direction == "right":
				active_item.replace_with_rotated_version("back")
				return
			if active_item.item_direction == "back":
				active_item.replace_with_rotated_version("left")
				return
			if active_item.item_direction == "left":
				active_item.replace_with_rotated_version("front")
				return
