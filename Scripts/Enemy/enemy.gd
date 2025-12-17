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
@export var attack_range: float = 1.8
@export_enum("axe","blade","crossbow","staff") var weapon: String
@export var boost_spawn_rate: int = 5
@export var reward: int = 0

# --- VARIABLES ---
var current_weapon: Node3D
var can_action: bool = true
var is_dead: bool = false
var ray_offset_distance: float = 0.45

func _ready() -> void:
	enemy_ui.call("set_health_bar", health)
	equip_weapon(weapon)

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return

	if not player: return
	
	# Gestion du Despawn
	var dist_to_player = global_transform.origin.distance_to(player.global_transform.origin)
	if dist_to_player > max_distance_to_player:
		emit_signal("enemy_despawned", self) 
		queue_free()
		return
	
	# --- LOGIQUE DE MOUVEMENT / ATTAQUE ---
	var direction = Vector3.ZERO
	direction = (player.global_transform.origin - global_transform.origin)
	direction.y = 0
	direction = direction.normalized()
	
	# Rotation vers le joueur
	var target_rotation = atan2(direction.x, direction.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_rotation, delta * 10.0)
	if separation_ray:
		# On calcule la position devant l'ennemi basé sur l'angle du modèle
		var offset_vector = Vector3(0, 0, ray_offset_distance)
		var rotated_offset = offset_vector.rotated(Vector3.UP, model.rotation.y)
		separation_ray.position.x = rotated_offset.x
		separation_ray.position.z = rotated_offset.z

	if is_on_floor() and can_action:
		# Si on est assez proche pour taper
		if dist_to_player <= attack_range:
			velocity.x = 0
			velocity.z = 0
			if current_weapon:
				trigger_attack()
		
		# Sinon on avance vers le joueur
		else:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
	
	else:
		# En l'air / occupé
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

	if current_weapon.has_method("start_attack"):
		current_weapon.start_attack(strength)

func take_damage(damage: float, _attacker: Node3D = null, _is_ranged: bool = false):
	if is_dead: return
		
	health -= damage
	
	# Mise à jour UI
	if enemy_ui:
		enemy_ui.take_damage(damage)
	
	# Son
	if hit_sound.size() > 0:
		hit_sound[randi() % hit_sound.size()].play()
		
	# Animation
	anim_state.travel("Hit")
	
	# Stun
	can_action = false
	hit_cooldown.start()
	
	if health <= 0:
		die()

func die():
	if is_dead: return 
	is_dead = true
	emit_signal("enemy_died", self)
	
	if player.has_method("set_money"):
		player.call("set_money", reward)
		
	eyes_light.queue_free()
	collision.queue_free()
	separation_ray.queue_free()
	enemy_ui.queue_free()
	anim_state.travel("Death")
	death_sound.play()
	dead_cooldown.start()
	create_boost()
	
func create_boost():
	if(randi_range(0,10) < boost_spawn_rate):
		game_manager.create_boost(global_position)

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
		# Nettoyage des signaux avant suppression
		if current_weapon.has_signal("attack_finished"):
			if current_weapon.attack_finished.is_connected(_on_weapon_attack_finished):
				current_weapon.attack_finished.disconnect(_on_weapon_attack_finished)
		if current_weapon.has_signal("needs_reload"):
			if current_weapon.needs_reload.is_connected(_on_weapon_needs_reload):
				current_weapon.needs_reload.disconnect(_on_weapon_needs_reload)
		current_weapon.queue_free()

	var new_weapon = weapon_scene.instantiate()
	
	# Gestion de la main
	var hand = new_weapon.get("hand")
	if hand == "Right":
		weapon_slot_right.add_child(new_weapon)
	elif hand == "Left":
		weapon_slot_left.add_child(new_weapon)
	else:
		weapon_slot_right.add_child(new_weapon)
		
	current_weapon = new_weapon
	
	# Assignation du propriétaire
	if "wielder" in current_weapon:
		current_weapon.wielder = self
	
	if current_weapon.has_signal("attack_finished"):
		current_weapon.attack_finished.connect(_on_weapon_attack_finished)
	if current_weapon.has_signal("needs_reload"):
		current_weapon.needs_reload.connect(_on_weapon_needs_reload)
		
	update_locomotion()

func _hit_cooldown() -> void:
	can_action = true
	speed = 2.0

func _dead_cooldown() -> void:
	death_particle.emitting = true
	destroy_cooldown.start()

func _destroy_cooldown() -> void:
	queue_free()
