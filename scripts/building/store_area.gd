extends Node2D

@onready var area = $Area2D
@onready var label = $StoreLabel

func _ready():
	label.visible = false  # 初始隐藏
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name == "Player":
		label.visible = true

func _on_body_exited(body):
	if body.name == "Player":
		label.visible = false
