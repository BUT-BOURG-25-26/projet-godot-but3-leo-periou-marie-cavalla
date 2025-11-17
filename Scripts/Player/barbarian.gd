extends CharacterBody3D

# Object
@onready var camera = $SpringArmPivot/Camera3D
@onready var player_ui = $PlayerUi
@onready var model = $Model
@onready var attack_range = $AttackRange
@onready var death_screen = $DeathScreen
@onready var attack_cooldown = $AttackCooldown
@onready var attack_delay = $AttackDelay
@onready var attack_sound = $AttackSound
@onready var joystick = $MobileUi/VirtualJoystick
@onready var anim_tree = $Model/AnimationTree
@onready var anim_state = anim_tree.get("parameters/playback")

# Export variables
@export var speed: float = 5.0
@export var jump_force: float = 4.0
@export var attack_damage: float = 20.0
@export var health: float = 100.0
@export var kill: int = 0

# Variables
var can_action: bool = true
var blocking: bool = false
var attack_range_list = []

func _ready() -> void:
	player_ui.call("set_health_bar", health) # Init UI health

func _physics_process(delta: float) -> void:
	var direction
	
	# Comportement Action
	if is_on_floor() and can_action:
		var move_inputs = read_move_input()
		direction = (transform.basis * move_inputs).normalized()
		direction = direction.rotated(Vector3.UP, camera.global_rotation.y)

		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
		if Input.is_action_just_pressed("attack"):
			anim_state.travel("Attack") # Attack animation
			attack_input()
		
		elif Input.is_action_pressed("block"):
			anim_state.travel("Block")
			blocking_input()
		
		elif Input.is_action_just_released("block"):
			unblocking_input()
		
		elif Input.is_action_just_pressed("jump"):
			anim_state.travel("Jump") # Jump animation
			velocity.y = jump_force
		
		elif velocity.x != 0 or velocity.z != 0:
			anim_state.travel("Running") # Walk animation
		
		else:
			anim_state.travel("Idle") # Idle animation
	
	# Bouge pas pendant une action
	elif is_on_floor() and not can_action:
		direction = Vector3.ZERO
		velocity.x = 0
		velocity.z = 0
	
	# Tombe
	else:
		direction = Vector3.ZERO
		velocity.y += get_gravity().y * delta
		anim_state.travel("Jump")
	
	# Déplacement
	move_and_slide()
	
	# Tourner le modèle
	if direction.length() > 0.01:
		var target_rotation = atan2(direction.x, direction.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_rotation, delta * 10.0)
		attack_range.rotation.y = lerp_angle(attack_range.rotation.y, target_rotation, delta * 10.0)

# -- Lectures d'Input --
func read_move_input() -> Vector3:
	var move_inputs: Vector3 = Vector3.ZERO
	
	# Mobile
	if joystick and joystick.direction.length() > 0.1:
		move_inputs.x = joystick.direction.x
		move_inputs.z = joystick.direction.y
	
	# PC
	else:
		move_inputs.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		move_inputs.z = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	
	return move_inputs.normalized()

# -- Input d'actions --
func attack_input():
	can_action = false
	speed = 0.0
	attack_delay.start()

func blocking_input():
	blocking = true
	speed = 0.0

func unblocking_input():
	blocking = false
	speed = 5.0
	
# -- Cooldown --
func _attack_delay() -> void:
	attack_sound.play()
	for enemy in attack_range_list:
		enemy.call("take_damage", attack_damage)
	attack_cooldown.start()
	
func _attack_cooldown() -> void:
	can_action = true
	speed = 5.0

# -- Fonctions d'attaques --
func _add_attack_list(body: Node3D) -> void:
	if("Enemy" in body.name):
		attack_range_list.append(body)

func _remove_attack_list(body: Node3D) -> void:
	if("Enemy" in body.name):
		attack_range_list.erase(body)

func add_kill():
	kill += 1
	player_ui.call("set_kill_counter", kill)
	
# -- Damage / Mort --
func take_damage(damage: float):
	if(health > 0) and not blocking:
		health -= damage
		player_ui.take_damage(damage)
		if(health <= 0):
			die()

func die():
	set_process(false)
	set_physics_process(false)
	anim_state.travel("Death")
	death_screen.call("show_death_screen")
