class_name Melee extends Node3D

signal attack_finished

@export_group("Weapon Stats")
@export var damage: float = 10.0
@export var cooldown_time: float = 0.8
@export var is_two_handed: bool = false
@export var weight: float = 0.0
@export_enum("Enemy","Player") var target: String = "Enemy"
@export_enum("Left","Right") var hand: String = "Right"
@export var cost: int = 1

@onready var hitbox: Area3D = $Hitbox 
@onready var cooldown_timer: Timer = $CooldownTimer
@onready var delay_timer: Timer = $DelayTimer
@onready var attack_sound: AudioStreamPlayer3D = $AttackSound

var delay_time: float 
var active_time: float 
var wielder_strength: float = 0.0
var is_hitbox_active: bool = false
var hit_history: Array[Node3D] = [] 
var wielder: Node3D = null 

func _ready() -> void:
	hitbox.monitoring = false 
	
	if(is_two_handed):
		delay_time = 0.4
		active_time = 0.5
	else:
		delay_time = 0.25
		active_time = 0.4
		
	cooldown_timer.wait_time = cooldown_time
	delay_timer.wait_time = delay_time
	
	delay_timer.timeout.connect(_on_delay_timeout)
	cooldown_timer.timeout.connect(_on_cooldown_finished)
	
	hitbox.body_entered.connect(_on_body_entered)
		
func start_attack(strength: float) -> void:
	wielder_strength = strength
	delay_timer.start()

func _on_delay_timeout() -> void:
	if attack_sound:
		attack_sound.play()
	
	is_hitbox_active = true
	hit_history.clear()
	hitbox.monitoring = true
	
	if hitbox.has_overlapping_bodies():
		for body in hitbox.get_overlapping_bodies():
			_try_deal_damage(body)
	
	get_tree().create_timer(active_time).timeout.connect(_on_active_time_finished)

func _on_body_entered(body: Node3D) -> void:
	if is_hitbox_active:
		_try_deal_damage(body)

func _try_deal_damage(body: Node3D) -> void:
	if body.is_in_group(target) and body not in hit_history:
		if body.has_method("take_damage"):
			body.take_damage(damage + wielder_strength, wielder, false)
			hit_history.append(body)

func _on_active_time_finished() -> void:
	is_hitbox_active = false
	hitbox.monitoring = false 
	cooldown_timer.start()

func _on_cooldown_finished() -> void:
	attack_finished.emit()
