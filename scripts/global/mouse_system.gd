extends Node2D

@onready var custom_cursor := $CanvasLayer/Mouse

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _process(_delta):
	
	custom_cursor.position = get_viewport().get_mouse_position()
