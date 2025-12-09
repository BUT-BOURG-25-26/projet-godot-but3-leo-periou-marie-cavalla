extends StaticBody3D

# --- CONFIGURATION ---
@export_group("Loot Settings")

# Liste des chemins d'armes
@export var available_weapons: Array[String] = [
	"Melee/sword_1h",
	"Melee/axe_1h",
	"Melee/dagger",
	"Ranged/crossbow_1h",
]
# Temps d'attente avant que l'arme apparaisse (en secondes)
@export var opening_delay: float = 0.3

@onready var interaction_area = $InteractionArea
@onready var spawn_point = $SpawnPoint
@onready var label = $Label3D
@onready var model = $Model

# Variables d'état
var player_in_range: Node3D = null
var is_open: bool = false
var is_looted: bool = false
var generated_weapon_name: String = ""
var visual_weapon_node: Node3D = null

func _ready() -> void:
	if label: label.text = "" 
	
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	# Rotation de l'arme
	if is_open and not is_looted and visual_weapon_node:
		visual_weapon_node.rotation.y += delta * 1.0

	# Gestion de l'input
	if player_in_range and Input.is_action_just_pressed("interact"):
		handle_interaction()

func handle_interaction():
	if not is_open:
		open_chest()
	elif is_open and not is_looted:
		take_loot()

func open_chest():
	is_open = true
	
	if label: label.text = ""
	
	var anim_player = model.get_node("AnimationPlayer")
	if anim_player: anim_player.play("open")
	
	await get_tree().create_timer(opening_delay).timeout
	
	# Choisir une arme au hasard
	if available_weapons.size() > 0:
		generated_weapon_name = available_weapons.pick_random()
		spawn_visual_weapon(generated_weapon_name)
		
		var display_name = generated_weapon_name.split("/")[-1]
		display_name = display_name.replace("_", " ") 

		if label:
			label.text = "Prendre : " + display_name
	else:
		push_error("Aucune arme dans la liste du coffre !")

func spawn_visual_weapon(weapon_name: String):
	var path = "res://Scenes/Weapons/%s.tscn" % weapon_name
	var scene = load(path)
	if scene:
		visual_weapon_node = scene.instantiate()
		add_child(visual_weapon_node)
		
		# On la place au spawn point
		visual_weapon_node.global_position = spawn_point.global_position
		
		visual_weapon_node.process_mode = Node.PROCESS_MODE_DISABLED
		
		var tween = create_tween()
		tween.tween_property(visual_weapon_node, "position:y", spawn_point.position.y + 1.5, 0.5).from(spawn_point.position.y)

func take_loot():
	is_looted = true

	if player_in_range.has_method("equip_weapon"):
		player_in_range.equip_weapon(generated_weapon_name)
	
	if visual_weapon_node:
		visual_weapon_node.queue_free()
	
	if label: label.text = ""

	interaction_area.queue_free()

# --- DETECTION JOUEUR ---
func _on_body_entered(body: Node3D):
	if body.is_in_group("Player"):
		player_in_range = body
		if not is_open:
			if label: label.text = "Ouvrir"
		elif not is_looted:
			if visual_weapon_node:
				if label: label.text = "Prendre"

func _on_body_exited(body: Node3D):
	if body == player_in_range:
		player_in_range = null
		if label: label.text = ""
