extends Area2D

@onready var shop_ui 
var player_in_range := false

func _ready():
	shop_ui = get_tree().get_first_node_in_group("shop_ui")
	if shop_ui == null:
		push_error("找不到商店UI（未加入 shop_ui 组）")
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)

func _process(_delta):
	if player_in_range and Input.is_action_just_pressed("interact"):
		if shop_ui.visible:
			shop_ui.hide()
		else:
			shop_ui.show()

func _on_body_entered(body):
	if body.name == "Player":
		player_in_range = true

func _on_body_exited(body):
	if body.name == "Player":
		player_in_range = false
