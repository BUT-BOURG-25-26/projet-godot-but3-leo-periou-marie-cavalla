class_name Enemy extends CharacterBody3D

# --- SIGNAUX ---
signal enemy_died(enemy)
signal enemy_despawned(enemy)

# --- REFERENCES ---
@onready var player: Node3D = get_tree().get_first_node_in_group("Player")
@onready var model = $Model
@onready var collision = $CollisionShape3D
@onready var separation_ray = $SeparationRay
@onready var enemy_ui = $EnemyUi
@onready var eyes_light = $Model/SpotLight3D
@onready var death_particle = $Model/DeathParticle
@onready var spawn_particle = $Model/SpawnParticle
@onready var weapon_slot_right = $Model/Rig_Medium/Skeleton3D/HandSlotRight
@onready var weapon_slot_left = $Model/Rig_Medium/Skeleton3D/HandSlotLeft

# Timers
@onready var dead_cooldown = $DeadCooldown
@onready var hit_cooldown = $HitCooldown
@onready var destroy_cooldown = $DestroyCooldown

# Audio
@onready var hit_sound : Array[AudioStreamPlayer3D] = [$HitSound1, $HitSound2]
@onready var death_sound = $DeathSound

# Animation
@onready var anim_tree = $Model/AnimationTree
@onready var anim_state = anim_tree.get("parameters/playback")

# --- EXPORT VARIABLES ---
@export_group("Stats")
@export var health: float = 100
@export var speed: float = 2.0
@export var strength: float = 5
@export var reward: int = 0
@export var boost_spawn_rate: int = 5

@export_group("Combat Settings")
@export var max_distance_to_player: float = 50.0
@export var attack_range: float = 1.8
@export_range(-1.0, 1.0) var attack_fov: float = 0.8
@export_enum("axe","blade","crossbow","staff","boss_axe") var weapon: String

@export_group("Type")
@export var is_boss: bool = false

# --- VARIABLES INTERNES ---
var current_weapon: Node3D
var can_action: bool = true
var is_dead: bool = false
var ray_offset_distance: float = 0.45
var turn_speed: float = 10.0

# Spawn
var is_spawning: bool = false
var spawn_target_y: float = 0.0
var spawn_rise_speed: float = 2.0

func _ready() -> void:
	enemy_ui.call("set_health_bar", health)
	equip_weapon(weapon)
	
	if is_boss:
		turn_speed = 1.0
	else:
		turn_speed = 10.0

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if is_spawning:
		_process_spawn_movement(delta)
		return

	if not player: return


	var dist_sq_to_player = global_position.distance_squared_to(player.global_position)
	var max_dist_sq = max_distance_to_player * max_distance_to_player
	if dist_sq_to_player > max_dist_sq:
		emit_signal("enemy_despawned", self)
		queue_free()
		return
	
	var direction := Vector3.ZERO
	direction = (player.global_position - global_position)
	direction.y = 0
	direction = direction.normalized()

	if can_action:
		_handle_rotation(direction, delta)
		_handle_movement_and_attack(direction, sqrt(dist_sq_to_player))
	elif not can_action:
		velocity.x = 0
		velocity.z = 0
		velocity.y += get_gravity().y * delta
	else:
		velocity.y += get_gravity().y * delta

	move_and_slide()
	update_locomotion()

# --- LOGIQUE DE SPAWN ---
func init_spawn_sequence(target_y: float):
	is_spawning = true
	can_action = false
	spawn_target_y = target_y
	hide()
	collision.disabled = true 

func _process_spawn_movement(delta: float):
	global_position.y += spawn_rise_speed * delta
	if global_position.y >= spawn_target_y:
		global_position.y = spawn_target_y
		_finish_spawn_rise()

func _finish_spawn_rise():
	is_spawning = false
	show()
	anim_state.start("Spawn")
	if spawn_particle: spawn_particle.emitting = true
	await get_tree().create_timer(3.5).timeout
	can_action = true
	collision.disabled = false
	if spawn_particle: spawn_particle.emitting = false

# --- LOGIQUE DE MOUVEMENT & ROTATION ---
func update_locomotion():
	if not can_action or is_dead or is_spawning:
		return

	var horizontal_velocity = Vector2(velocity.x, velocity.z)
	if horizontal_velocity.length() > 0.1:
		anim_state.travel("Running")
	else:
		anim_state.travel("Idle")

func _handle_rotation(direction: Vector3, delta: float):
	var target_rotation = atan2(direction.x, direction.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_rotation, delta * turn_speed)
	
	if separation_ray:
		var offset_vector = Vector3(0, 0, ray_offset_distance)
		var rotated_offset = offset_vector.rotated(Vector3.UP, model.rotation.y)
		separation_ray.position.x = rotated_offset.x
		separation_ray.position.z = rotated_offset.z

func _handle_movement_and_attack(direction: Vector3, dist_to_player: float):
	if is_on_floor():
		if _should_attack(dist_to_player, direction):
			velocity.x = 0
			velocity.z = 0
			if current_weapon:
				trigger_attack()
		else:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
	else:
		velocity.y += get_gravity().y * get_physics_process_delta_time()

func _should_attack(dist_to_player: float, direction_to_player: Vector3) -> bool:
	# Vérification de la distance
	if dist_to_player > attack_range:
		return false
	
	var forward_vector = model.global_transform.basis.z
	
	# Produit scalaire
	var angle = forward_vector.dot(direction_to_player)
	
	if angle >= attack_fov:
		return true
		
	return false

# --- COMBAT ---
func trigger_attack():
	if not hit_cooldown.is_stopped(): return
	
	can_action = false
	velocity = Vector3.ZERO
	
	var action_name = "Attack"
	if current_weapon is Ranged: action_name = "Shoot"
	
	if anim_state.get_current_node() == action_name:
		anim_state.start(action_name)
	else:
		anim_state.travel(action_name)

	if current_weapon.has_method("start_attack"):
		current_weapon.start_attack(strength)

func take_damage(damage: float, _attacker: Node3D = null, _is_ranged: bool = false):
	if is_dead or is_spawning: return
		
	health -= damage
	if enemy_ui: enemy_ui.take_damage(damage)
	if hit_sound.size() > 0: hit_sound.pick_random().play()
	
	if not is_boss:
		if anim_state.get_current_node() == "Hit": anim_state.start("Hit")
		else: anim_state.travel("Hit")
		can_action = false
		hit_cooldown.start()
	
	if health <= 0: die()

func die():
	if is_dead: return
	is_dead = true
	emit_signal("enemy_died", self)
	if player.has_method("set_money"): player.call("set_money", reward)
	if eyes_light: eyes_light.queue_free()
	collision.queue_free()
	if separation_ray: separation_ray.queue_free()
	if enemy_ui: enemy_ui.queue_free()
	anim_state.travel("Death")
	death_sound.play()
	dead_cooldown.start()
	create_boost()
	
func create_boost():
	if randi_range(0, 10) < boost_spawn_rate:
		game_manager.create_boost(global_position)

# --- UTILS ---
func equip_weapon(weapon_name: String):
	# ... (ton code equip weapon inchangé) ...
	var path = "res://Scenes/Weapons/Enemy/enemy_%s.tscn" % weapon_name
	var weapon_scene = load(path)
	if not weapon_scene: return

	if current_weapon: current_weapon.queue_free()

	var new_weapon = weapon_scene.instantiate()
	var hand = new_weapon.get("hand")
	
	if hand == "Left": weapon_slot_left.add_child(new_weapon)
	else: weapon_slot_right.add_child(new_weapon)
		
	current_weapon = new_weapon
	if "wielder" in current_weapon: current_weapon.wielder = self
	
	if current_weapon.has_signal("attack_finished"):
		current_weapon.attack_finished.connect(_on_weapon_attack_finished)
	if current_weapon.has_signal("needs_reload"):
		current_weapon.needs_reload.connect(_on_weapon_needs_reload)
	update_locomotion()

func _on_weapon_attack_finished():
	if is_dead: return
	if hit_cooldown.is_stopped(): can_action = true

func _on_weapon_needs_reload(duration: float):
	if not hit_cooldown.is_stopped(): return
	can_action = false
	velocity = Vector3.ZERO
	anim_state.travel("Reload")
	await get_tree().create_timer(duration).timeout
	if current_weapon and current_weapon.has_method("complete_reload"):
		current_weapon.complete_reload()
	else: _on_weapon_attack_finished()

func _hit_cooldown() -> void:
	can_action = true
	speed = 2.0

func _dead_cooldown() -> void:
	if death_particle: death_particle.emitting = true
	destroy_cooldown.start()

func _destroy_cooldown() -> void:
	queue_free()
