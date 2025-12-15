extends Area2D

# 进行的动作（用于让其他交互物脚本调用）
func play_animation(condition, direction):
	if condition == "fridge":
		var cartoon = "drink1_fridge_%s" % direction
		$AnimatedSprite2D.animation = cartoon
		$AnimatedSprite2D.play()
	if condition == "walk":
		var cartoon = "drink1_walk_%s" % direction
		$AnimatedSprite2D.animation = cartoon
		$AnimatedSprite2D.play()
	elif condition == "idle":
		return
	else:
		print("特殊动作动画有问题")
