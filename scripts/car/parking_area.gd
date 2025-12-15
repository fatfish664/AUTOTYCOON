extends Area2D

@onready var marker = $Marker2D
var parking_in_range = false # 判断是否在停车位
var parking_item = null # 记录停车位的节点
var is_repair = false  # 是否在停,修车
var parking_marker 

func _ready():
	connect("area_entered", _on_area_entered)
	connect("area_exited", _on_area_exited)

func _process(_delta):
	if parking_item:
		parking_marker = parking_item.get_node("ParkingPlace")
		is_repair = true
	if is_repair:
		var offset = get_parent().global_position - marker.global_position
		get_parent().global_position = parking_marker.global_position + offset

# 信号连接，进入/进出函数
func _on_area_entered(area):
	if area.is_in_group("control"):
		parking_in_range = true
		parking_item = area.get_parent()

func _on_area_exited(area):
	if area.is_in_group("control"):
		parking_in_range = false
		parking_item = null
