class_name Ranged extends Node3D

signal attack_finished
signal needs_reload(duration: float) # Signal pour dire au player de jouer l'anim

@export_group("Ranged Stats")
@export var damage: float = 10.0
@export var cooldown_time: float = 0.5 # Temps de "recul" après le tir
@export var reload_time: float = 1.5   # Temps obligatoire de l'animation de reload
@export var delay_time: float = 0.5    # Temps avant que la flèche parte
@export var projectile_speed: float = 30.0
@export var is_two_handed: bool = false
@export var weight: float = 0.1
@export var is_bow: bool = false
@export_enum("Left","Right") var hand: String = "Right"
@export var cost: int = 1

@export_group("Projectile Setup")
@export var projectile_scene: PackedScene 
@onready var spawn_point: Marker3D = $SpawnPoint 

@onready var cooldown_timer: Timer = $CooldownTimer
@onready var delay_timer: Timer = $DelayTimer
@onready var shoot_sound: AudioStreamPlayer3D = $ShootSound

var wielder_strength: float = 0.0

func _ready() -> void:
	if not projectile_scene:
		push_error("Attention: Pas de Projectile Scene assignée !")
		
	cooldown_timer.wait_time = cooldown_time
	delay_timer.wait_time = delay_time
	
	delay_timer.timeout.connect(_on_delay_timeout)
	cooldown_timer.timeout.connect(_on_cooldown_finished)

func start_attack(strength: float) -> void:
	wielder_strength = strength
	delay_timer.start()

func _on_delay_timeout() -> void:
	if shoot_sound:
		shoot_sound.play()
	
	spawn_projectile()
	cooldown_timer.start()

func _on_cooldown_finished() -> void:
	if(is_bow):
		attack_finished.emit()
	else:
		needs_reload.emit(reload_time)
	
func complete_reload() -> void:
	attack_finished.emit()

func spawn_projectile() -> void:
	if projectile_scene and spawn_point:
		var projectile = projectile_scene.instantiate()
		get_tree().root.add_child(projectile)
		projectile.global_position = spawn_point.global_position
		projectile.global_rotation.y = spawn_point.global_rotation.y
		projectile.setup(damage + wielder_strength, projectile_speed, is_two_handed)
