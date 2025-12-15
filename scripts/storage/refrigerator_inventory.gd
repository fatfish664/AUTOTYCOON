extends CanvasLayer

@onready var panel = $NinePatchRect
@onready var header = $NinePatchRect/Header
@onready var close_button = $NinePatchRect/CloseButton
@onready var close_bg = $NinePatchRect/CloseButtonBackground
@onready var title = $NinePatchRect/Header/Title

const depotItemSlotScene = preload("res://scenes/storages/inventory_slot.tscn")

func _ready():
	add_to_group("refrigerator_ui")
	show_depot(DepotManager.refrigerator_items)
	_set_layout()
	visible = false
	close_button.pressed.connect(_on_close_pressed)

# 加载仓库的物品数据
func show_depot(items: Array):
	var grid = $NinePatchRect/GridContainer
	# 清空旧商品
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for item_data in items.duplicate():
		var slot = depotItemSlotScene.instantiate()
		if item_data == null:
			item_data = { "id": "", "name": "", "price": 0, "icon": null, "count": 0 }
		slot.set_item(item_data)
		grid.add_child(slot)

# 用于填入格子
func add_item_to_slot(index: int, data):
	if data == null:
		return
	var grid = $NinePatchRect/GridContainer
	if index >= 0 and index < grid.get_child_count():
		var slot = grid.get_child(index)
		slot.item_data = data.duplicate()
		slot.item_data["count"] = 1
		slot.icon.texture = data.get("icon", null)
		slot.count_label.text = str(data.get("count", null))
		slot._update_display()
		DepotManager.refrigerator_items[index] = slot.item_data.duplicate()

# 添加的物品在背包是否有,有的话数量加一
func search_same_item(item_id: String):
	var grid = $NinePatchRect/GridContainer
	for i in grid.get_child_count():
		var slot = grid.get_child(i)
		if slot.item_data.has("id"):
			if item_id == slot.item_data["id"]:
				slot.item_data["count"] += 1
				slot._update_display()
				DepotManager.refrigerator_items[i]["count"] += 1
				return true
	return false

# 从上往下查找空背包格子
func search_empty_slot():
	var grid = $NinePatchRect/GridContainer
	for i in grid.get_child_count():
		var slot = grid.get_child(i)
		if slot.icon.texture == null:
			return i + 1
	return 0

# 物品移入冰箱仓库
func inmigrant_item(item: Dictionary):
	if item.has("type") and item["type"] == "drink":
		if search_same_item(item["id"]):
			return true
		var i = search_empty_slot() - 1
		if i == -1:
			return false
		add_item_to_slot(i, item)
		return true

# 设置仓库界面的面板
func _set_layout():
	var grid = $NinePatchRect/GridContainer
	# 居中面板
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -200
	panel.offset_top = -220
	panel.offset_right = 200
	panel.offset_bottom = 220
	# 设置header信息区域
	header.anchor_left = 0.0
	header.anchor_top = 0.0
	header.anchor_right = 1.0
	header.anchor_bottom = 0.0
	header.offset_left = 20
	header.offset_right = -20
	header.offset_top = 10
	header.offset_bottom = 50
	# 设置标题居中对齐
	title.text = "冰箱仓库"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # 横向填满，保证居中
	# 格子布局
	grid.columns = 3  # 10列
	grid.anchor_left = 0.0
	grid.anchor_top = 0.0
	grid.anchor_right = 1.0
	grid.anchor_bottom = 1.0
	grid.offset_left = 20
	grid.offset_top = 70
	grid.offset_right = -20
	grid.offset_bottom = -60
	var spacing = 8
	grid.add_theme_constant_override("h_separation", spacing)
	grid.add_theme_constant_override("v_separation", spacing)
	# 计算可用宽度（面板宽度 - 左右间距 - 列间距）
	var available_width = panel.size.x - 40 - (spacing * (grid.columns - 1))
	var slot_size = floor(available_width / grid.columns)
	# 遍历所有格子节点，让它们正方形
	for slot in grid.get_children():
		slot.custom_minimum_size = Vector2(slot_size, slot_size)
	# 关闭按钮放右上角
	close_bg.anchor_left = 1.0
	close_bg.anchor_top = 0.0
	close_bg.anchor_right = 1.0
	close_bg.anchor_bottom = 0.0
	close_bg.offset_left = -40
	close_bg.offset_top = 8
	close_bg.offset_right = -8
	close_bg.offset_bottom = 40

	close_button.anchor_left = 1.0
	close_button.anchor_top = 0.0
	close_button.anchor_right = 1.0
	close_button.anchor_bottom = 0.0
	close_button.offset_left = -40
	close_button.offset_top = 8
	close_button.offset_right = -8
	close_button.offset_bottom = 40
	close_button.flat = true
	close_button.text = ""

func _on_close_pressed():
	DepotManager.save_depot_items(DepotManager.cur_id)
	hide()
