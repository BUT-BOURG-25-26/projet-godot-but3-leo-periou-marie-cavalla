extends Node3D

@export var mouse_sensibility: float = 0.005
@export var touch_sensibility: float = 0.01
@onready var spring_arm := $SpringArm3D

var rotating := false
var last_touch_pos := Vector2.ZERO

func _ready() -> void:
	spring_arm.spring_length = 5
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	# Contrôle à la souris
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * mouse_sensibility
		rotation.y = wrapf(rotation.y, 0.0, TAU)
		
		rotation.x -= event.relative.y * mouse_sensibility
		rotation.x = clamp(rotation.x, -PI/2, PI/4)

	# Contrôle tactile
	elif event is InputEventScreenTouch:
		if event.pressed:
			rotating = true
			last_touch_pos = event.position
		else:
			rotating = false

	elif event is InputEventScreenDrag and rotating:
		var delta = event.position - last_touch_pos
		last_touch_pos = event.position
		
		rotation.y -= delta.x * touch_sensibility
		rotation.y = wrapf(rotation.y, 0.0, TAU)
		
		rotation.x -= delta.y * touch_sensibility
		rotation.x = clamp(rotation.x, -PI/2, PI/4)

	# Zoom avec la molette
	if event.is_action_pressed("wheel_up"):
		if spring_arm.spring_length > 1:
			spring_arm.spring_length -= 1
	if event.is_action_pressed("wheel_down"):
		if spring_arm.spring_length < 8:
			spring_arm.spring_length += 1

	# Capture du curseur
	if event.is_action_pressed("toggle_mouse_capture"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
