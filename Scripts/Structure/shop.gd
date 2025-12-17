extends Node3D

# Liste des chemins d'armes à vendre
@export var weapons_to_sell: Array[String] = [
	"Melee/dagger",
	"Melee/sword_1h",
	"Melee/axe_1h",
	"Ranged/crossbow_1h",
	"Shield/shield_badge",
	"Shield/shield_round",
	"Shield/shield_square",
	"Melee/sword_2h",
	"Melee/axe_2h",
	"Ranged/crossbow_2h",
	"Melee/legendary_sword",
	"Ranged/bow",
	"Shield/shield_spikes"
]

@onready var interaction_area = $InteractionArea
@onready var label = $Label3D

@export var shop_ui_scene: PackedScene
@export var shopkeeper_animationplayer: AnimationPlayer

var player_in_range: Node3D = null
var shop_inventory_data: Array = []
var shop_ui_instance: Control = null

func _ready():
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	
	shopkeeper_animationplayer.play("idle")
	# Pré-chargement des données des armes
	_load_weapons_data()

	if shop_ui_scene:
		shop_ui_instance = shop_ui_scene.instantiate()
		get_tree().current_scene.add_child.call_deferred(shop_ui_instance)

func _load_weapons_data():
	shop_inventory_data.clear()
	for weapon_path in weapons_to_sell:
		var full_path = "res://Scenes/Weapons/%s.tscn" % weapon_path
		if ResourceLoader.exists(full_path):
			var scene = load(full_path)
			var temp_instance = scene.instantiate()
			
			var cost = 0
			if "cost" in temp_instance:
				cost = temp_instance.cost
			
			shop_inventory_data.append({
				"name": weapon_path.split("/")[-1],
				"full_path": weapon_path,
				"cost": cost,
				"sold": false
			})
			
			temp_instance.free()
		else:
			push_error("Arme introuvable : " + full_path)

func _process(_delta):
	if player_in_range and Input.is_action_just_pressed("interact"):
		open_shop_ui()

func open_shop_ui():
	if shop_ui_instance and player_in_range:
		shop_ui_instance.open_shop(player_in_range, shop_inventory_data)

func _on_body_entered(body):
	if body.is_in_group("Player"):
		player_in_range = body
		if label: label.text = "Shopkeeper (E)"

func _on_body_exited(body):
	if body == player_in_range:
		player_in_range = null
		if label: label.text = ""
		if shop_ui_instance and shop_ui_instance.visible:
			shop_ui_instance.close_shop()


func _on_welcome_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		shopkeeper_animationplayer.play("wave")


func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	shopkeeper_animationplayer.play("idle")
