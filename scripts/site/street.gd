extends Node2D

@onready var world = $World  # 要缩放的世界节点

func _ready():
	#start_zoom()
	enter_door()
	#add_to_group("editable")
	# 从全局管理器 GameManager 获取上一次玩家从哪个“门”进入的标识

func enter_door():
	var spawn_id = GameManager.spawn_door_id
	# 如果有入口 ID，则尝试获取该 ID 对应的出生点节点
	print(spawn_id)
	if spawn_id != "":
		var spawn_point = get_node("World/SpawnPoints/%s_spawn" % spawn_id)
		# 如果找到了出生点和玩家节点，将玩家传送到对应出生点的位置，实现“从某扇门进入”的功能。
		if spawn_point and has_node("World/Player"):
			$World/Player.global_position = spawn_point.global_position
		GameManager.spawn_door_id = ""  # 重置

#func _can_drop_data(_position, data):
	## 只有当拖动的是背包中的物品（例如场景）时允许接收
	#return data.has("scene")
#
## 实例化拖进来的物体（场景实例）
#func _drop_data(screen_pos, data):
	#if data.has("scene"):
		#var scene_instance = data["scene"].instantiate()
		#var instance = scene_instance.instantiate()
		#var camera = get_viewport().get_camera_2d()
		#if camera:
			#var world_pos = camera.get_screen_transform().affine_inverse() * screen_pos
			#instance.global_position = world_pos
		#else:
			#instance.global_position = screen_pos  # fallback
			#scene_instance.global_position = position
		## 把新物体加入 "dragers" 组，意味着它是可拖拽物体
		#scene_instance.add_to_group("dragers")
		## 把实例添加为World节点的子节点，正式加入场景中。
		#world.add_child(scene_instance)

# 让每个场景有个视角，并使其跟随角色（已废弃）
#func start_zoom():
	#var player = $World/Player  # 要缩放的世界节点
	#var Visual = $Visual/Camera2D  # 要缩放的世界节点
	#Visual.set_follow_target(player)
