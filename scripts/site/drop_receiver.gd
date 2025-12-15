extends Control

# 判断是否允许放置这个拖拽数据，这里仅当 data 中包含 "id" 键时才允许
func _can_drop_data(_pos, data):
	return data.has("id")

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # 非常关键，否则会吃掉拖拽

# 当拖拽松开鼠标，发生实际放置物体行为时被调用
func _drop_data(pos, data):
	print("生成物品中...")
	if data.has("id"):
		# 获取主场景中属于 "editable" 组的第一个节点
		var world = get_tree().get_first_node_in_group("editable")
		if world == null:
			print("未找到主场景节点 editable")
			return
		# 实例化一个场景
		var scene = GameManager.item_scene_map.get(data["id"], null)
		if scene == null:
			print("找不到对应场景")
			return  # 或使用你传入的 data["scene"]
		var instance = scene.instantiate()
		# 获取当前主场景下的摄像机
		var camera = world.get_viewport().get_camera_2d()
		if camera == null:
			print("未找到摄像机")
			return
		# 将拖拽位置 pos（一般是屏幕坐标）转换为世界坐标，便于物品实例落到正确位置。
		var world_pos = camera.get_screen_transform().affine_inverse() * pos
		instance.global_position = world_pos
		# 把物体加入到 "dragers" 组（用于后续识别哪些可以拖），并作为主场景的子节点添加
		instance.add_to_group("dragers")
		world.add_child(instance)
