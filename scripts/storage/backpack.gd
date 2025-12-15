extends CanvasLayer

@onready var toggle_button = $ToggleButton # 用于切换库存面板的按钮
@onready var inventory_panel = $InventoryPanel # 实际的库存面板容器

# 标记背包当前是否展开
var is_open := false
# 存储面板打开和关闭时的位置
var panel_closed_pos: Vector2
var panel_open_pos: Vector2
# 添加书物品数据

func _ready():
	add_to_group("Backpack") # 加入"Backpack"组便于全局访问
	# 把初始化的背包内的数据装进背包
	for i in GameManager.backpack_items.size():
		add_item_to_slot(i, GameManager.backpack_items[i])
	# 获取视口尺寸
	var viewport_rect = get_viewport().get_visible_rect()
	# 设置面板最小尺寸
	inventory_panel.custom_minimum_size = Vector2(100, 100)
	# 计算面板实际尺寸
	var panel_size = inventory_panel.get_combined_minimum_size()
	# 计算打开/关闭位置（垂直居中）
	panel_open_pos = Vector2(viewport_rect.size.x - panel_size.x, (viewport_rect.size.y - panel_size.y) / 2)
	panel_closed_pos = Vector2(viewport_rect.size.x, (viewport_rect.size.y - panel_size.y) / 2)
	# 初始位置设为关闭状态
	inventory_panel.position = panel_closed_pos
	# 连接按钮信号
	toggle_button.pressed.connect(_on_toggle_button_pressed)
	# 定位按钮到右下角
	toggle_button.position = Vector2(
	viewport_rect.size.x - toggle_button.size.x - 10,
	viewport_rect.size.y - toggle_button.size.y - 10)

# 背包格子中拖出一个物品后，会调用这个函数，在世界中放置对应的物体。
func spawn_item_in_world(screen_pos: Vector2, item_data: Dictionary):
	if not DragManager.is_edit_mode:
		return  # 如果不在编辑模式，禁止响应拖拽操作
	# 从item_data字典中获取"id"字段，如果没有则返回空字符串
	var item_id = item_data.get("id", "")
	# 检查item_scene_map字典中是否有该物品ID对应的场景
	if not GameManager.item_scene_map.has(item_id):
		print("未找到对应的场景")
		return
	var main_scene = get_tree().get_first_node_in_group("editable")  # 主场景路径
	if main_scene == null:
		print("未找到主场景节点")
		return
	var world = main_scene.get_node_or_null("World")
	if world == null:
		print("未找到 World 节点")
		return
	# 从item_scene_map中获取对应物品ID的场景
	var item_scene = GameManager.item_scene_map[item_id]
	var item_instance = item_scene.instantiate()
	# 转换屏幕坐标为世界坐标
	var camera = world.get_viewport().get_camera_2d()
	#print("获取摄像机:", camera)
	var world_pos = camera.get_screen_transform().affine_inverse() * screen_pos
	# 设置物品位置和数据
	item_instance.global_position = world_pos
	item_instance.item_data = item_data.duplicate() # 深拷贝一份数据，避免原数据被改
	# 主动调用 item_instance.set_process_input(true)，让它接收 _input
	item_instance.set_process_input(true)
	item_instance.set_process(true)  # 如果 _process 里控制拖动
	item_instance.first_ex_drag()
	#print("准备实例化: ", item_id)
	#print("目标位置: ", world_pos)
	# 将物品实例作为子节点添加到主场景中
	world.add_child(item_instance)

# 自动继续拖出一个新的物品
func auto_drag_item(item_id: String):
	var grid = $InventoryPanel/GridContainer
	for i in grid.get_child_count():
		var slot = grid.get_child(i)
		if slot.item_data.has("id"):
			if item_id == slot.item_data["id"]:
				slot.drag_create(get_viewport().get_mouse_position())

# 获取相应id的数量
func get_item_count(item_id: String) -> int:
	var grid = $InventoryPanel/GridContainer
	for i in grid.get_child_count():
		var slot = grid.get_child(i)
		if slot.item_data.has("id"):
			if item_id == slot.item_data["id"]:
				return slot.item_data["count"]
	return 0

# 从上往下查找空背包格子
func search_empty_slot():
	var grid = $InventoryPanel/GridContainer
	for i in grid.get_child_count():
		var slot = grid.get_child(i)
		if slot.icon.texture == null:
			return i + 1
	return 0

# 添加的物品在背包是否有,有的话数量加一
func search_same_item(item_id: String):
	var grid = $InventoryPanel/GridContainer
	for i in grid.get_child_count():
		var slot = grid.get_child(i)
		if slot.item_data.has("id"):
			if item_id == slot.item_data["id"]:
				slot.item_data["count"] += 1
				slot._update_display()
				update_bacpack(i, slot.item_data)
				return true
	return false

# 用于填入格子
func add_item_to_slot(index: int, data):
	if data == null:
		return
	var grid = $InventoryPanel/GridContainer
	if index >= 0 and index < grid.get_child_count():
		var slot = grid.get_child(index)
		slot.item_data = data.duplicate()
		slot.icon.texture = data.get("icon", null)
		slot.count_label.text = str(data.get("count", null))
		slot._update_display()
		update_bacpack(index, slot.item_data)

# 购买物品函数（加入金钱系统后会更改）
func buy_shop(shop_item: Dictionary):
	print("buy", shop_item)
	if search_same_item(shop_item["id"]):
		return true
	var i = search_empty_slot() - 1
	if i == -1:
		return false
	add_item_to_slot(i, shop_item)
	return true

# 移入物品函数
func move_item(depot_item: Dictionary):
	var item = depot_item.duplicate()
	if search_same_item(item["id"]):
		return true
	var i = search_empty_slot() - 1
	if i == -1:
		return false
	item["count"] = 1
	add_item_to_slot(i, item)
	return true

# 把物品回收至背包
func return_item(item_id: String):
	if item_id == "empty":
		return false
	if search_same_item(item_id):
		return true
	for item in GameManager.all_items:
		if item_id == item["id"]:
			var i = search_empty_slot() - 1
			item["count"] = 1
			add_item_to_slot(i, item)
			return true

func update_bacpack(i : int, data):
	GameManager.backpack_items[i] = data

# 打开或收起背包 
func _on_toggle_button_pressed():
	is_open = !is_open # 切换状态
	if is_open:
		show_inventory()
	else:
		hide_inventory()

func show_inventory():
	# 使用动画平滑显示
	var tween = create_tween()
	tween.tween_property(inventory_panel, "position", panel_open_pos, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func hide_inventory():
	var tween = create_tween()
	tween.tween_property(inventory_panel, "position", panel_closed_pos, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
