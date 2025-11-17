extends Control

@export var radius := 80.0
@export var active_area := Rect2(Vector2.ZERO, Vector2(300, 300))

var direction: Vector2 = Vector2.ZERO
var dragging := false
var finger_index := -1

@onready var base := $Base
@onready var stick := $Base/Stick


func _ready():
	stick.position = (base.size-stick.size) / 2

func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			var local_pos = event.position - global_position
			
			if active_area.has_point(local_pos):
				dragging = true
				finger_index = event.index
				_update_stick(local_pos)
		else:
			if event.index == finger_index:
				dragging = false
				finger_index = -1
				direction = Vector2.ZERO
				stick.position = (base.size-stick.size) / 2

	elif event is InputEventScreenDrag and dragging and event.index == finger_index:
		var local_pos = event.position - global_position
		_update_stick(local_pos)


func _update_stick(pos: Vector2):
	var center = (base.size-stick.size) / 2
	var offset = pos - center

	if offset.length() > radius:
		offset = offset.normalized() * radius

	stick.position = center + offset

	direction = offset / radius
