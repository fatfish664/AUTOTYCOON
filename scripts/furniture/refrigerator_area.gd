extends Area2D

@onready var refrigerator_ui 
var player_in_range := false # 判断角色是否靠近
var player_ref: Node = null # 记录角色的节点
var is_player_drinking := false # 角色是否在喝
var drink_item = "" # 喝的什么

func _ready():
	refrigerator_ui = get_tree().get_first_node_in_group("refrigerator_ui")
	if refrigerator_ui == null:
		push_error("找不到冰箱UI（未加入 refrigerator_ui 组）")
	connect("area_entered", _on_area_entered)
	connect("area_exited", _on_area_exited)

func _process(_delta):
	if not DragManager.is_edit_mode:
		if player_ref and player_in_range and not player_ref.is_palying_drink_animation:
			_player_stop()
			get_parent().close_refrigerator()
			drink_item = null
		if player_in_range and Input.is_action_just_pressed("relax"):
			if not is_player_drinking:
				drink_item = "drinks"
				get_parent().open_refrigerator()
				_player_drink()
			else:
				_player_stop()
				get_parent().close_refrigerator()
				drink_item = null
		elif player_in_range and Input.is_action_just_pressed("interact"):
			if refrigerator_ui.visible:
				refrigerator_ui.hide()
			else:
				refrigerator_ui.show()

func _player_drink():
	if player_ref:
		is_player_drinking = true
		player_ref.relax_stamina(50)
		# 播放动画（可选）
		if player_ref.has_method("play_animation"):
			player_ref.play_animation("fridge", drink_item)

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
		refrigerator_ui.hide()
