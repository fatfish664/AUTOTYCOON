extends Node2D

var is_open = false
var player_in_range = false

@onready var closed_sprite = $BuildingDoor
@onready var opened_sprite = $BuildingDoorOpen
@onready var air_wall = $DoorBody/CollisionShape2D
@onready var area = $Area2D

func _ready():
	add_to_group("in_door")
	_update_door_visuals()
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _process(_delta):
	if player_in_range and Input.is_action_just_pressed("interact"):
		is_open = !is_open
		_update_door_visuals()

func _update_door_visuals():
	closed_sprite.visible = not is_open
	opened_sprite.visible = is_open
	air_wall.disabled = is_open  # 打开门时禁用空气墙，允许通行

func _on_body_entered(body):
	if body.name == "Player":  # 或使用 `body is CharacterBody2D` 判断类型
		player_in_range = true

func _on_body_exited(body):
	if body.name == "Player":
		player_in_range = false
