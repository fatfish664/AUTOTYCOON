extends Area2D

@export var target_scene: String = "res://scenes/sites/street.tscn"
@export var door_id: String = "rdoor4"  # 当前门的ID
var player_in_range := false
var player_node: Node = null

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		player_node = body
		print("玩家靠近门，可进入")

func _on_body_exited(body):
	if body == player_node:
		player_in_range = false
		player_node = null
		print("玩家离开门")

func _process(_delta):
	if player_in_range and Input.is_action_just_pressed("interact"):
		if target_scene != "":
			GameManager.spawn_door_id = door_id
			print("进入房间：", target_scene)
			RoomSave.save_world_items()
			get_tree().change_scene_to_file(target_scene)
