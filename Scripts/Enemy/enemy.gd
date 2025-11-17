extends CharacterBody3D

@export var health: float = 100
@export var speed: float = 1
@export var attack_damage: float = 10.0
@export var can_action: bool = true
@export var player_in_range: bool = false
@export var player_detected: bool = false

@onready var player: Node3D = get_tree().get_nodes_in_group("Player")[0]
@onready var model = $Model
@onready var collision = $CollisionShape3D
@onready var attack_range = $AttackRange
@onready var enemy_ui = $EnemyUi
@onready var attack_cooldown = $AttackCooldown
@onready var attack_delay = $AttackDelay
@onready var dead_cooldown = $DeadCooldown
@onready var hit_cooldown = $HitCooldown
@onready var destroy_cooldown = $DestroyCooldown
@onready var detector = $Detector
@onready var eyes_light = $Model/SpotLight3D
@onready var death_particle = $DeathParticle

# Son
@onready var attack_sound = $AttackSound
@onready var hit_sound_1 = $HitSound1
@onready var hit_sound_2 = $HitSound2
@onready var death_sound = $DeathSound
@onready var hit_sound : Array[AudioStreamPlayer] = [$HitSound1, $HitSound2]

@onready var anim_tree = $Model/AnimationTree
@onready var anim_state = anim_tree.get("parameters/playback")

func _ready() -> void:
	enemy_ui.call("set_health_bar", health)

func _physics_process(delta: float) -> void:
	if not player:
		return
		
	if not player_detected:
		anim_state.travel("Idle_Combat") # Default animation
		return
	
	# Direction vers le joueur
	var direction = (player.global_transform.origin - global_transform.origin)
	direction.y = 0
	direction = direction.normalized()
	
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	
	# Comportement
	if is_on_floor() and can_action:
		if player_in_range:
			anim_state.travel("1H_Melee_Attack_Slice_Horizontal") # Attack animation
			attack()
		
		elif velocity.x != 0 or velocity.z != 0:
			anim_state.travel("Walking_D_Skeletons") # Walk animation
		
		else:
			anim_state.travel("Idle_Combat") # Idle animation
	
	else:
		velocity.y += get_gravity().y * delta
	
	move_and_slide()
	
	# Rotation du modèle
	if direction.length() > 0.01:
		var target_rotation = atan2(direction.x, direction.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_rotation, delta * 10.0)
		attack_range.rotation.y = lerp_angle(attack_range.rotation.y, target_rotation, delta * 10.0)
		
		
func take_damage(damage: float):
	health -= damage
	enemy_ui.take_damage(damage)
	hit_sound[randi_range(0,1)].play()
	anim_state.travel("Hit_B")
	can_action = false
	speed = 0.0
	hit_cooldown.start()
	if(health<=0):
		die()

func attack():
	can_action = false
	speed = 0.0
	attack_delay.start()

func _attack_delay() -> void:
	attack_sound.play()
	if(player_in_range):
		player.call("take_damage", attack_damage)
	attack_cooldown.start()

func _attack_cooldown_timeout() -> void:
	speed = 1.0
	can_action = true;

func _in_attack_range(body: Node3D) -> void:
	if body == player:
		player_in_range = true

func _out_attack_range(body: Node3D) -> void:
	if body == player:
		player_in_range = false
		
func _detector_body(body: Node3D) -> void:
	if body == player:
		player_detected = true

func _hit_cooldown() -> void:
	speed = 1.0
	can_action = true;

func die():
	set_process(false)
	set_physics_process(false)
	player.call("add_kill")
	death_particle.emitting = true
	collision.queue_free()
	eyes_light.queue_free()
	anim_state.travel("Death_B")
	death_sound.play()
	dead_cooldown.start()

func _dead_cooldown() -> void:
	model.hide()
	enemy_ui.hide()
	death_particle.emitting = false
	destroy_cooldown.start()


func _destroy_cooldown() -> void:
	queue_free()
