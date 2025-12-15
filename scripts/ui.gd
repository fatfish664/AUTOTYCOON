extends Control

@onready var time_label: Label = $TimeLabel

func _process(_delta):
	if time_label:
		time_label.text = TimeSystem.get_time()
