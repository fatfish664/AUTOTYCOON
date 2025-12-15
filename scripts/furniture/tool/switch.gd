extends StaticBody2D

@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D
@onready var mouse_area := $MouseArea
@onready var put_place = $PutPlace
@onready var marker = $Marker2D
@export var item_type: String = "furniture"  # 是家具
#@onready var outline_sprite = $OutlineSprite # 用来实现触碰描边
var is_being_dragged := false  # 是否正在拖拽中
var drag_offset := Vector2.ZERO  # 拖拽偏移量
var is_area = false # 鼠标是否在区域内
var can_place := false  # 是否可以放置
var is_occupy = false # 是否在被使用
var overlap_put: Array = [] # 记录碰到的其他物品的放置区域
var one_dragging = false # 是否是刚拖出来
var change_seat  # 随物品在不同的区域进行转换(其他脚本有判定，不能删)
var link_item = null  # 连接到的物品
var item_direction: String = "front" # 记录当前物品的方向
var item_data: Dictionary = { "id": "switch", "name": "控制器",
"price": 20, "icon": preload("res://art_resource/thing/Seats1_blue_icon.png") }

func _ready():
	add_to_group("dragers")
	add_to_group("switch")
	set_meta("item_type", "furniture")
	mouse_area.mouse_entered.connect(_on_area_mouse_entered)
	mouse_area.mouse_exited.connect(_on_area_mouse_exited)
	put_place.connect("area_entered", _on_area_entered)
	put_place.connect("area_exited", _on_area_exited)

func _process(_delta):
	z_index = get_surface_z_index()

func start_item():
	if link_item == null:
		return
	link_item.start_lift()

# 动态地获取层级
func get_surface_z_index():
	return $Sprite2D/ShelterBase.global_position.y

# 是否正在被使用
func is_occupied():
	return is_occupy

# 开启/关闭描边
func apply_outline():
	pass
	#outline_sprite.visible = true

func clear_outline():
	pass
	#outline_sprite.visible = false

# 判断两个区域是不是来自同一个物体
func is_same_object(area: Area2D) -> bool:
	return area.get_owner() == self or area.get_parent() == self

# 链接鼠标等区域
func _on_area_mouse_entered():
	is_area = true
	if DragManager.is_edit_mode and not is_being_dragged:
		DragManager.request_highlight(self)

func _on_area_mouse_exited():
	is_area = false
	if not is_being_dragged:
		DragManager.clear_if_hovered(self)

func _on_area_entered(area):
	if is_same_object(area):
		return  # 忽略自身
	# 若进入的区域也是可放置物品的区域
	if area.is_in_group("put_place"):  # 放置物品加个 group
		if is_being_dragged:
			if not overlap_put.has(area):
				overlap_put.append(area)
	if area.is_in_group("control"):
		link_item = area.get_parent()

func _on_area_exited(area):
	if is_same_object(area):
		return  # 忽略自身
	if area.is_in_group("put_place"):
		if is_being_dragged:
			overlap_put.erase(area)
	if area.is_in_group("control"):
		link_item = null
