extends Node2D

@onready var digits := [
	$"Digits/0",
	$"Digits/1",
	$"Digits/colon",
	$"Digits/2",
	$"Digits/3"
]

const DIGIT_PATH := "res://art_resource/changjing/"
const DIGIT_IMAGES := {
	"0": "0.png",
	"1": "1.png",
	"2": "2.png",
	"3": "3.png",
	"4": "4.png",
	"5": "5.png",
	"6": "6.png",
	"7": "7.png",
	"8": "8.png",
	"9": "9.png",
	":": "colon.png"
}

func _process(_delta):
	var time_str = "%02d:%02d" % [TimeSystem.hours, TimeSystem.minutes]
	for i in range(5):
		var digit_char = time_str[i]
		var path = DIGIT_PATH + DIGIT_IMAGES.get(digit_char, "digit_0.png")
		var texture = load(path)
		if texture and digits[i]:
			digits[i].texture = texture
