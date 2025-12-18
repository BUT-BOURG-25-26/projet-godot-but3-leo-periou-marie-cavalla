extends Node3D

# -- Enemy import  --
var skeleton_minion: PackedScene = preload("res://Scenes/Enemy/skeleton_minion.tscn")
var skeleton_rogue: PackedScene = preload("res://Scenes/Enemy/skeleton_rogue.tscn")
var skeleton_warrior: PackedScene = preload("res://Scenes/Enemy/skeleton_warrior.tscn")

var enemy_list = [
	skeleton_minion,
	skeleton_rogue,
	skeleton_warrior,
]

# -- Export variables --
@export var min_distance_from_player = 10
@export var max_distance_to_add = 15
@export var max_enemies_on_map: int = 15
@export var round_cooldown_time: int = 20

# -- Variables de gestion de Manche --
var current_round: int = 1
var enemies_to_kill_total: int = 0
var enemies_killed_current: int = 0
var enemies_active_count: int = 0
var player_ui: Sprite3D
var is_round_in_progress: bool = false
var player: Node3D
var rng = RandomNumberGenerator.new()

@onready var spawn_timer = $SpawnTimer

func _ready() -> void:
	get_tree().current_scene.connect("player_spawned", Callable(self, "_on_player_spawned"))
	spawn_timer.wait_time = 1.0
	spawn_timer.timeout.connect(_on_spawn_try)
	rng.randomize() 
	
	await get_tree().create_timer(1.0).timeout
	start_round()

func _on_player_spawned(spawned_player):
	player = spawned_player
	player_ui = player.get_node("PlayerUi")

func start_round():
	is_round_in_progress = true
	enemies_killed_current = 0
	enemies_to_kill_total = 5 + (current_round - 1)
	player_ui.call("set_wave_counter", current_round)
	spawn_timer.start()

func _process(_delta: float) -> void:
	if is_round_in_progress and enemies_killed_current >= enemies_to_kill_total:
		end_round()

func _on_spawn_try():
	if not is_round_in_progress or not player: return
	if enemies_active_count >= max_enemies_on_map: return
	
	var enemies_left_to_spawn = enemies_to_kill_total - enemies_killed_current - enemies_active_count
	if enemies_left_to_spawn > 0:
		spawn_enemy()

func spawn_enemy():
	# Position valide au sol
	var valid_ground_pos = find_valid_spawn_pos()
	
	if valid_ground_pos == Vector3.INF:
		return

	var enemy_scene = enemy_list.pick_random()
	var enemy = enemy_scene.instantiate()
	get_parent().add_child(enemy)
	
	# Positionne l'ennemi sous la carte
	var spawn_depth = 3.0
	enemy.global_position = valid_ground_pos - Vector3(0, spawn_depth, 0)
	
	if enemy.has_method("init_spawn_sequence"):
		enemy.init_spawn_sequence(valid_ground_pos.y)
	
	enemy.connect("enemy_died", Callable(self, "_on_enemy_killed"))
	enemy.connect("enemy_despawned", Callable(self, "_on_enemy_despawned"))
	
	enemies_active_count += 1

func find_valid_spawn_pos() -> Vector3:
	var space_state = get_world_3d().direct_space_state
	var max_attempts = 10
	
	for i in range(max_attempts):
		# Coordonnées X/Z
		var x = (min_distance_from_player + rng.randf_range(0, max_distance_to_add)) * get_positive_or_negative()
		var z = (min_distance_from_player + rng.randf_range(0, max_distance_to_add)) * get_positive_or_negative()
		var target_pos = player.global_position + Vector3(x, 0, z)
		
		# Raycast
		var from_pos = Vector3(target_pos.x, 50.0, target_pos.z)
		var to_pos = Vector3(target_pos.x, -50.0, target_pos.z)
		
		var query = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
		
		var result = space_state.intersect_ray(query)
		
		if result:
			var collider = result.collider
			if collider.is_in_group("Terrain"):
				return result.position
	
	return Vector3.INF # Échec

func _on_enemy_killed(_enemy_ref):
	enemies_killed_current += 1
	enemies_active_count -= 1
	
func _on_enemy_despawned(_enemy_ref):
	enemies_active_count -= 1
	
func end_round():
	is_round_in_progress = false
	spawn_timer.stop()
	var time_left = round_cooldown_time
	while time_left > 0:
		if player_ui: player_ui.call("set_next_wave", time_left)
		await get_tree().create_timer(1.0).timeout
		time_left -= 1
	if player_ui: player_ui.call("set_next_wave", 0)
	current_round += 1
	start_round()

# -- Utilitaires --
func get_random_number(start:int, end:int) -> float:
	return rng.randf_range(start, end)

func get_positive_or_negative() -> int:
	var array = [-1, 1]
	return array.pick_random()
