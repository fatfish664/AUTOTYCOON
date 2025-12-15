extends Node2D

@onready var world = $World  # 要缩放的世界节点
@onready var edit_button := $EditButton  # 按钮节点路径

func _ready():
	add_to_group("editable")
	if edit_button:
		edit_button.pressed.connect(toggle_edit_mode)
	RoomSave.load_world_items()
	enter_door()

func enter_door():
	print(RoomSave.room_id)
	# 从全局管理器 GameManager 获取上一次玩家从哪个“门”进入的标识
	var spawn_id = GameManager.spawn_door_id
	# 如果有入口 ID，则尝试获取该 ID 对应的出生点节点
	if spawn_id != "":
		var spawn_point = get_node("World/SpawnPoints/%s_spawn" % spawn_id)
		# 如果找到了出生点和玩家节点，将玩家传送到对应出生点的位置，实现“从某扇门进入”的功能。
		if spawn_point and has_node("World/Player"):
			$World/Player.global_position = spawn_point.global_position
		GameManager.spawn_door_id = ""  # 重置

func toggle_edit_mode():
	DragManager.is_edit_mode = not DragManager.is_edit_mode
	if DragManager.is_edit_mode:
		edit_button.text = "退出编辑模式"
	else:
		edit_button.text = "进入编辑模式"

func _can_drop_data(_position, data):
	# 只有当拖动的是背包中的物品（例如场景）时允许接收
	return data.has("scene")

# 实例化拖进来的物体（场景实例）
func _drop_data(screen_pos, data):
	if data.has("scene"):
		var scene_instance = data["scene"].instantiate()
		#var instance = scene_instance.instantiate()
		var camera = get_viewport().get_camera_2d()
		if camera:
			var world_pos = camera.get_screen_transform().affine_inverse() * screen_pos
			scene_instance.global_position = world_pos
		else:
			#instance.global_position =   # fallback
			scene_instance.global_position = screen_pos
		# 把新物体加入 "dragers" 组，意味着它是可拖拽物体
		scene_instance.add_to_group("dragers")
		# 把实例添加为当前节点的子节点，正式加入场景中。
		world.add_child(scene_instance)
