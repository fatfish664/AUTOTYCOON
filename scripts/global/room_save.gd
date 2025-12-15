extends Node

var world_items: Array = [] # 用于存储世界中的物品（id 和坐标）
var all_room_id = [101, 102, 103, 104]
var room_id = 102  # 用来临时记录进入或出去的房间id

func save_world_items():
	world_items.clear()
	# 检查是否已挂在场景树中
	if get_tree() == null:
		print("无法访问 SceneTree，跳过保存世界物品")
		return
	var scene_root = get_tree().get_first_node_in_group("editable")
	if scene_root == null:
		print("未找到 editable 主节点")
		return
	var world = scene_root.get_node_or_null("World")
	if world == null:
		print("未找到 World 节点")
		return
	for node in world.get_children():
		if node.has_method("get_save_data"):
			print(node)
			print("有 get_save_data 方法，加入保存")
			world_items.append(node.get_save_data())
		else:
			print("无 get_save_data 方法，跳过")
	var save_data = {
		"world_items": world_items
	}
	var file = FileAccess.open("user://instantiationitem%d.save" % room_id, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("游戏数据已保存")

func load_world_items():
	if not FileAccess.file_exists("user://instantiationitem%d.save" % room_id):
		print("未找到保存文件，使用默认数据")
		return
	var file = FileAccess.open("user://instantiationitem%d.save" % room_id, FileAccess.READ)
	var content = file.get_as_text()
	#print("【读取到的原始 JSON】:", content)
	var result = JSON.parse_string(content)
	#print("【解析后的 result 类型】:", typeof(result), ", 内容:", result)
	if typeof(result) == TYPE_DICTIONARY:
		world_items = result.get("world_items", [])
		var scene_root = get_tree().get_first_node_in_group("editable")
		if scene_root == null:
			print("未找到 editable 主场景")
			return
		var world = scene_root.get_node_or_null("World")
		if world == null:
			print("未找到 World 节点")
			return
		#print("World items 个数：", world_items.size())
		for item in world_items:
			var id = item.get("id", "")
			var pos = item.get("position", Vector2.ZERO)
			var direction = item.get("direction", "")
			var save_surface = item.get("save_surface", 0)
			var inventory_id = item.get("inventory_id", 0)
			var scene_id = id
			if direction != "" and direction != "front":
				scene_id = scene_id + "_%s" % direction
			if GameManager.item_scene_map.has(scene_id):
				var scene = GameManager.item_scene_map[scene_id]
				var instance = scene.instantiate()
				var new_item = GameManager.find_item_by_id(id)
				instance.item_data = {
					"id": id,
					"name": new_item.get("name", ""),
					"icon": new_item.get("icon", null),
					"price": new_item.get("price", 0),
					"count": 1
				}
				world.add_child(instance)
				if direction != "":
					instance.item_direction = direction
				if save_surface != 0:
					instance.save_surface = save_surface
				var inventory_id_tem = 0 # 用与确保每个仓库id的唯一性的临时变量
				if inventory_id != 0:
					instance.inventory_id = inventory_id
					if inventory_id_tem < inventory_id:
						inventory_id_tem = inventory_id
						DepotManager.iron_shelf = inventory_id + 1
				if typeof(pos) == TYPE_STRING:
				# 如果pos是字符串格式如"(362.0, 121.0)"，转换为Vector2
					var parts = pos.replace("(", "").replace(")", "").split(",")
					if parts.size() == 2:
						pos = Vector2(float(parts[0]), float(parts[1]))
					else:
						push_error("无效的位置字符串格式")
						return
				instance.position = pos

# 自动保存（退出前）
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_world_items()

func clear_file():
	var file = FileAccess.open("user://instantiationitem%d.save" % room_id, FileAccess.READ)
	file.close()  # 关闭文件（写入空内容即清空）
