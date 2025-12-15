extends TextureRect

# 自定义信号：当物品被拖出时触发，携带物品数据
signal item_dragged_out(item_data: Dictionary)

@export var item_data: Dictionary = {}  # 导出变量：存储物品信息的字典
@onready var icon = $Icon   # 该物品的图标控件（子节点）
@onready var highlight = $Highlight  # 鼠标悬停时显示的高亮图层
@onready var count_label = $CountLabel # 显示数量的 Label
var mouse_pos: Vector2 # 拖拽开始位置
var dragging_threshold := 8  # 拖动多少像素才算拖拽
var is_dragging_item = false # 是否在拖拽
var dragging_begin = false # 拖拽是否开始
var last_click_time := 0.0 # 记录上次点击的时间
const DOUBLE_CLICK_TIME := 0.3  # 双击最大间隔（秒）

func _ready():
	add_to_group("Backpackslot")
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	# 设置鼠标过滤器为"穿透"模式，允许鼠标事件传递到该控件
	mouse_filter = MOUSE_FILTER_PASS 
	# 显示初始图标纹理
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_display()

func _process(_delta):
	var mouse_distance = mouse_pos.distance_to(get_viewport().get_mouse_position())
	if dragging_begin and mouse_distance > dragging_threshold:
		drag_create(get_viewport().get_mouse_position())

# 判断是否允许放置(背包内物品交换)：
#func can_drop_data(_position, data):
	#return data is Dictionary and data.has("item_data")
#
## 物品放置与接收（背包内物品交换）
#func drop_data(_position, data):
	#if data is Dictionary:
		#var incoming = data["item_data"]  # 获取拖入的物品数据
		#var outgoing = item_data         # 当前槽位的物品数据
		#item_data = incoming  # 更新当前槽位数据
		#icon.texture = incoming.get("icon", null)
		#var from_slot = data["from_slot"]
		#from_slot.item_data = outgoing
		#from_slot.icon.texture = outgoing.get("icon", null)

# 拖出背包 → 在世界生成物品 || 右键移出物品到仓库
func _gui_input(event):
	# 检查当前事件是不是鼠标按键事件
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var now = Time.get_ticks_msec() / 1000.0
			if now - last_click_time < DOUBLE_CLICK_TIME:
				_on_double_click()
			last_click_time = now
		if not DragManager.is_edit_mode:
			if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				print("尝试移动：", item_data.get("name"))
				_remove_item()
			return  # 如果不在编辑模式，禁止响应拖拽操作
		# 如果是左键按下,记录当前位置 event.position 为 drag_start_position，用来后续判断是否拖拽
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# 如果背包格子没有物品，不触发拖拽
			if item_data.is_empty() or not item_data.has("id"):
				return
			# 获取当前全局鼠标位置
			mouse_pos = get_viewport().get_mouse_position()
			dragging_begin = true

func drag_create(p):
	if item_data.is_empty() or not item_data.has("id"):
		return # 空格子不处理拖拽逻辑
	highlight.visible = false  # 取消高亮
	# 创建一个拖拽预览图（显示物品图标的缩略图）
	var drag_preview := TextureRect.new()
	drag_preview.texture = icon.texture
	drag_preview.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	drag_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emit_signal("item_dragged_out", item_data)
	# 查找背包面板控件节点（背包 CanvasLayer节点）
	var backpack_ui = get_tree().get_first_node_in_group("Backpack")
	# 用背包面板的位置和尺寸构造一个Rect2，表示背包的区域范围
	var backpack_rect = Rect2(backpack_ui.inventory_panel.get_screen_transform().origin,
		backpack_ui.inventory_panel.size
		)
	#print("2")
	#print(GameManager.mouse_pos)
	#print(backpack_rect)
	#print(backpack_rect.has_point(p))
	if not backpack_rect.has_point(p):
		# 生成物品
		#print("生成物品中...")
		get_tree().call_group("Backpack", "spawn_item_in_world", get_global_mouse_position(), item_data)
		# 减少数量
		item_data["count"] -= 1
		if item_data["count"] <= 0:
			DragManager.cur_item_id = str(item_data["id"])
			item_data.clear()
		_update_display()
		#print(item_data)
		dragging_begin = false
		is_dragging_item = false

# 移动物品到仓库等地
func _remove_item():
	if not item_data.has("id"):
		return
	var inventory = get_open_inventory()
	if inventory == null:
		print("没找到仓库")
		return
	if inventory.inmigrant_item(item_data):
		item_data["count"] -= 1
		if item_data["count"] <= 0:
			item_data.clear()
		_update_display()

# 得到当前打开的仓库
func get_open_inventory():
	for inventory in get_tree().get_nodes_in_group("depot_ui"):
		if inventory.visible:
			return inventory
	return null  # 没有找到打开的仓库

func refrigertor_inventory():
	for inventory in get_tree().get_nodes_in_group("refrigerator_ui"):
			if inventory.visible:
				return inventory
	return null  # 没有找到打开的仓库

# 更新图标与数量
func _update_display():
	# 刷新图标
	if item_data.has("icon"):
		icon.texture = item_data["icon"]
	else:
		icon.texture = null
	# 更新数量文本
	if count_label:
		count_label.anchor_right = 1.0
		count_label.anchor_bottom = 1.0
		count_label.offset_right = -4
		count_label.offset_bottom = -4
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count_label.label_settings = LabelSettings.new()
		count_label.label_settings.font_size = 12
		count_label.label_settings.font_color = Color.GREEN
		count_label.label_settings.outline_color = Color.BLACK
		count_label.label_settings.outline_size = 3
		if item_data.has("count") and item_data["count"] > 1:
			count_label.text = str(item_data["count"])
			count_label.visible = true
		else:
			count_label.visible = false

# 双击后对物品进行使用
func _on_double_click():
	if item_data.has("type") and item_data["type"] == "drink":
		var players = get_tree().get_nodes_in_group("player")
		for player in players:
			player.relax_stamina(10)
			player.play_animation("drink", "drinks")
		# 消耗一瓶饮料
		item_data["count"] -= 1
		if item_data["count"] <= 0:
			DragManager.cur_item_id = str(item_data["id"])
			item_data.clear()
		_update_display()

# 高亮的打开与关闭
func _on_mouse_entered():
	highlight.visible = true

func _on_mouse_exited():
	highlight.visible = false
