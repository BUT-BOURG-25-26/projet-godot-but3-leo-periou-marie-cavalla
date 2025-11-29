extends Node3D 

@export var game_over_scene: PackedScene = preload("res://Scenes/UI/death_screen.tscn")
@export var main_scene: PackedScene = preload("res://Scenes/game.tscn")
@export var boost_scene: PackedScene = preload("res://Scenes/Map/boost.tscn")


@export var difficulty_label:Control
@export var main_scene_node:Node3D
var is_initialized = false
var started_time = 0
var selected_character: String = ""

func initialize() -> void:
	if(!is_initialized):
		main_scene_node = $"/root/Game/Terrain"
		process_mode = Node.PROCESS_MODE_ALWAYS

func update_difficulty(value:int):
	#TODO difficulty_label.text = str(value)
	pass
	
func create_boost(position:Vector3):
	var boost = boost_scene.instantiate()
	boost.position = position
	main_scene_node.add_child(boost)

func game_over() -> void:
	get_tree().paused = true;
	var game_over_ui = game_over_scene.instantiate()
	main_scene_node.add_child(game_over_ui)

func play() -> void:
	get_tree().change_scene_to_packed(main_scene)
	
func restart() -> void:
	get_tree().paused = false;
	get_tree().reload_current_scene()

func quit() -> void:
	get_tree().quit()
