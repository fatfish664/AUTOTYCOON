extends Node

# 全局变量
var next_scene_path: String
var spawn_door_id: String = ""  # 记录进门的ID
var mouse_pos  # 鼠标的实时位置
var backpack_items = [] # 初始化10格背包（全部为空）
var shop_items = [] # 商店物品数组
var dev_zoom = 0.5

func _ready():
	randomize() # 初始化随机种子
	load_game()
	#if shop_items == null:
	fill_shop_with_random_items(20)
	if backpack_items.is_empty():
		backpack_items.resize(10)
		backpack_items.fill(null)
	# 监听退出信号（比 _notification 更可靠）
	get_tree().root.connect("tree_exiting", Callable(self, "save_game"))

func _process(_delta):
	mouse_pos = get_viewport().get_mouse_position()

# 物品 ID → 物品场景（.tscn）的映射表。
var item_scene_map: Dictionary = {
	"book": preload("res://scenes/furnitures/book.tscn"),
	"cola": preload("res://scenes/drinks/cola.tscn"),
	"desk": preload("res://scenes/furnitures/desk.tscn"),
	"bed": preload("res://scenes/furnitures/bed.tscn"),
	"blue_chair": preload("res://scenes/furnitures/seats_1_front_blue.tscn"),
	"box_1": preload("res://scenes/furnitures/box_1.tscn"),
	"cup": preload("res://scenes/furnitures/cup.tscn"),
	"glass_plate": preload("res://scenes/furnitures/glass_plate.tscn"),
	"double_gplate": preload("res://scenes/furnitures/double_gplate.tscn"),
	"moka_pot": preload("res://scenes/furnitures/moka_pot.tscn"),
	"paper": preload("res://scenes/furnitures/paper.tscn"),
	"tea_mat": preload("res://scenes/furnitures/tea_mat.tscn"),
	"tea_table": preload("res://scenes/furnitures/tea_table.tscn"),
	"tea_table_1": preload("res://scenes/furnitures/tea_table_1.tscn"),
	"tea": preload("res://scenes/furnitures/tea.tscn"),
	"tea_1": preload("res://scenes/furnitures/tea_1.tscn"),
	"tea_3": preload("res://scenes/furnitures/tea_3.tscn"),
	"carton": preload("res://scenes/furnitures/carton_front.tscn"),
	"carton_left": preload("res://scenes/furnitures/carton_left.tscn"),
	"carton_back": preload("res://scenes/furnitures/carton_back.tscn"),
	"carton_right": preload("res://scenes/furnitures/carton_right.tscn"),
	"shelves_1": preload("res://scenes/furnitures/special/shelves_1.tscn"),
	"sofa": preload("res://scenes/furnitures/sofa_front.tscn"),
	"sofa_down": preload("res://scenes/furnitures/sofa_back.tscn"),
	"sofa_right": preload("res://scenes/furnitures/sofa_right.tscn"),
	"refrigerator": preload("res://scenes/furnitures/special/refrigerator_front.tscn"),
	"refrigerator_left": preload("res://scenes/furnitures/special/refrigerator_left.tscn"),
	"refrigerator_back": preload("res://scenes/furnitures/special/refrigerator_back.tscn"),
	"refrigerator_right": preload("res://scenes/furnitures/special/refrigerator_right.tscn"),
	"water_dispenser": preload("res://scenes/furnitures/special/water_dispenser.tscn"),
	"Magnet1": preload("res://scenes/furnitures/refrigerator_magnet_1.tscn"),
	"work_place": preload("res://scenes/furnitures/special/work_place.tscn"),
}

# 所有可用物品库
var all_items = [
	{ "id": "book", "name": "书", "price": 30, "icon": preload("res://art_resource/changjing/book.png"), "count": 1 },
	{ "id": "desk", "name": "桌子", "price": 80, "icon": preload("res://art_resource/changjing/desk.png"), "count": 1 },
	{ "id": "bed", "name": "床", "price": 70, "icon": preload("res://art_resource/changjing/bed.png"), "count": 1 },
	{ "id": "cola", "name": "可乐", "type": "drink", "price": 10, "icon": preload("res://art_resource/changjing/drinks_2.png"), "count": 1 },
	{ "id": "wine", "name": "葡萄酒", "price": 90, "icon": preload("res://art_resource/changjing/drinks_2.png"), "count": 1 },
	{ "id": "milk", "name": "牛奶", "price": 25, "icon": preload("res://art_resource/changjing/drinks_1.png"), "count": 1 },
	{ "id": "blue_chair", "name": "蓝椅子", "price": 200, "icon": preload("res://art_resource/thing/Seats1_blue_icon.png"), "count": 1 },
	{ "id": "box_1", "name": "盒子1", "price": 1, "icon": preload("res://art_resource/Fewobject/Box1.png"), "count": 1 },
	{ "id": "cup", "name": "杯子", "price": 1, "icon": preload("res://art_resource/Fewobject/Cup.png"), "count": 1 },
	{ "id": "glass_plate", "name": "玻璃杯", "price": 1, "icon": preload("res://art_resource/Fewobject/Glass plate.png"), "count": 1 },
	{ "id": "double_gplate", "name": "叠放杯", "price": 2, "icon": preload("res://art_resource/Fewobject/Glass plate_pile up.png"), "count": 1 },
	{ "id": "moka_pot", "name": "咖啡壶", "price": 1, "icon": preload("res://art_resource/Fewobject/Moka pot.png"), "count": 1 },
	{ "id": "paper", "name": "卷纸", "price": 1, "icon": preload("res://art_resource/Fewobject/Paper.png"), "count": 1 },
	{ "id": "tea_mat", "name": "茶垫", "price": 1, "icon": preload("res://art_resource/Fewobject/Tea mat.png"), "count": 1 },
	{ "id": "tea_table", "name": "茶桌", "price": 1, "icon": preload("res://art_resource/Fewobject/Tea table.png"), "count": 1 },
	{ "id": "tea_table_1", "name": "茶桌1", "price": 1, "icon": preload("res://art_resource/Fewobject/Tea table_1.png"), "count": 1 },
	{ "id": "tea", "name": "茶", "price": 1, "icon": preload("res://art_resource/Fewobject/Tea.png"), "count": 1 },
	{ "id": "tea_1", "name": "茶1", "price": 1, "icon": preload("res://art_resource/Fewobject/Tea_1.png"), "count": 1 },
	{ "id": "tea_3", "name": "茶3", "price": 1, "icon": preload("res://art_resource/Fewobject/Tea_3.png"), "count": 1 },
	{ "id": "carton", "name": "箱子", "price": 1, "icon": preload("res://art_resource/Fewobject/carton_up.png"), "count": 1 },
	{ "id": "shelves_1", "name": "仓库架", "price": 10, "icon": preload("res://art_resource/thing/Seats1_blue_icon.png"), "count": 1 },
	{ "id": "sofa", "name": "沙发", "price": 10, "icon": preload("res://art_resource/thing/Seats1_blue_icon.png"), "count": 1 },
	{ "id": "refrigerator", "name": "冰箱", "price": 5, "icon": preload("res://art_resource/thing/Seats1_blue_icon.png"), "count": 1 },
	{ "id": "water_dispenser", "name": "饮水机", "price": 5, "icon": preload("res://art_resource/thing/Seats1_blue_icon.png"), "count": 1 },
	{ "id": "Magnet1", "name": "贴纸1", "price": 1, "icon": preload("res://art_resource/player1_drink/refrigerator magnet_1.png"), "count": 1 },
	{ "id": "work_place", "name": "工作位", "price": 10, "icon": preload("res://art_resource/thing/Seats1_blue_icon.png"), "count": 1 },
]

# 通过ID查找物品的函数
func find_item_by_id(item_id):
	for item in all_items:
		if item["id"] == item_id:
			return item
	return null  # 未找到返回null

# 随机填充商店物品
func fill_shop_with_random_items(amount: int):
	shop_items.clear()
	for i in range(amount):
		# 随机选择一个物品模板
		var random_index = randi() % all_items.size()
		var template = all_items[random_index]
		var new_item = template.duplicate()
		shop_items.append(new_item)

# 保存游戏数据
func save_game():
	# 简化储存背包和商店的内容
	var cleaned_backpack := []
	for item in backpack_items:
		if item != null and item.has("id") and item.has("count"):
			cleaned_backpack.append({
				"id": item["id"],
				"count": int(item["count"])
			})
		else:
			cleaned_backpack.append(null)
	var cleaned_shop := []
	for item in shop_items:
		if item != null and item.has("id") and item.has("count"):
			cleaned_shop.append({
				"id": item["id"],
				"count": int(item["count"])
			})
		else:
			cleaned_shop.append(null)
	var save_data = {
		"backpack": cleaned_backpack,
		"shop": cleaned_shop,
	}
	var file = FileAccess.open("user://savegame.save", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("背包商店游戏数据已保存")

# 加载游戏数据
func load_game():
	if not FileAccess.file_exists("user://savegame.save"):
		print("未找到保存文件，使用默认数据")
		return
	var file = FileAccess.open("user://savegame.save", FileAccess.READ)
	var content = file.get_as_text()
	var result = JSON.parse_string(content)
	if typeof(result) == TYPE_DICTIONARY:
		var saved_backpack = result.get("backpack", [])
		var saved_shop = result.get("shop", [])
		backpack_items = []
		for item in saved_backpack:
			if item == null:
				backpack_items.append(null)
			else:
				# 从 all_items 中查找完整数据
				var full_item = null
				for i in all_items:
					if i.get("id", "") == item.get("id", ""):
						full_item = i
						break
				if full_item:
					var new_item = {
						"id": item["id"],
						"name": full_item["name"],
						"count": int(item["count"]),
						"icon": full_item["icon"],
						"price": full_item.get("price", 0)
					}
					if full_item.has("type"):
						new_item["type"] = full_item["type"]
					backpack_items.append(new_item)
				else:
					backpack_items.append(null)
		shop_items = []
		for item in saved_shop:
			if item == null:
				shop_items.append(null)
			else:
				# 从 all_items 中查找完整数据
				var full_item = null
				for i in all_items:
					if i.get("id", "") == item.get("id", ""):
						full_item = i
						break
				if full_item:
					var new_item = {
						"id": item["id"],
						"name": full_item["name"],
						"count": int(item["count"]),
						"icon": full_item["icon"],
						"price": full_item.get("price", 0)
					}
					shop_items.append(new_item)
				else:
					shop_items.append(null)
		print("游戏数据已加载")

# 自动保存（退出前）
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
