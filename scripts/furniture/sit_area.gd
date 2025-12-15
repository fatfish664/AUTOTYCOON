extends Area2D

@onready var sofa_sit_place = $SitPlace
var player_in_range := false # 判断角色是否靠近
var player_ref: Node = null # 记录角色的节点
var player_original_position: Vector2 # 记录角色坐座位前的位置
var is_player_sitting := false # 角色是否在座位上
var is_sitting = false # 是否有角色坐在沙发上

func _ready():
	connect("area_entered", _on_area_entered)
	connect("area_exited", _on_area_exited)

func _process(_delta):
	if not DragManager.is_edit_mode:
		if player_in_range and Input.is_action_just_pressed("interact"):
			if not is_player_sitting:
				get_parent().sit_down()
				_player_sit()
			else:
				_player_stand()
				get_parent().stand_up()

func _player_sit():
	if player_ref:
		# 记录玩家原始位置（用于站起时恢复）
		player_original_position = player_ref.global_position
		# 获取玩家的SitPlace
		var player_sit_place = player_ref.get_node("SitPlace")
		# 把玩家整体移动，使两个 SitPlace 对齐
		var offset = player_ref.global_position - player_sit_place.global_position
		player_ref.global_position = sofa_sit_place.global_position + offset
		# 状态切换
		player_ref.collision.disabled = true
		is_player_sitting = true
		is_sitting = true
		# 播放动画（可选）
		if player_ref.has_method("play_animation"):
			player_ref.play_animation("sit", get_parent().item_direction)

func _player_stand():
	if player_ref:
		# 玩家回到之前记录的位置
		player_ref.global_position = player_original_position
		# 状态切换
		player_ref.collision.disabled = false
		is_player_sitting = false
		is_sitting = false
		# 播放站立动画（可选）
		if player_ref.has_method("play_animation"):
			player_ref.play_animation("idle", "")

func _on_area_entered(area):
	if is_sitting:
		return
	if area.is_in_group("PlayerInteract"):
		player_in_range = true
		player_ref = area.get_parent()
	if area.is_in_group("NPCInteract"):
		player_ref = area.get_parent()

func _on_area_exited(area):
	if area.is_in_group("PlayerInteract"):
		player_in_range = false
		player_ref = null
