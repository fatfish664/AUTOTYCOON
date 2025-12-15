extends Area2D

@onready var drink_place = $DrinkPlace
var player_in_range := false # 判断角色是否靠近
var player_ref: Node = null # 记录角色的节点
var is_player_drinking := false # 角色是否在喝
var player_original_position: Vector2 # 记录角色喝水前的位置
var drink_item = "" # 喝的什么

func _ready():
	connect("area_entered", _on_area_entered)
	connect("area_exited", _on_area_exited)

func _process(_delta):
	if not DragManager.is_edit_mode:
		if player_ref and player_in_range and not player_ref.is_palying_drink_animation:
			_player_stop()
			get_parent().collision.disabled = false
			drink_item = null
		if player_in_range and Input.is_action_just_pressed("relax"):
			if not is_player_drinking:
				drink_item = "water"
				get_parent().collision.disabled = true
				_player_drink()
			else:
				_player_stop()
				get_parent().collision.disabled = false
				drink_item = null

func _player_drink():
	if player_ref:
		# 记录玩家原始位置（用于站起时恢复）
		player_original_position = player_ref.global_position
		# 获取玩家的SitPlace
		var player_sit_place = player_ref.get_node("SitPlace")
		# 把玩家整体移动，使两个 SitPlace 对齐
		var offset = player_ref.global_position - player_sit_place.global_position
		player_ref.global_position = drink_place.global_position + offset
		# 状态切换
		is_player_drinking = true
		# 播放动画（可选）
		player_ref.relax_stamina(50)
		if player_ref.has_method("play_animation"):
			player_ref.play_animation("drink", drink_item)

func _player_stop():
	if player_ref:
		# 状态切换
		is_player_drinking = false
		# 播放站立动画（可选）
		if player_ref.has_method("play_animation"):
			player_ref.play_animation("idle", drink_item)

func _on_area_entered(area):
	if is_player_drinking:
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
