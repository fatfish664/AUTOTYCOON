extends Node2D

@onready var area1 = $Rdoor1
@onready var label1 = $DoorLabel1

func _ready():
	label1.visible = false  # 初始隐藏
	area1.body_entered.connect(_on_body_entered)
	area1.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name == "Player":
		label1.visible = true

func _on_body_exited(body):
	if body.name == "Player":
		label1.visible = false
