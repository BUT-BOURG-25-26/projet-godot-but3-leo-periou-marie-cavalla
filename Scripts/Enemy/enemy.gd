extends CharacterBody3D

# --- REFERENCES ---
@onready var player: Node3D = get_tree().get_first_node_in_group("Player")
@onready var model = $Model
@onready var collision = $CollisionShape3D
@onready var enemy_ui = $EnemyUi
@onready var detector = $Detector
@onready var eyes_light = $Model/SpotLight3D
@onready var death_particle = $DeathParticle
@onready var weapon_slot_right = $Model/Rig_Medium/Skeleton3D/HandSlotRight
@onready var weapon_slot_left = $Model/Rig_Medium/Skeleton3D/HandSlotLeft

# Timers
@onready var dead_cooldown = $DeadCooldown
@onready var hit_cooldown = $HitCooldown
@onready var destroy_cooldown = $DestroyCooldown

# Audio
@onready var hit_sound : Array[AudioStreamPlayer] = [$HitSound1, $HitSound2]
@onready var death_sound = $DeathSound

# Animation
@onready var anim_tree = $Model/AnimationTree
@onready var anim_state = anim_tree.get("parameters/playback")

# --- EXPORT VARIABLES ---
@export var health: float = 100
@export var boss_health: float = 150
@export var speed: float = 2.0 
@export var strength: float = 5
@export var max_distance_to_player: float = 50.0
@export var attack_range: float = 1.5
@export_enum("axe","blade","crossbow","staff") var weapon: String
@export var boost_spawn_rate: int = 5

# --- VARIABLES ---
var current_weapon: Node3D
var can_action: bool = true
var player_detected: bool = false
var is_dead: bool = false

func _ready() -> void:
	enemy_ui.call("set_health_bar", health)
	
	if detector:
		if not detector.body_entered.is_connected(_detector_body):
			detector.body_entered.connect(_detector_body)
	
	equip_weapon(weapon)

func _physics_process(delta: float) -> void:
	# Gestion de la mort
	if is_dead:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return

	if not player: return
	
	# Gestion de la distance max (Despawn)
	var dist_to_player = global_transform.origin.distance_to(player.global_transform.origin)
	if dist_to_player > max_distance_to_player:
		queue_free()
		return
	
	# Si le joueur n'est pas détecté
	if not player_detected:
		velocity.x = 0
		velocity.z = 0
		velocity.y += get_gravity().y * delta
		update_locomotion()
		move_and_slide()
		return
	
	# --- LOGIQUE DE MOUVEMENT / ATTAQUE ---
	var direction = Vector3.ZERO
	direction = (player.global_transform.origin - global_transform.origin)
	direction.y = 0
	direction = direction.normalized()
	
	# Rotation vers le joueur
	var target_rotation = atan2(direction.x, direction.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_rotation, delta*10)

	if is_on_floor() and can_action:
		# Si on est assez proche pour taper
		if dist_to_player <= attack_range:
			velocity.x = 0
			velocity.z = 0
			# On vérifie qu'on a une arme avant d'attaquer
			if current_weapon:
				trigger_attack()
		
		# Sinon on avance vers le joueur
		else:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
	
	else:
		# En l'air ou occupé
		velocity.y += get_gravity().y * delta
		if not can_action:
			velocity.x = 0
			velocity.z = 0
	
	move_and_slide()
	update_locomotion()

# --- GESTION ANIMATION ---

func update_locomotion():
	if not can_action or is_dead:
		return

	var horizontal_velocity = Vector2(velocity.x, velocity.z)
	# Si on bouge
	if horizontal_velocity.length() > 0.1:
		anim_state.travel("Running")
		return

	anim_state.travel("Idle")

# --- COMBAT ---

func trigger_attack():
	if(!hit_cooldown.is_stopped()):
		return
	
	can_action = false
	velocity = Vector3.ZERO
	
	var action_name = "Attack"
	
	if current_weapon is Ranged: 
		action_name = "Shoot"
	
	anim_state.travel(action_name)
		
	current_weapon.start_attack(strength)

func take_damage(damage: float, get_stand: bool = false):
	if is_dead: return
	
	# Si on prend des dégâts, on détecte automatiquement le joueur
	if not player_detected:
		player_detected = true
		
	health -= damage
	enemy_ui.take_damage(damage)
	
	if hit_sound.size() > 0:
		hit_sound[randi() % hit_sound.size()].play()
		
	anim_state.travel("Hit")
	
	can_action = false
	if get_stand:
		speed = 0.0
		
	hit_cooldown.start()
	
	if health <= 0:
		die()

func die():
	is_dead = true
	if player.has_method("add_kill"):
		player.call("add_kill")
		
	death_particle.emitting = true
	eyes_light.queue_free()
	collision.queue_free()
	
	anim_state.travel("Death")
	death_sound.play()
	dead_cooldown.start()
	create_boost()
	
func create_boost():
	if(randi_range(0,10)<boost_spawn_rate):
		game_manager.create_boost(position)
		
# --- WEAPON SIGNALS ---

func _on_weapon_attack_finished():
	if is_dead: return
	if(hit_cooldown.is_stopped()):
		can_action = true

func _on_weapon_needs_reload(duration: float):
	if(!hit_cooldown.is_stopped()):
		return
	
	can_action = false
	velocity = Vector3.ZERO
	
	anim_state.travel("Reload")
	
	await get_tree().create_timer(duration).timeout
	
	if current_weapon and current_weapon.has_method("complete_reload"):
		current_weapon.complete_reload()
	else:
		_on_weapon_attack_finished()

# --- UTILS ---

func equip_weapon(weapon_name: String):
	var path = "res://Scenes/Weapons/Enemy/enemy_%s.tscn" % weapon_name
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
	
	var hand = new_weapon.get("hand")
	if hand == "Right":
		weapon_slot_right.add_child(new_weapon)
	elif hand == "Left":
		weapon_slot_left.add_child(new_weapon)
	else:
		weapon_slot_right.add_child(new_weapon)
		
	current_weapon = new_weapon
	
	if current_weapon.has_signal("attack_finished"):
		current_weapon.attack_finished.connect(_on_weapon_attack_finished)
	if current_weapon.has_signal("needs_reload"):
		current_weapon.needs_reload.connect(_on_weapon_needs_reload)
		
	update_locomotion()

func _detector_body(body: Node3D) -> void:
	if body == player:
		player_detected = true

func _hit_cooldown() -> void:
	can_action = true
	speed = 2.0

func _dead_cooldown() -> void:
	model.hide()
	enemy_ui.hide()
	death_particle.emitting = false
	destroy_cooldown.start()

func _destroy_cooldown() -> void:
	queue_free()
