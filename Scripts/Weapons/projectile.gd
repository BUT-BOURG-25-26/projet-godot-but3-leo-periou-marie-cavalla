extends Area3D

var damage: float = 0.0
var speed: float = 0.0
var lifetime: float = 10.0
var enemy_stand: bool = false
@export_enum("Enemy","Player") var target: String = "Enemy"

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	# Timer de sécurité pour supprimer les flèches perdues
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func setup(new_damage: float, new_speed: float, e_stand: bool) -> void:
	damage = new_damage
	speed = new_speed
	enemy_stand = e_stand

func _physics_process(delta: float) -> void:
	# Fait avancer la flèche tout droit
	position -= transform.basis.z * speed * delta

func _on_body_entered(body: Node) -> void:
	# Si on touche une cible
	if body.is_in_group(target):
		if body.has_method("take_damage"):
			body.take_damage(damage, enemy_stand)
		queue_free() # La flèche disparait après l'impact
	
	# Si on touche un mur
	elif body is GridMap or body is StaticBody3D: 
		queue_free() # La flèche se plante dans le mur
