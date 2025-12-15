extends Node2D

@export var enabled: bool = true
@export var grid_color: Color = Color(1, 1, 1, 0.2)
@export var obstacle_color: Color = Color(1, 0, 0, 0.3)
@export var path_color: Color = Color(0, 1, 0, 0.5)
@export var current_cell_color: Color = Color(1, 1, 0, 0.4)

var current_path: Array = []
var highlight_cells: Array = []

func _ready():
	# 如果网格未初始化，初始化一个默认大小
	var viewport = get_viewport()
	var world_size = viewport.get_visible_rect().size
	# 连接GridManager的变化信号
	if GridManager.has_signal("grid_updated"):
		GridManager.grid_updated.connect(queue_redraw)
	# 每帧更新
	set_process(true)

#事件驱动重绘
func set_current_path(path: Array):
	current_path = path
	if enabled:
		queue_redraw()  # 只在数据变化时重绘

func _draw():
	var cell_size = GridManager.grid_cell_size
	# 绘制所有格子
	for grid_pos in GridManager.grid_map:
		var world_pos = GridManager.grid_to_world(grid_pos)
		var rect = Rect2(world_pos - cell_size / 2, cell_size)
		# 绘制格子边框
		draw_rect(rect, grid_color, false, 1.0)
		# 如果是障碍物格子，填充颜色
		if not GridManager.is_cell_walkable(grid_pos):
			draw_rect(rect, obstacle_color, true)
		# 如果是当前路径，绘制路径
		if _is_in_current_path(grid_pos):
			draw_rect(rect, path_color, true)
		# 如果需要高亮特定格子
		if grid_pos in highlight_cells:
			draw_rect(rect, current_cell_color, true)
		
		# 可选：绘制网格坐标文字（调试用）
		# draw_string(ThemeDB.fallback_font, world_pos - Vector2(10, -10), 
		#            str(int(grid_pos.x), ",", int(grid_pos.y)), 
		#            HORIZONTAL_ALIGNMENT_CENTER, 12, 12, Color.WHITE)

func _is_in_current_path(grid_pos: Vector2) -> bool:
	for path_point in current_path:
		var path_grid = GridManager.world_to_grid(path_point)
		if path_grid == grid_pos:
			return true
	return false

func highlight_cell(grid_pos: Vector2):
	highlight_cells.append(grid_pos)
	queue_redraw()

func clear_highlights():
	highlight_cells.clear()
	queue_redraw()

# 切换显示/隐藏
func toggle_visible():
	enabled = !enabled
	visible = enabled
	queue_redraw()
