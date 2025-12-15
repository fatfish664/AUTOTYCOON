extends Node

var iron_shelf = 1
var depot_items = [] # 仓库物品数组
var refrigerator_items = [] # 冰箱中物品的数组
var cur_id = 0

func _ready() -> void:
	refrigerator_items.resize(9)

# 计算物品的数量
func count_item():
	var counts = 0
	for item in depot_items:
		if item != null and item.has("id") and item.has("count"):
			counts += item["count"]
	return counts

func save_depot_items(inventory_id):
	# 简化储存仓库的内容
	var cleaned_depot = []
	cleaned_depot.clear()
	for item in depot_items:
		if item != null and item.has("id") and item.has("count"):
			cleaned_depot.append({
				"id": item["id"],
				"count": int(item["count"])
			})
		else:
			cleaned_depot.append(null)
	var save_data = { "depot": cleaned_depot }
	var file = FileAccess.open("user://depotitem%d.save" % inventory_id, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("游戏数据已保存")
		depot_items.clear()

func load_depot_items(inventory_id):
	depot_items.clear()
	if not FileAccess.file_exists("user://depotitem%d.save" % inventory_id):
		print("未找到保存文件，使用默认数据")
		return
	var file = FileAccess.open("user://depotitem%d.save" % inventory_id, FileAccess.READ)
	#print("user://depotitem%d.save" % inventory_id)
	var content = file.get_as_text()
	#print("【读取到的原始 JSON】:", content)
	var result = JSON.parse_string(content)
	#print("【解析后的 result 类型】:", typeof(result), ", 内容:", result)
	if typeof(result) == TYPE_DICTIONARY:
		var save_depot = result.get("depot", [])
		for item in save_depot:
			if item == null:
				depot_items.append(null)
			else:
				# 从 all_items 中查找完整数据
				var full_item = null
				for i in GameManager.all_items:
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
					depot_items.append(new_item)
				else:
					depot_items.append(null)
	if depot_items.is_empty():
		depot_items.resize(50)
