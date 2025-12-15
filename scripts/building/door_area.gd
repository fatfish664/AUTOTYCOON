extends Node2D

@onready var area1 = $Door1
@onready var area2 = $Door2
@onready var area3 = $Door3
@onready var area4 = $Door4
@onready var label1 = $DoorLabel1
@onready var label2 = $DoorLabel2
@onready var label3 = $DoorLabel3
@onready var label4 = $DoorLabel4

func _ready():
	label1.visible = false  # 初始隐藏
	label2.visible = false  # 初始隐藏
	label3.visible = false  # 初始隐藏
	label4.visible = false  # 初始隐藏
	#area1.body_entered.connect(_on_body_entered)
	#area1.body_exited.connect(_on_body_exited)
	#area2.body_entered.connect(_on_body_entered)
	#area2.body_exited.connect(_on_body_exited)
	#area3.body_entered.connect(_on_body_entered)
	#area3.body_exited.connect(_on_body_exited)
	#area4.body_entered.connect(_on_body_entered)
	#area4.body_exited.connect(_on_body_exited)

#func _on_body_entered(body):
	#if body.name == "Player":
		#label1.visible = true
#
#func _on_body_exited(body):
	#if body.name == "Player":
		#label1.visible = false


func _on_door_1_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		label1.visible = true

func _on_door_1_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		label1.visible = false


func _on_door_2_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		label2.visible = true

func _on_door_2_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		label2.visible = false


func _on_door_3_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		label3.visible = true

func _on_door_3_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		label3.visible = false


func _on_door_4_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		label4.visible = true

func _on_door_4_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		label4.visible = false
