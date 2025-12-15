extends Area2D

@onready var depot_ui 
var player_in_range := false
var cur_id 

func _ready():
	depot_ui = get_tree().get_first_node_in_group("depot_ui")
	if depot_ui == null:
		push_error("找不到仓库UI（未加入 shop_ui 组）")
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)

func _process(_delta):
	cur_id = get_parent().inventory_id
	if not DragManager.is_edit_mode:
		if player_in_range and Input.is_action_just_pressed("interact"):
			if depot_ui.visible:
				DepotManager.save_depot_items(cur_id)
				DepotManager.cur_id = 0
				depot_ui.hide()
			else:
				DepotManager.load_depot_items(cur_id)
				DepotManager.cur_id = cur_id
				depot_ui.show_depot(DepotManager.depot_items)
				depot_ui._set_layout()
				depot_ui.show()
	else:
		depot_ui.hide()

func _on_body_entered(body):
	if body.name == "Player":
		player_in_range = true

func _on_body_exited(body):
	if body.name == "Player":
		player_in_range = false
		if depot_ui.visible:
			DepotManager.save_depot_items(cur_id)
			DepotManager.cur_id = 0
			depot_ui.hide()
