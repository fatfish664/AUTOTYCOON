extends Node2D

@onready var time_label: Label = $TimeLabel

func _ready():
	z_index = clamp(2100, -32766, 32767)

func _process(_delta):
	if time_label:
		time_label.text = TimeSystem.get_time()
