extends Node

# 时间变量
var minutes: int = 0
var hours: int = 8
var days: int = 1
var months: int = 1
var years: int = 1

const TICKS_PER_MINUTE := 0.25  # 每**秒增加1分钟
var time_accumulator := 0.0

# 保存文件路径
const SAVE_PATH := "user://game_time.save"

func _ready():
	load_time_data()
	# 确保在游戏暂停时也能运行
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float):
	time_accumulator += delta
	var minutes_to_add = floor(time_accumulator / TICKS_PER_MINUTE)
	if minutes_to_add > 0:
		time_accumulator -= minutes_to_add * TICKS_PER_MINUTE
		advance_time(minutes_to_add)

func advance_time(minutes_passed):
	minutes += minutes_passed
	# 处理时间进位
	if minutes >= 60:
		@warning_ignore("integer_division")
		hours += minutes / 60
		minutes = minutes % 60
		
	if hours >= 24:
		@warning_ignore("integer_division")
		days += hours / 24
		hours = hours % 24
		
	if days > 30:  # 假设每月30天
		@warning_ignore("integer_division")
		months += days / 30
		days = days % 30 + 1  # 下个月从1号开始
		
	if months > 12:
		@warning_ignore("integer_division")
		years += months / 12
		months = months % 12
		if months == 0:
			months = 12

func get_time():
	return "%02d:%02d  %02d/%02d  第%02d年" % [hours, minutes, days, months, years]

func get_hour():
	return hours + minutes / 60.0

# 保存时间
func save_time_data():
	var save_data = {
		"minutes": minutes,
		"hours": hours,
		"days": days,
		"months": months,
		"years": years
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_var(save_data)
	file.close()

# 读取时间
func load_time_data():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var data = file.get_var()
		file.close()
		minutes = data.get("minutes", 0)
		hours = data.get("hours", 8)
		days = data.get("days", 1)
		months = data.get("months", 1)
		years = data.get("years", 1)

# 自动保存（退出前）
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_time_data()
