extends Node2D

var is_open = true
var player_in_range = false

@onready var closed_sprite = $SwitchClos
@onready var opened_sprite = $SwitchOpen
@onready var area = $Area2D
@onready var darkness_overlay = $DarknessOverlay


func _ready():
	_update_lights_visuals()
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _process(_delta):
	if player_in_range and Input.is_action_just_pressed("interact"):
		is_open = !is_open
		_update_lights_visuals()

func _update_lights_visuals():
	closed_sprite.visible = not is_open
	opened_sprite.visible = is_open
	darkness_overlay.visible = is_open

func _on_body_entered(body):
	if body.name == "Player":  # 或使用 `body is CharacterBody2D` 判断类型
		player_in_range = true

func _on_body_exited(body):
	if body.name == "Player":
		player_in_range = false
