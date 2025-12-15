extends MarginContainer

@onready var button := $Button

var item_data: Dictionary

func _ready():
	_set_layout()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 设置按钮为透明
	button.flat = true
	button.text = ""
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	# 监听按钮点击
	button.connect("gui_input", _on_button_gui_input)

func set_item(data: Dictionary):
	#print(data)
	item_data = data
	var icon := $HBoxContainer/TextureRect/Icon
	var name_label := $HBoxContainer/VBoxContainer/NameLabel
	var price_label := $HBoxContainer/VBoxContainer/PriceLabel
	if icon and data.has("icon"):
		icon.texture = data["icon"]
	if name_label and data.has("name"):
		name_label.text = data["name"]
	if price_label and data.has("price"):
		price_label.text = str(data["price"]) + "元"

func _on_button_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		print("尝试购买：", item_data.get("name"))
		_buy_item()

func _buy_item():
	var backpack = get_tree().get_first_node_in_group("Backpack")
	if backpack and backpack.has_method("buy_shop"):
		if backpack.buy_shop(item_data):
				print("购买成功：", item_data.get("name"))
			# 这里你可以播放音效、动画等
		else:
			print("背包已满，购买失败")
	else:
		print("找不到Backpack")

func _set_layout():
	var name_label = $HBoxContainer/VBoxContainer/NameLabel
	var price_label = $HBoxContainer/VBoxContainer/PriceLabel
	set("custom_minimum_size", Vector2(230, 72))  # 每个格子的宽高
	$HBoxContainer/TextureRect.custom_minimum_size = Vector2(68, 68)
	$HBoxContainer/TextureRect/Icon.custom_minimum_size = Vector2(62, 62)
	# 设置商品名称样式
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(100, 30)
	# 设置商品价格样式
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.custom_minimum_size = Vector2(100, 30)
