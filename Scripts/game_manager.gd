extends Node3D 

@export var game_over_scene: PackedScene = preload("res://Scenes/UI/death_screen.tscn")
@export var main_scene: PackedScene = preload("res://Scenes/game.tscn")
@export var boost_scene: PackedScene = preload("res://Scenes/Map/boost.tscn")
@export var main_scene_node: Node3D

var is_initialized = false
var started_time = 0
var selected_character: String = "" 
var current_round: int = 1 

func initialize() -> void:
	if(!is_initialized):
		main_scene_node = $"/root/Game/Terrain"
		process_mode = Node.PROCESS_MODE_ALWAYS

func create_boost(position: Vector3):
	var boost = boost_scene.instantiate()
	boost.position = position
	if main_scene_node:
		main_scene_node.add_child(boost)
	else:
		# Fallback si main_scene_node n'est pas encore assigné
		get_tree().current_scene.add_child(boost)

func game_over() -> void:
	get_tree().paused = true
	var game_over_ui = game_over_scene.instantiate()
	if main_scene_node:
		main_scene_node.add_child(game_over_ui)
	else:
		get_tree().current_scene.add_child(game_over_ui)

func play() -> void:
	get_tree().change_scene_to_packed(main_scene)
	
func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func quit() -> void:
	get_tree().quit()
