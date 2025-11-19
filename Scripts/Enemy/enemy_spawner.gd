extends Node3D

# -- Enemy import  --
var skeleton_minion: PackedScene = preload("res://Scenes/Enemy/skeleton_minion.tscn")
var skeleton_mage: PackedScene = preload("res://Scenes/Enemy/skeleton_mage.tscn")
var skeleton_rogue: PackedScene = preload("res://Scenes/Enemy/skeleton_rogue.tscn")
var skeleton_warrior: PackedScene = preload("res://Scenes/Enemy/skeleton_warrior.tscn")

var enemy_list = [
	skeleton_minion,
	skeleton_mage,
	skeleton_rogue,
	skeleton_warrior,
]

# -- Export variables --
@export var min_distance_from_player = 5
@export var max_distance_to_add = 10

# -- Variables --
@onready var spawn_timer = $SpawnTimer
var rng = RandomNumberGenerator.new()
var player:Node3D
var timer:Timer
var start_time = 0;
var difficulty_limit = 5;

func _ready() -> void:
	timer = get_child(0)
	start_time = Time.get_unix_time_from_system()
	get_tree().current_scene.connect("player_spawned", Callable(self, "_on_player_spawned"))

# Quand le joueur spawn
func _on_player_spawned(spawned_player):
	player = spawned_player

func _process(delta:float):
	timer.wait_time = get_difficulty_timer_time()
	set_timer_difficulty()

func _on_spawn_timer_timeout():
	
	var enemy = enemy_list.pick_random().instantiate()
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
