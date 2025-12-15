extends Area2D

@onready var marker = $Marker2D
var player_in_range := false # 判断角色是否靠近
var player_ref: Node = null # 记录角色的节点
var is_using = false # 是否在使用
var player_marker
var cur_direction

func _ready():
	connect("area_entered", _on_area_entered)
	connect("area_exited", _on_area_exited)

func _process(_delta):
	cur_direction = get_parent().item_direction
	if player_ref:
		player_marker = player_ref.get_node("TakingCart").get_node(cur_direction)
	else:
		player_marker = null
	if not DragManager.is_edit_mode:
		if player_in_range and Input.is_action_just_pressed("interact"):
			if is_using:
				finish_work()
			else:
				start_work()
	if is_using:
		var offset = get_parent().global_position - marker.global_position
		get_parent().global_position = player_marker.global_position + offset

func start_work():
	is_using = true
	if player_ref.has_method("play_animation"):
		player_ref.play_animation("transport", cur_direction)

func finish_work():
	is_using = false
	if player_ref.has_method("play_animation"):
		player_ref.play_animation("idle", "")

# 信号连接，进入/进出函数
func _on_area_entered(area):
	if is_using:
		return
	if area.is_in_group("PlayerInteract"):
		player_in_range = true
		player_ref = area.get_parent()
	if area.is_in_group("NPCInteract"):
		player_ref = area.get_parent()

func _on_area_exited(area):
	if is_using:
		return
	if area.is_in_group("PlayerInteract"):
		player_in_range = false
		player_ref = null
	if area.is_in_group("NPCInteract"):
		player_ref = null
