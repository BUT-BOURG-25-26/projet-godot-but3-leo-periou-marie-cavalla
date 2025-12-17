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
@onready var separation_ray = $SeparationRay

# --- EXPORT STATS ---
@export var speed: float = 5.0
@export var jump_force: float = 4.0
@export var strength: float = 20
@export var health: float = 100.0
@export var max_health: float = 100.0
@export var money: int = 0

# --- VARIABLES ---
var can_action: bool = true
var blocking: bool = false
var is_dead: bool = false
var current_weapon: Node3D
var current_shield: Shield
var ray_offset_distance: float = 0.45
var base_speed: float
var base_strength: float
var active_boosts: Dictionary = {}

func _ready() -> void:
	base_speed = speed
	base_strength = strength
	player_ui.call("set_health_bar", health)
	player_ui.call("set_money_counter", money)
	init_player_class()

func _physics_process(delta: float) -> void:
	
	update_boosts_timers(delta)

	if is_dead:
		velocity.x = 0
		velocity.z = 0
		velocity.y += get_gravity().y * delta
		move_and_slide()
		return

	var direction
# --- CALCUL DU POIDS ---
	var weight_penalty = -(strength/100)
	if current_weapon:
		weight_penalty += current_weapon.get("weight")
	if current_shield:
		weight_penalty += current_shield.weight
	var current_speed = speed * (1.0 - clamp(weight_penalty*3, 0.0, 0.9))
	
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
			direction = Vector3.ZERO
		
		elif Input.is_action_just_released("block"):
			blocking = false
			velocity.x = 0
			velocity.z = 0
		
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
		
		var offset_vector = Vector3(0, 0, ray_offset_distance)
		var rotated_offset = offset_vector.rotated(Vector3.UP, model.rotation.y)
		if separation_ray:
			separation_ray.position.x = rotated_offset.x
			separation_ray.position.z = rotated_offset.z
		
		
	update_locomotion()

# --- SYSTEME DE BOOST OPTIMISE ---

func apply_boost(type: String, duration: float):
	# Cas spécial pour la vie
	if type == "Health":
		if health < max_health:
			var heal_amount = 30.0
			health = min(health + heal_amount, max_health)
			player_ui.heal(heal_amount)
			player_ui.set_health_bar(health)
		return

	# Cas pour les boosts temporaires
	if active_boosts.has(type):
		# CUMUL
		active_boosts[type]["time"] += duration
	else:
		active_boosts[type] = {
			"time": duration,
			"value": get_boost_value(type)
		}
	
	# On recalcule les stats immédiatement
	recalc_stats()

func get_boost_value(type: String) -> float:
	match type:
		"Attack": return 5.0
		"Speed": return 5.0
	return 0.0

func update_boosts_timers(delta: float):
	if active_boosts.is_empty():
		return
		
	var has_changed = false
	var keys_to_remove = []
	
	for type in active_boosts:
		active_boosts[type]["time"] -= delta
		
		if active_boosts[type]["time"] <= 0:
			keys_to_remove.append(type)
			has_changed = true
	
	# Nettoyage des boosts expirés
	for k in keys_to_remove:
		active_boosts.erase(k)
	
	# Si un boost a expiré, on recalcule les stats
	if has_changed:
		recalc_stats()
		
	# Mise à jour UI
	player_ui.update_boosts_display(active_boosts)

func recalc_stats():
	speed = base_speed
	strength = base_strength
	
	# On applique tous les bonus actifs
	if active_boosts.has("Speed"):
		speed += active_boosts["Speed"]["value"]
	
	if active_boosts.has("Attack"):
		strength += active_boosts["Attack"]["value"]

# --- INITIALISATION DE LA CLASSE DU JOUEUR ---

func init_player_class():
	var current_class_name:String = self.name
	match current_class_name :
		"Barbarian":
			equip_weapon("Melee/axe_1h")
		"Knight":
			equip_weapon("Melee/sword_1h")
		"Mage":
			equip_weapon("Melee/hand")
		"Ranger":
			equip_weapon("Melee/dagger")
		"Rogue":
			equip_weapon("Ranged/crossbow_1h")
# --- ANIMATION ---

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
				if((health+30)>max_health):
					var difference:float = max_health-health
					health = max_health
					player_ui.heal(difference)
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

func take_damage(damage: float, attacker: Node3D = null, is_ranged: bool = false):
	if is_dead: return

	var final_damage = damage
	
	# --- LOGIQUE DE BLOCAGE ---
	var successful_block = false
   
	if blocking and current_shield:
	
		if attacker:
			var direction_to_attacker = (attacker.global_position - global_position).normalized()
			var forward_vector = model.global_transform.basis.z 
			var angle = direction_to_attacker.dot(forward_vector)
			if angle > 0.0: # Blocage réussi
				successful_block = true
		else:
			successful_block = true 

	# --- APPLICATION ---
	if successful_block:
		final_damage = current_shield.process_hit(damage, attacker, is_ranged)

	if final_damage > 0:
		health -= final_damage
		player_ui.take_damage(final_damage)
		
		if health <= 0:
			die()

func die():
	is_dead = true
	anim_state.travel("Death")
	death_screen.call("show_death_screen")

func set_money(amount: int):
	money += amount
	player_ui.call("set_money_counter", money)

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
	
	if "wielder" in current_weapon:
		current_weapon.wielder = self
	
	if current_weapon.has_signal("attack_finished"):
		current_weapon.attack_finished.connect(_on_weapon_attack_finished)
	if current_weapon.has_signal("needs_reload"):
		current_weapon.needs_reload.connect(_on_weapon_needs_reload)
	
	update_locomotion()
	
func equip_shield(shield_name: String):
	var path = "res://Scenes/Weapons/%s.tscn" % shield_name
	var shield_scene = load(path)
	
	if not shield_scene:
		push_error("Bouclier introuvable: " + path)
		return

	if current_shield:
		current_shield.queue_free()

	var new_shield = shield_scene.instantiate()
	
	weapon_slot_left.add_child(new_shield)
	
	if new_shield is Shield:
		current_shield = new_shield
		current_shield.wielder = self
	
	else:
		push_error("La scène chargée n'a pas le script shield.gd")

func read_move_input() -> Vector3:
	var move_inputs: Vector3 = Vector3.ZERO
	if joystick and joystick.direction.length() > 0.1:
		move_inputs.x = joystick.direction.x
		move_inputs.z = joystick.direction.y
	else:
		move_inputs.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		move_inputs.z = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	return move_inputs.normalized()
