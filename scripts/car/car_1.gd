extends StaticBody2D

@onready var car_tire1 = $CarTire1
@onready var car_tire2 = $CarTire2
@onready var car_upper = $CarUpper
@onready var marker = $Marker2D
@onready var animation_player = $AnimatedSprite2D
@onready var collision = $CollisionShape2D
@onready var parking_area = $ParkingArea
@onready var check_points = $Checkpoints
# 车需要修理的的状态参数
var need_open_hood = false     # 是否要开前盖
var need_add_oil = false       # 是否需要加油
var need_replace_tires = false   # 是否要换轮胎
var need_repair_brake = false  # 是否要修刹车
# 车的状态参数
var parking_index = null   # 用于保存停车时的层级
var is_open_hood = false    # 车前盖是否打开 

func _ready():
	add_to_group("car")
	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)
	need_open_hood = true
	need_add_oil = true
	need_replace_tires = true
	need_repair_brake = true

func _process(_delta):
	z_index = get_surface_z_index()
	if parking_area.is_repair:
		collision.disabled = true
	else:
		collision.disabled = false

# 打开/关闭 车前盖函数
func open_hood():
	animation_player.play("open_hood")
	is_open_hood = true

func close_hood():
	animation_player.play("close_hood")
	is_open_hood = false

# 动态地获取层级
func get_surface_z_index():
	if parking_index != null and parking_area.parking_item.have_raise:
		return parking_index + 120
	parking_index = $Car1Brake/ShelterBase.global_position.y
	return $Car1Brake/ShelterBase.global_position.y

# 一段动画播完后的行为函数
func _on_animation_finished():
	var current_anim = animation_player.animation
	match current_anim:
		"open_hood":
			need_open_hood = false
