extends StaticBody2D

@onready var sprite = $Sprite2D
@onready var animated = $AnimatedSprite2D
@onready var collision = $CollisionShape2D
@onready var repair_collision = $RepairCollsion
@onready var mouse_area := $MouseArea
@onready var put_place = $PutPlace
@onready var parking = $ParkingPlace
@onready var check_points = $Checkpoints
@onready var tool_place = $ToolPlace
@onready var eliminate_oil = $EliminateOil
@export var item_type: String = "furniture"  # 是家具
#@onready var outline_sprite = $OutlineSprite # 用来实现触碰描边
@export var parking_positions: Dictionary = {
	"up": [Vector2(-2,-5), Vector2(-2,-5), Vector2(-2,-6), Vector2(-2,-10),
	Vector2(-2,-13), Vector2(-2,-14), Vector2(-2,-17), Vector2(-2,-20), Vector2(-2,-23),
	Vector2(-2,-29), Vector2(-2,-35), Vector2(-2,-42), Vector2(-2,-51)],
	}
var is_being_dragged := false  # 是否正在拖拽中
var drag_offset := Vector2.ZERO  # 拖拽偏移量
var is_area = false # 鼠标是否在区域内
var can_place := false  # 是否可以放置
var is_occupy = false # 是否在被使用
var overlap_put: Array = [] # 记录碰到的其他物品的放置区域
var one_dragging = false # 是否是刚拖出来
var have_raise = false   # 是否处于升起状态
var change_seat  # 随物品在不同的区域进行转换(其他脚本有判定，不能删)
var item_direction: String = "front" # 记录当前物品的方向
var item_data: Dictionary = { "id": "carlift", "name": "汽车抬起位",
"price": 20, "icon": preload("res://art_resource/thing/Seats1_blue_icon.png") }

func _ready():
	add_to_group("dragers")
	add_to_group("parking")
	set_meta("item_type", "furniture")
	mouse_area.mouse_entered.connect(_on_area_mouse_entered)
	mouse_area.mouse_exited.connect(_on_area_mouse_exited)
	put_place.connect("area_entered", _on_area_entered)
	put_place.connect("area_exited", _on_area_exited)
	animated.frame_changed.connect(_update_marker_position)
	animated.animation_finished.connect(_on_animation_finished)
	repair_collision.disabled = false

func _process(_delta):
	z_index = get_surface_z_index()

# 启用升降机
func start_lift():
	if have_raise:
		repair_collision.disabled = false
		animated.play("down")
	else:
		have_raise = true
		animated.play("up")

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

func _on_area_exited(area):
	if is_same_object(area):
		return  # 忽略自身
	if area.is_in_group("put_place"):
		if is_being_dragged:
			overlap_put.erase(area)

func _update_marker_position():
	var anim = animated.animation
	var frame = animated.frame
	if parking_positions.has(anim) and frame < parking_positions[anim].size():
		parking.position = parking_positions[anim][frame]

func _on_animation_finished():
	var current_anim = animated.animation
	match current_anim:
		"up":
			repair_collision.disabled = true
		"down":
			have_raise = false
