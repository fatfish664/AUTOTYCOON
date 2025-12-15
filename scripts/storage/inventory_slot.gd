extends MarginContainer

@onready var button := $Button
@onready var highlight = $Highlight  # 鼠标悬停时显示的高亮图层
@onready var icon = $Icon   # 该物品的图标控件（子节点）
@onready var count_label = $CountLabel # 显示数量的 Label

var item_data: Dictionary # 存储物品信息的字典

func _ready():
	@warning_ignore("shadowed_variable")
	var icon = $Icon
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 设置按钮为透明
	button.flat = true
	button.text = ""
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	# 监听按钮点击
	button.connect("gui_input", _on_button_gui_input)
	# 显示初始图标纹理
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_display()

# 加载后，进行数据载入
func set_item(data: Dictionary):
	item_data = data.duplicate()
	_update_display()

# 更新格子的显示
func _update_display():
	@warning_ignore("shadowed_variable")
	var icon = $Icon
	@warning_ignore("shadowed_variable")
	var count_label = $CountLabel
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

# 点击右键触发
func _on_button_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		remove_item()

# 把一个物品移出仓库到背包
func remove_item():
	if not item_data.has("id") or item_data["id"] == "":
		return
	var backpack = get_tree().get_first_node_in_group("Backpack")
	if backpack and backpack.has_method("move_item"):
		if backpack.move_item(item_data):
			item_data["count"] -= 1
		update_depot_items()
		if item_data["count"] <= 0:
			item_data = { "id": "", "name": "", "price": 0, "icon": null, "count": 0 }
		_update_display()

# 更新保存的数据
func update_depot_items():
	var now_size = 0
	for item in DepotManager.depot_items:
		if item != null and item["id"] == item_data["id"]:
			DepotManager.depot_items[now_size]["count"] -= 1
		if item != null and DepotManager.depot_items[now_size]["count"] <= 0:
			DepotManager.depot_items[now_size] = { "id": "", "name": "",
			"price": 0, "icon": null, "count": 0 }
		now_size += 1

# 高亮的打开与关闭
func _on_mouse_entered():
	highlight.visible = true

func _on_mouse_exited():
	highlight.visible = false
