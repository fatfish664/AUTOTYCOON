extends CanvasLayer

@onready var panel = $NinePatchRect
@onready var scroll = $NinePatchRect/ScrollContainer
@onready var grid: GridContainer = scroll.get_node("GridContainer")
@onready var info_container = $NinePatchRect/InfoContainer
@onready var close_bg = $NinePatchRect/CloseButtonBackground
@onready var close_button = $NinePatchRect/CloseButton

# 商品预设路径（提前创建一个ShopItemSlot.tscn）
const ShopItemSlotScene = preload("res://scenes/storages/shop_item_slot.tscn")

func _ready():
	add_to_group("shop_ui")
	_set_layout()
	show_shop(GameManager.shop_items)
	_setup_scrollbar_style()
	visible = false

func show_shop(items: Array):
	# 清空旧商品
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for item_data in items:
		var slot = ShopItemSlotScene.instantiate()
		slot.set_item(item_data)
		grid.add_child(slot)
	visible = true

func _set_layout():
	# 居中面板
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -400
	panel.offset_top = -220
	panel.offset_right = 400
	panel.offset_bottom = 220
	
	# 设置 info 信息区域
	info_container.anchor_left = 0.0
	info_container.anchor_top = 0.0
	info_container.anchor_right = 1.0
	info_container.anchor_bottom = 0.0
	info_container.offset_left = 20
	info_container.offset_right = -20
	info_container.offset_top = 20
	info_container.offset_bottom = 40

	# ScrollContainer 设置（商品区）
	scroll.anchor_left = 0.0
	scroll.anchor_top = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 20
	scroll.offset_top = 60
	scroll.offset_right = -20
	scroll.offset_bottom = -60
	# 滚动区域大小
	scroll.custom_minimum_size = Vector2(600, 320)
	# 关闭按钮放右上角
	close_bg.anchor_left = 1.0
	close_bg.anchor_top = 0.0
	close_bg.anchor_right = 1.0
	close_bg.anchor_bottom = 0.0
	close_bg.offset_left = -40
	close_bg.offset_top = 8
	close_bg.offset_right = -8
	close_bg.offset_bottom = 40
	
	close_button.anchor_left = 1.0
	close_button.anchor_top = 0.0
	close_button.anchor_right = 1.0
	close_button.anchor_bottom = 0.0
	close_button.offset_left = -40
	close_button.offset_top = 8
	close_button.offset_right = -8
	close_button.offset_bottom = 40
	close_button.flat = true
	close_button.text = ""
	close_button.pressed.connect(hide) # 点击关闭按钮隐藏商店

func _setup_scrollbar_style():
	var scroll_container := $NinePatchRect/ScrollContainer
	# 创建 Theme
	var theme := Theme.new()
	# 加载纹理
	var bg_texture := preload("res://art_resource/Store/jdt.png")
	var grabber_texture := preload("res://art_resource/Store/jd.png")
	# 创建滚动条背景样式
	var bg_style := StyleBoxTexture.new()
	bg_style.texture = bg_texture
	bg_style.content_margin_left = 4
	bg_style.content_margin_right = 4
	bg_style.content_margin_top = 4
	bg_style.content_margin_bottom = 4
	# 创建滑块样式
	var grabber_style := StyleBoxTexture.new()
	grabber_style.texture = grabber_texture
	grabber_style.content_margin_left = 4
	grabber_style.content_margin_right = 4
	grabber_style.content_margin_top = 4
	grabber_style.content_margin_bottom = 4
	# 应用于垂直滚动条
	theme.set_stylebox("scroll", "VScrollBar", bg_style)
	theme.set_stylebox("grabber", "VScrollBar", grabber_style)
	# 应用主题到 ScrollContainer
	scroll_container.theme = theme
