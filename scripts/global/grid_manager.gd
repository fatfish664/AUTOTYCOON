extends Node

signal grid_updated

var grid_cell_size: Vector2 = Vector2(8, 8)  # 每个格子大小
var _path_cache: Dictionary = {}  # 缓存常用路径
# 稀疏存储：只存储障碍物位置
var blocked_cells_set: Dictionary = {}  # 键为Vector2，值为true

# 世界坐标转网格坐标
func world_to_grid(world_pos: Vector2) -> Vector2:
	return Vector2(
		floor(world_pos.x / grid_cell_size.x),
		floor(world_pos.y / grid_cell_size.y)
	)

# 网格坐标转世界坐标（格子中心点）
func grid_to_world(grid_pos: Vector2) -> Vector2:
	return Vector2(
		(grid_pos.x + 0.5) * grid_cell_size.x,
		(grid_pos.y + 0.5) * grid_cell_size.y
	)

# 添加障碍物
func add_obstacle(world_position: Vector2, size: Vector2 = Vector2.ONE):
	var grid_pos = world_to_grid(world_position)
	var grid_size = Vector2(
		ceil(size.x / grid_cell_size.x),
		ceil(size.y / grid_cell_size.y)
	)
	for x in range(int(grid_size.x)):
		for y in range(int(grid_size.y)):
			var cell = Vector2(grid_pos.x + x, grid_pos.y + y)
			blocked_cells_set[cell] = true  # 存储障碍物
			update_grid()

# 移除障碍物
func remove_obstacle(world_position: Vector2, size: Vector2 = Vector2.ONE):
	var grid_pos = world_to_grid(world_position)
	var grid_size = Vector2(
		ceil(size.x / grid_cell_size.x),
		ceil(size.y / grid_cell_size.y)
	)
	for x in range(int(grid_size.x)):
		for y in range(int(grid_size.y)):
			var cell = Vector2(grid_pos.x + x, grid_pos.y + y)
			if blocked_cells_set.has(cell):
				blocked_cells_set.erase(cell)

# 检查格子是否可通行
func is_cell_walkable(grid_pos: Vector2) -> bool:
	return not blocked_cells_set.has(grid_pos)  # 默认都是可通行的

# 获取相邻的可通行格子
func get_neighbors(grid_pos: Vector2) -> Array:
	var neighbors = []
	var directions = [
		Vector2(1, 0),   # 右
		Vector2(-1, 0),  # 左
		Vector2(0, -1),  # 上
		Vector2(0, 1)    # 下
	]
	for dir in directions:
		var neighbor = grid_pos + dir
		if is_cell_walkable(neighbor):
			neighbors.append(neighbor)
	return neighbors

# A*寻路算法
func find_path(start_world: Vector2, end_world: Vector2) -> Array:
	var start_grid = world_to_grid(start_world)
	var end_grid = world_to_grid(end_world)
	if not is_cell_walkable(end_grid):
		return []
	var open_set = [start_grid]
	var came_from = {}
	var g_score = {start_grid: 0}
	var f_score = {start_grid: _heuristic(start_grid, end_grid)}
	
	while open_set.size() > 0:
		# 找到f_score最小的节点
		var current = open_set[0]
		var current_index = 0
		for i in range(1, open_set.size()):
			if f_score.get(open_set[i], INF) < f_score.get(current, INF):
				current = open_set[i]
				current_index = i
		
		if current == end_grid:
			return _reconstruct_path(came_from, current)
		
		open_set.remove_at(current_index)
		
		for neighbor in get_neighbors(current):
			var tentative_g_score = g_score[current] + 1
			if tentative_g_score < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g_score
				f_score[neighbor] = tentative_g_score + _heuristic(neighbor, end_grid)
				
				if not neighbor in open_set:
					open_set.append(neighbor)
	return []

func _heuristic(a: Vector2, b: Vector2) -> float:
	return abs(a.x - b.x) + abs(a.y - b.y)  # 曼哈顿距离

func _reconstruct_path(came_from: Dictionary, current: Vector2) -> Array:
	var path = [grid_to_world(current)]
	while came_from.has(current):
		current = came_from[current]
		path.insert(0, grid_to_world(current))
	return path

# 其他逻辑（如更新网格后发射信号）
func update_grid():
	# 网格更新逻辑...
	emit_signal("grid_updated")  # 发射信号
