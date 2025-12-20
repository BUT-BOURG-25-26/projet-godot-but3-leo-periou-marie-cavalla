extends StaticBody3D

# --- CONFIGURATION ---
@export_group("Loot Settings")

@export var available_weapons: Array[String] = [
	"Melee/sword_1h",
	"Melee/axe_1h",
	"Melee/dagger",
	"Ranged/crossbow_1h",
	"Shield/shield_badge",
	"Shield/shield_round",
	"Shield/shield_square"
]
@export var opening_delay: float = 0.3

@export_subgroup("Mystery Box Effect")
@export var mystery_duration: float = 4.5
@export var initial_switch_speed: float = 0.05
@export var final_switch_speed: float = 0.5

@onready var interaction_area = $InteractionArea
@onready var spawn_point = $SpawnPoint
@onready var label = $Label3D
@onready var model = $Model
@onready var music = $Music
@onready var light = $SpotLight3D
@onready var light2 = $SpotLight3D2

# Variables d'état
var player_in_range: Node3D = null
var is_open: bool = false
var is_looted: bool = false
var is_cycling: bool = false 
var generated_weapon_name: String = ""


var loot_pivot: Node3D = null 
var visual_weapon_node: Node3D = null

func _ready() -> void:
	if label: label.text = "" 
	
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if is_open and not is_looted and loot_pivot:
		loot_pivot.rotation.y += delta * 1.5

	if player_in_range and Input.is_action_just_pressed("interact"):
		handle_interaction()

func handle_interaction():
	if is_cycling: return
		
	if not is_open:
		open_chest()
	elif is_open and not is_looted:
		take_loot()

func open_chest():
	music.play()
	if available_weapons.size() == 0:
		push_error("Aucune arme dans la liste du coffre !")
		return

	is_open = true
	is_cycling = true
	
	if label: label.text = "..."
	
	var anim_player = model.get_node("AnimationPlayer")
	if anim_player: anim_player.play("open")
	
	await get_tree().create_timer(opening_delay).timeout
	
	_process_mystery_box_sequence()

func _process_mystery_box_sequence():
	# CRÉATION DU PIVOT (CONTENEUR)
	loot_pivot = Node3D.new()
	add_child(loot_pivot)
	loot_pivot.global_position = spawn_point.global_position
	
	# ANIMATION DE MONTÉE (TWEEN)
	var rise_tween = create_tween()
	rise_tween.tween_property(loot_pivot, "position:y", spawn_point.position.y + 1.5, mystery_duration).from(spawn_point.position.y).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# BOUCLE DE DÉFILEMENT DES ARMES
	var elapsed_time = 0.0
	var current_delay = initial_switch_speed
	
	while elapsed_time < mystery_duration:
		var temp_weapon = available_weapons.pick_random()
		
		update_visual_model(temp_weapon)
		
		await get_tree().create_timer(current_delay).timeout
		elapsed_time += current_delay
		
		# Ralentissement progressif
		var progress = elapsed_time / mystery_duration
		current_delay = lerp(initial_switch_speed, final_switch_speed, pow(progress, 2))
		
	# FINALISATION
	generated_weapon_name = available_weapons.pick_random()
	update_visual_model(generated_weapon_name)
	
	# Mise à jour du label
	var display_name = generated_weapon_name.split("/")[-1].replace("_", " ") 

	if label:
		label.text = "Take : " + display_name
		
	is_cycling = false

func update_visual_model(weapon_name: String):
	# Suppression de l'ancien modèle
	if visual_weapon_node:
		visual_weapon_node.queue_free()
	
	var path = "res://Scenes/Weapons/%s.tscn" % weapon_name
	var scene = load(path)
	if scene:
		visual_weapon_node = scene.instantiate()
		loot_pivot.add_child(visual_weapon_node)
		
		visual_weapon_node.process_mode = Node.PROCESS_MODE_DISABLED
		
		# Position locale à 0, car c'est le pivot qui gère la hauteur globale
		visual_weapon_node.position = Vector3.ZERO
		visual_weapon_node.rotation = Vector3.ZERO

func take_loot():
	is_looted = true

	if "Shield" in generated_weapon_name:
		if player_in_range.has_method("equip_shield"):
			player_in_range.equip_shield(generated_weapon_name)
	else:
		# Sinon, on considère que c'est une arme classique
		if player_in_range.has_method("equip_weapon"):
			player_in_range.equip_weapon(generated_weapon_name)
	
	# On supprime tout le pivot (qui contient l'arme)
	if loot_pivot:
		loot_pivot.queue_free()
	
	if label: label.text = ""
	interaction_area.queue_free()
	light.queue_free()
	light2.queue_free()

# --- DETECTION JOUEUR ---
func _on_body_entered(body: Node3D):
	if body.is_in_group("Player"):
		body.call("show_interact")
		player_in_range = body
		
		if is_cycling:
			if label: label.text = "..."
		elif not is_open:
			if label: label.text = "Open"
		elif not is_looted and loot_pivot:
			var display_name = generated_weapon_name.split("/")[-1].replace("_", " ")
			if label: label.text = "Take : " + display_name

func _on_body_exited(body: Node3D):
	if body == player_in_range:
		body.call("hide_interact")
		player_in_range = null
		if label: label.text = ""
