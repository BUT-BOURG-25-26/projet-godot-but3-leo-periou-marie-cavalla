extends Area3D

var damage: float = 0.0
var speed: float = 0.0
var lifetime: float = 10.0
var attacker_ref: Node3D = null 

@export_enum("Enemy","Player") var target: String = "Enemy"

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Timer de sécurité pour supprimer les flèches perdues
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func setup(new_damage: float, new_speed: float, attacker: Node3D) -> void:
	damage = new_damage
	speed = new_speed
	attacker_ref = attacker

func _physics_process(delta: float) -> void:
	global_position -= global_transform.basis.z * speed * delta

func _on_area_entered(area: Area3D) -> void:
	# Si la flèche touche le bouclier
	if area.is_in_group("Shield"):
		var shield_node = area.get_parent()
		
		if shield_node.wielder == attacker_ref: return
		
		if shield_node.has_method("take_hit"):
			shield_node.take_hit(damage, attacker_ref, true)
			queue_free() # La flèche est bloquée

func _on_body_entered(body: Node) -> void:
	if body == attacker_ref: return
	
	if body.is_in_group(target):
		if body.has_method("take_damage"):
			body.take_damage(damage, attacker_ref, true)
		queue_free()
	
	elif body is GridMap or body is StaticBody3D or body.is_in_group("Terrain"):
		queue_free()
