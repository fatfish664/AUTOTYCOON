extends TextureProgressBar
func update_repair_progress():
	# 修理开始时显示
	$HealthBar.show()
	# 修理完成后隐藏
	$HealthBar.hide()
	if has_node("HealthBar"):
	# 将修理进度转换为百分比
		$HealthBar.value = ($workbench.repair_progress / $workbench.repair_duration) * 100
	# 动态改变颜色（例如：黄色→绿色）
		if $HealthBar.value < 50:
			$HealthBar.tint_progress = Color.YELLOW
		else:
			$HealthBar.tint_progress = Color.GREEN
