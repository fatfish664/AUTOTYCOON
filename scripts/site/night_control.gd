extends Node

@onready var night_overlay := $DarknessOverlay

func _process(_delta: float):
	var hour = TimeSystem.get_hour()
	var darkness := calculate_darkness(hour)
	night_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	night_overlay.modulate.a = clamp(darkness, 0.0, 1.0)  # 只改透明度部分

func calculate_darkness(hour: float) -> float:
	if hour >= 19.0 and hour < 21.0:
		# 19:00 到 21:00 渐暗
		return lerp(0.0, 0.8, (hour - 19.0) / 2.0)
	elif hour >= 21.0 and hour < 24.0:
		# 22:00 到午夜，保持黑夜
		return 0.8
	elif hour >= 0.0 and hour < 5.0:
		# 凌晨到清晨，保持黑夜
		return 0.8
	elif hour >= 5.0 and hour < 7.0:
		# 5:00 到 7:00 渐亮
		return lerp(0.8, 0.0, (hour - 5.0) / 2.0)
	else:
		# 白天
		return 0.0
