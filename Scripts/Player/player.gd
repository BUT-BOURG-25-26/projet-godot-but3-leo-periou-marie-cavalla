class_name Player extends CharacterBody3D

# --- OBJECTS ---
@onready var camera = $SpringArmPivot/Camera3D
@onready var player_ui = $PlayerUi
@onready var model = $Model
@onready var death_screen = $DeathScreen
@onready var joystick = $MobileUi/VirtualJoystick
@onready var anim_tree = $Model/AnimationTree
@onready var anim_state = anim_tree.get("parameters/playback")
@onready var weapon_slot_right = $Model/Rig_Medium/Skeleton3D/HandSlotRight
@onready var weapon_slot_left = $Model/Rig_Medium/Skeleton3D/HandSlotLeft
@onready var collision_shape = $CollisionShape3D

# --- EXPORT STATS ---
@export var speed: float = 5.0
@export var jump_force: float = 4.0
@export var strength: float = 20
@export var health: float = 100.0
@export var max_health: float = 100.0
@export var kill: int = 0

# --- VARIABLES ---
var can_action: bool = true
var blocking: bool = false
var is_dead: bool = false
var current_weapon: Node3D

func _ready() -> void:
	player_ui.call("set_health_bar", health)
	equip_weapon("Melee/sword_2h")

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.x = 0
		velocity.z = 0
		velocity.y += get_gravity().y * delta
		move_and_slide()
		return

	var direction
	var current_speed = speed
	
	if current_weapon:
		current_speed = speed * (1.0 - current_weapon.get("weight"))
	
	if is_on_floor() and can_action:
		var move_inputs = read_move_input()
		direction = (transform.basis * move_inputs).normalized()
		direction = direction.rotated(Vector3.UP, camera.global_rotation.y)

		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		
		# --- GESTION INPUTS ---
		
		if Input.is_action_just_pressed("attack") and current_weapon:
			trigger_attack()
		
		elif Input.is_action_pressed("block"):
			blocking = true
			velocity = Vector3.ZERO
		
		elif Input.is_action_just_released("block"):
			blocking = false
		
		elif Input.is_action_just_pressed("jump"):
			anim_state.travel("Jump") 
			velocity.y = jump_force

	elif is_on_floor() and not can_action:
		direction = Vector3.ZERO
		velocity.x = 0
		velocity.z = 0
	
	else:
		direction = Vector3.ZERO
		velocity.y += get_gravity().y * delta
	
	move_and_slide()
	
	if direction and direction.length() > 0.01:
		var target_rotation = atan2(direction.x, direction.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_rotation, delta * 10.0)
		
	update_locomotion()

# --- OPTIMISATION ANIMATION ---

# Cette fonction détermine le suffixe à utiliser (_1H, _2H, _Bow)
func get_anim_suffix() -> String:
	if not current_weapon:
		return "_1H" # Par défaut si pas d'arme
		
	if current_weapon is Ranged and current_weapon.get("is_bow"):
		return "_Bow"
		
	if current_weapon.is_two_handed:
		return "_2H"
		
	return "_1H"

# Gère les états continus (Idle, Run, Block, Jump)
func update_locomotion():
	if not can_action or is_dead:
		return

	if blocking:
		anim_state.travel("Block")
		return

	if not is_on_floor():
		anim_state.travel("Jump")
		return

	if velocity.length() > 0.1:
		anim_state.travel("Running")
		return

	anim_state.travel("Idle" + get_anim_suffix())

# --- ACTIONS ---

func add_boost(type:String):
	match type :
		"Health" :
			if(health<max_health):
				if(health+30>max_health):
					health = max_health
					player_ui.heal(max_health-health)
				else:
					health += 30
					player_ui.heal(30)
		"Attack" : 
			strength += 5
		"Speed" :
			speed += 5
			
func remove_boost(type:String):
	match type :
		"Attack" : 
			strength -= 5
		"Speed" :
			speed -= 5

func trigger_attack():
	can_action = false
	velocity = Vector3.ZERO
	
	# Construit le nom de l'animation
	var action_name = "Attack"
	if current_weapon is Ranged:
		action_name = "Shoot" 
	
	var full_anim_name = action_name + get_anim_suffix()
	anim_state.travel(full_anim_name)
		
	current_weapon.start_attack(strength)

func _on_weapon_needs_reload(duration: float):
	can_action = false
	velocity = Vector3.ZERO
	
	if current_weapon.is_two_handed:
		anim_state.travel("Reload_2H")
	else:
		anim_state.travel("Reload_1H")
	
	await get_tree().create_timer(duration).timeout
	
	if current_weapon and current_weapon.has_method("complete_reload"):
		current_weapon.complete_reload()
	else:
		_on_weapon_attack_finished()

func _on_weapon_attack_finished():
	if is_dead: return
	can_action = true

# --- GESTION MORT ---

func take_damage(damage: float, _get_stand: bool = false):
	if health > 0 and not blocking:
		health -= damage
		player_ui.take_damage(damage)
		if health <= 0:
			die()

func die():
	is_dead = true
	anim_state.travel("Death")
	death_screen.call("show_death_screen")

func add_kill():
	kill += 1
	player_ui.call("set_kill_counter", kill)

# --- INPUT / EQUIP ---

func equip_weapon(weapon_name: String):
	var path = "res://Scenes/Weapons/%s.tscn" % weapon_name
	var weapon_scene = load(path)
	
	if not weapon_scene:
		push_error("Arme introuvable: " + path)
		return

	if current_weapon:
		if current_weapon.has_signal("attack_finished"):
			if current_weapon.attack_finished.is_connected(_on_weapon_attack_finished):
				current_weapon.attack_finished.disconnect(_on_weapon_attack_finished)
		if current_weapon.has_signal("needs_reload"):
			if current_weapon.needs_reload.is_connected(_on_weapon_needs_reload):
				current_weapon.needs_reload.disconnect(_on_weapon_needs_reload)
		current_weapon.queue_free()

	var new_weapon = weapon_scene.instantiate()
	
	# Gestion main gauche / main droite
	if new_weapon.get("hand") == "Right":
		weapon_slot_right.add_child(new_weapon)
	elif new_weapon.get("hand") == "Left":
		weapon_slot_left.add_child(new_weapon)
	else:
		# Par défaut droite si pas précisé
		weapon_slot_right.add_child(new_weapon)
		
	current_weapon = new_weapon
	
	if current_weapon.has_signal("attack_finished"):
		current_weapon.attack_finished.connect(_on_weapon_attack_finished)
	if current_weapon.has_signal("needs_reload"):
		current_weapon.needs_reload.connect(_on_weapon_needs_reload)
	
	update_locomotion()

func read_move_input() -> Vector3:
	var move_inputs: Vector3 = Vector3.ZERO
	if joystick and joystick.direction.length() > 0.1:
		move_inputs.x = joystick.direction.x
		move_inputs.z = joystick.direction.y
	else:
		move_inputs.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		move_inputs.z = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	return move_inputs.normalized()
