extends Sprite2D

func _process(_delta):
	z_index = clamp($ShelterBase.global_position.y, -1000, 10000) # 根据Y值设置z_index，Y值越大的物体会被设置为更高的z_index，从而显示在前面。
