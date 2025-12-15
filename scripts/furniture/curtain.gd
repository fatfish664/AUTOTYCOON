extends Node2D

var is_open = false
var player_in_range = false

@onready var anim_player = $AnimatedSprite2D
@onready var area = $Area2D

func _ready():
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _process(_delta):
	if player_in_range and Input.is_action_just_pressed("interact"):
		_toggle_curtain()

func _toggle_curtain():
	if is_open:
		anim_player.play("close")
	else:
		anim_player.play("open")
	is_open = !is_open

func _on_body_entered(body):
	if body.name == "Player":  # 可替换为更严格类型判断
		player_in_range = true

func _on_body_exited(body):
	if body.name == "Player":
		player_in_range = false
