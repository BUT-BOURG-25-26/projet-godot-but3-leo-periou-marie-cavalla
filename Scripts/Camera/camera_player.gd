extends Node3D

@export var mouse_sensibility: float = 0.005
@export var touch_sensibility: float = 0.01
@export var zoom_speed_touch: float = 0.01 # Vitesse du zoom tactile
@onready var spring_arm := $SpringArm3D

var _active_touches = {}

func _ready() -> void:
	spring_arm.spring_length = 5
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	# Gestion Souris (PC)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(event.relative)

	# Gestion Tactile (Mobile)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_active_touches[event.index] = event.position
		else:
			_active_touches.erase(event.index)

	elif event is InputEventScreenDrag:
		_active_touches[event.index] = event.position
		
		# Un seul doigt sur l'écran (Rotation)
		if _active_touches.size() == 1:
			if event.index in _active_touches:
				_rotate_camera(event.relative * 2.0)

		# Deux doigts sur l'écran (Zoom)
		elif _active_touches.size() == 2:
			var keys = _active_touches.keys()
			var finger1_pos = _active_touches[keys[0]]
			var finger2_pos = _active_touches[keys[1]]
			
			var current_dist = finger1_pos.distance_to(finger2_pos)
			
			var finger1_prev = finger1_pos
			var finger2_prev = finger2_pos
			
			if event.index == keys[0]:
				finger1_prev = finger1_pos - event.relative
			else:
				finger2_prev = finger2_pos - event.relative
				
			var prev_dist = finger1_prev.distance_to(finger2_prev)
			
			# La différence de distance détermine le zoom
			var zoom_factor = prev_dist - current_dist
			_zoom_camera(zoom_factor * zoom_speed_touch)

	# Zoom Molette (PC)
	if event.is_action_pressed("wheel_up"):
		_zoom_camera(-1.0)
	if event.is_action_pressed("wheel_down"):
		_zoom_camera(1.0)

	# Capture du curseur (PC)
	if event.is_action_pressed("toggle_mouse_capture"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Fonction utilitaire pour tourner
func _rotate_camera(relative: Vector2) -> void:
	rotation.y -= relative.x * mouse_sensibility
	rotation.y = wrapf(rotation.y, 0.0, TAU)
	
	rotation.x -= relative.y * mouse_sensibility
	rotation.x = clamp(rotation.x, -PI/2, PI/4)

# Fonction utilitaire pour zoomer
func _zoom_camera(amount: float) -> void:
	spring_arm.spring_length += amount
	spring_arm.spring_length = clamp(spring_arm.spring_length, 1.0, 8.0)
