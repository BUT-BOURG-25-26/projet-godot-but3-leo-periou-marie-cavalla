extends Node3D

@export var enemy_scene: PackedScene = preload("res://Scenes/enemy_follower.tscn")
@export var min_distance_from_player = 5
@export var max_distance_to_add = 5

@onready var spawn_timer = $SpawnTimer
var rng = RandomNumberGenerator.new()
var player:Node3D
var timer:Timer
var start_time = 0;
var difficulty_limit = 5;

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player")
	timer = get_child(0)
	start_time = Time.get_unix_time_from_system()

func _process(delta:float):
	timer.wait_time = get_difficulty_timer_time()
	set_timer_difficulty()

func _on_spawn_timer_timeout():
	
	var enemy = enemy_scene.instantiate()
	get_parent().add_child(enemy)
	var x = (min_distance_from_player + get_random_number(0,max_distance_to_add)) * get_positive_or_negative()
	var z = (min_distance_from_player + get_random_number(0,max_distance_to_add)) * get_positive_or_negative()
	enemy.global_position = player.global_position + Vector3(x, 0.0, z)

func get_random_number(start:int,end:int) -> int:
	return rng.randf_range(start, end)

func get_positive_or_negative() -> int:
	var array = [-1,1]
	var weights = PackedFloat32Array([1, 1])
	return array[rng.rand_weighted(weights)]
	
func get_difficulty_timer_time():
	if(Time.get_unix_time_from_system() - start_time > 30):
		return 1
	elif(Time.get_unix_time_from_system() - start_time > 20):
		return 2
	elif(Time.get_unix_time_from_system() - start_time > 10):
		return 3
	else:
		return 4

func set_timer_difficulty():
	game_manager.update_difficulty(difficulty_limit-get_difficulty_timer_time())
