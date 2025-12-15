extends CanvasLayer

# 节点引用
@onready var panel := $Panel
@onready var resolution_selector: OptionButton = $Panel/OptionButton
@onready var fullscreen_checkbox: CheckBox = $Panel/CheckBox
@onready var close_button: Button = $Panel/CloseButton

# 可选分辨率
var resolutions := [
	Vector2i(640, 360),
	Vector2i(800, 600),
	Vector2i(1024, 768),
	Vector2i(1280, 720),
	Vector2i(1920, 1080)
]

func _ready():
	# 初始化界面：隐藏 + 分组
	hide()
	add_to_group("settings_ui")
	
	# 1. 面板美化：像素风边框 + 背景
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0.2, 0.2)       # 深灰背景
	panel_style.border_width_top = 2                # 像素边框（分别设置各方向）
	panel_style.border_width_bottom = 2
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_color = Color(1, 1, 1)       # 白色边框
	panel.add_theme_stylebox_override("normal", panel_style)
	
	# 2. 按钮美化：像素化 + 悬停反馈
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color(0.3, 0.3, 0.3)
	button_style.border_width_top = 2               # 分别设置各方向
	button_style.border_width_bottom = 2
	button_style.border_width_left = 2
	button_style.border_width_right = 2
	button_style.border_color = Color(1, 1, 1)
	
	# 悬停样式
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.4, 0.4, 0.4)
	hover_style.border_width_top = 2                # 分别设置各方向
	hover_style.border_width_bottom = 2
	hover_style.border_width_left = 2
	hover_style.border_width_right = 2
	hover_style.border_color = Color(1, 1, 1)
	
	close_button.add_theme_stylebox_override("normal", button_style)
	close_button.add_theme_stylebox_override("hover", hover_style)
	close_button.add_theme_stylebox_override("pressed", hover_style)
	
	# 3. 下拉框美化：适配像素风格
	var dropdown_style := StyleBoxFlat.new()
	dropdown_style.bg_color = Color(0.3, 0.3, 0.3)
	dropdown_style.border_width_top = 2             # 分别设置各方向
	dropdown_style.border_width_bottom = 2
	dropdown_style.border_width_left = 2
	dropdown_style.border_width_right = 2
	dropdown_style.border_color = Color(1, 1, 1)
	resolution_selector.add_theme_stylebox_override("normal", dropdown_style)
	
	# 4. 复选框美化
	var checkbox_style := StyleBoxFlat.new()
	checkbox_style.bg_color = Color(0.3, 0.3, 0.3)
	checkbox_style.border_width_top = 2             # 分别设置各方向
	checkbox_style.border_width_bottom = 2
	checkbox_style.border_width_left = 2
	checkbox_style.border_width_right = 2
	checkbox_style.border_color = Color(1, 1, 1)
	fullscreen_checkbox.add_theme_stylebox_override("normal", checkbox_style)
	
	# 选中样式
	var checkbox_checked_style := StyleBoxFlat.new()
	checkbox_checked_style.bg_color = Color(0.3, 0.3, 0.3)
	checkbox_checked_style.border_width_top = 2     # 分别设置各方向
	checkbox_checked_style.border_width_bottom = 2
	checkbox_checked_style.border_width_left = 2
	checkbox_checked_style.border_width_right = 2
	checkbox_checked_style.border_color = Color(1, 1, 0)  # 黄色边框表示选中
	fullscreen_checkbox.add_theme_stylebox_override("checked", checkbox_checked_style)
	
	# 5. 布局调整：居中 + 间距优化
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -200
	panel.offset_top = -150
	panel.offset_right = 200
	panel.offset_bottom = 150
	
	# 添加标题
	var title_label = Label.new()
	title_label.text = "设置"
	title_label.position = Vector2(180, -130)
	title_label.add_theme_color_override("font_color", Color(1, 1, 1))
	panel.add_child(title_label)
	
	# 6. 绑定信号
	close_button.pressed.connect(hide)
	
	# 填充分辨率选项
	for res in resolutions:
		resolution_selector.add_item("%d x %d" % [res.x, res.y])
	
	# 默认选中当前分辨率
	var current_size = DisplayServer.window_get_size()
	for i in range(resolutions.size()):
		if resolutions[i] == current_size:
			resolution_selector.select(i)
			break
	
	resolution_selector.item_selected.connect(_on_resolution_selected)
	
	# 设置全屏复选框状态
	fullscreen_checkbox.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)

func _on_resolution_selected(index: int):
	var selected_resolution = resolutions[index]
	DisplayServer.window_set_size(selected_resolution)
	# 重新居中窗口
	DisplayServer.window_set_position(
		(DisplayServer.screen_get_size() - selected_resolution) / 2
	)

func _on_fullscreen_toggled(pressed: bool):
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		# 切回窗口后重新应用分辨率
		var index = resolution_selector.get_selected_id()
		if index >= 0 and index < resolutions.size():
			_on_resolution_selected(index)

func toggle_visible():
	visible = not visible
