extends Sprite2D

# 给多个Sprite2D节点提供，让其处于底层层级

func _ready():
	z_index = clamp(-2000, -32766, 32767)
