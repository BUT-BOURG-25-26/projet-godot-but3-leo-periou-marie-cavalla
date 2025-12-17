class_name TerrainGeneration
extends Node

# --- EXPORTS ---
@export_group("References")
@export var player: CharacterBody3D
@export var noise : FastNoiseLite

@export_group("Settings")
@export var size_depth : int = 60
@export var size_width : int = 60
@export var mesh_resolution : int = 2
@export var highest_point : float = 50.0
@export var noise_scale : float = 0.001

@export_group("Spawning Settings")
@export_range(0.0, 1.0) var structure_spawn_chance: float = 0.4
@export var structure_exclusion_radius: float = 15.0
@export var spawn_radius_protection: float = 5.0

@export_group("Flattening Settings")
@export var flat_radius: float = 16.0 # Doit être inférieur à blend_radius
@export var blend_radius: float = 25.0 # Rayon d'impact sur le terrain

@export_group("Performance")
@export var items_per_frame: int = 5

# --- VARIABLES ---
var terrain_texture: Texture2D
var medium_models : Array[PackedScene] = []
var small_models : Array[PackedScene] = []
var structure_scenes : Array[PackedScene] = []

var medium_mesh_count = 30
var small_mesh_count = 80

var map_loaded_chunks : Array[Vector2] = []
var map_offset_vector = Vector2(-568, 657)

var was_player_placed: bool = false
var last_player_chunk: Vector2 = Vector2(9999, 9999)

var mutex: Mutex = Mutex.new()

func _ready():
	randomize()
	if noise:
		noise.seed = randi()
		noise.frequency = noise_scale
	
	load_assets()

	var current_scene = get_tree().current_scene
	if current_scene.has_signal("player_spawned"):
		current_scene.connect("player_spawned", Callable(self, "_on_player_spawned"))

func _on_player_spawned(spawned_player):
	player = spawned_player
	var ground_y = get_noise_y(0, 0)
	player.global_position = Vector3(0, ground_y + 2.0, 0)

func _process(_delta: float) -> void:
	if not player: return
		
	var current_chunk_x = floor(player.global_position.x / size_width)
	var current_chunk_z = floor(player.global_position.z / size_depth)
	var current_chunk = Vector2(current_chunk_x, current_chunk_z)
	
	if current_chunk != last_player_chunk:
		last_player_chunk = current_chunk
		load_chunks_around_player(current_chunk_x, current_chunk_z)

func load_chunks_around_player(center_x: int, center_z: int):
	for x in range(center_x - 1, center_x + 2):
		for z in range(center_z - 1, center_z + 2):
			var chunk_coord = Vector2(x, z)
			
			mutex.lock()
			var already_loaded = map_loaded_chunks.has(chunk_coord)
			if not already_loaded:
				map_loaded_chunks.push_back(chunk_coord)
			mutex.unlock()
			
			if not already_loaded:
				WorkerThreadPool.add_task(Callable(self, "_thread_generate_chunk_data").bind(chunk_coord))

# ------------------------------------------------------------------------------
# FONCTION DETERMINISTE
# ------------------------------------------------------------------------------
func _get_structure_info_for_chunk(chunk_x_idx: int, chunk_z_idx: int) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(chunk_x_idx, chunk_z_idx)) + noise.seed
	
	# Vérification spawn chance
	if rng.randf() >= structure_spawn_chance:
		return {} # Pas de structure ici
	
	# Vérification Spawn Chunk (0,0)
	if abs(chunk_x_idx) == 0 and abs(chunk_z_idx) == 0:
		return {}

	if structure_scenes.is_empty():
		return {}

	# On recalcule la position exacte théorique
	var world_x_start = chunk_x_idx * size_width
	var world_z_start = chunk_z_idx * size_depth
	
	var s_x = rng.randf_range(world_x_start + 5, world_x_start + size_width - 5)
	var s_z = rng.randf_range(world_z_start + 5, world_z_start + size_depth - 5)
	var s_y = get_noise_y(s_x, s_z)
	
	var struct_pos = Vector3(s_x, s_y, s_z)
	var struct_idx = rng.randi() % structure_scenes.size()
	var rot_y = rng.randf() * TAU
	
	return {
		"exists": true,
		"pos": struct_pos,
		"idx": struct_idx,
		"rot": rot_y
	}

# ------------------------------------------------------------------------------
# THREAD
# ------------------------------------------------------------------------------
func _thread_generate_chunk_data(chunk_coord: Vector2):
	var chunk_world_x = chunk_coord.x * size_width
	var chunk_world_z = chunk_coord.y * size_depth
	
	# RECUPERER LES STRUCTURES VOISINES (3x3)
	var nearby_structures = []
	var my_structure_info = {} # Pour stocker celle de ce chunk spécifiquement
	
	for x in range(chunk_coord.x - 1, chunk_coord.x + 2):
		for z in range(chunk_coord.y - 1, chunk_coord.y + 2):
			var info = _get_structure_info_for_chunk(x, z)
			if info.has("exists"):
				nearby_structures.append(info.pos)
				# Si c'est le chunk actuel, on sauvegarde les infos complètes pour l'instanciation plus tard
				if x == chunk_coord.x and z == chunk_coord.y:
					my_structure_info = info

	# GENERATION DU TERRAIN
	var temp_mesh = PlaneMesh.new()
	temp_mesh.size = Vector2(size_width, size_depth)
	temp_mesh.subdivide_width = size_width * mesh_resolution
	temp_mesh.subdivide_depth = size_depth * mesh_resolution
	
	var arrays = temp_mesh.get_mesh_arrays()
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	
	for i in range(vertices.size()):
		var v = vertices[i]
		var gx = chunk_world_x + (size_width * 0.5) + v.x
		var gz = chunk_world_z + (size_depth * 0.5) + v.z
		
		var raw_y = get_noise_y(gx, gz)
		var final_y = raw_y
		
		# On vérifie l'influence de toutes les structures voisines
		for struct_pos in nearby_structures:
			var dist = Vector2(gx, gz).distance_to(Vector2(struct_pos.x, struct_pos.z))
			
			if dist < blend_radius:
				# Si on est dans le rayon d'influence, on applique l'aplatissement
				if dist < flat_radius:
					# Force le plat
					final_y = struct_pos.y
				else:
					# Interpolation douce
					var t = (dist - flat_radius) / (blend_radius - flat_radius)
					t = smoothstep(0.0, 1.0, t)
					var blended_y = lerp(struct_pos.y, raw_y, t)
					
					if abs(final_y - raw_y) < abs(blended_y - raw_y):
						final_y = blended_y
					else:
						final_y = blended_y

		vertices[i].y = final_y
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	
	var surface_tool = SurfaceTool.new()
	surface_tool.create_from_arrays(arrays)
	surface_tool.generate_normals()
	var final_mesh_arrays = surface_tool.commit_to_arrays()

	# NATURE
	var nature_data = []

	_thread_calc_nature("small", small_mesh_count, chunk_world_x, chunk_world_z, nearby_structures, nature_data)
	_thread_calc_nature("medium", medium_mesh_count, chunk_world_x, chunk_world_z, nearby_structures, nature_data)

	var chunk_data = {
		"coord": chunk_coord,
		"world_pos": Vector3(chunk_world_x + size_width * 0.5, 0, chunk_world_z + size_depth * 0.5),
		"mesh_arrays": final_mesh_arrays,
		"structure_info": my_structure_info, # Contient {pos, idx, rot} ou vide
		"nature_data": nature_data
	}
	
	call_deferred("_finalize_chunk_generation", chunk_data)

func _thread_calc_nature(type: String, count: int, cx: float, cz: float, avoid_structures: Array, result_array: Array):
	for i in range(count):
		var x = randf_range(cx, cx + size_width)
		var z = randf_range(cz, cz + size_depth)
		
		# Protection Spawn (Zone carrée autour de 0,0)
		if x > -spawn_radius_protection and x < spawn_radius_protection and z > -spawn_radius_protection and z < spawn_radius_protection:
			continue

		var raw_y = get_noise_y(x, z)
		var final_y = raw_y
		var current_pos = Vector3(x, raw_y, z)
		
		var skip = false
		
		# Vérification contre toutes les structures voisines
		for s_pos in avoid_structures:
			var dist = current_pos.distance_to(s_pos)
			
			if dist < structure_exclusion_radius:
				skip = true
				break
	
			if dist < blend_radius:
				if dist < flat_radius:
					final_y = s_pos.y
				else:
					var t = (dist - flat_radius) / (blend_radius - flat_radius)
					t = smoothstep(0.0, 1.0, t)
					final_y = lerp(s_pos.y, raw_y, t)
		
		if skip: continue
		
		current_pos.y = final_y
		
		var scale_val = Vector3.ONE
		if type == "medium":
			var s = randf_range(4.0, 6.0)
			scale_val = Vector3(s, s, s)
			
		result_array.append({"type": type, "pos": current_pos, "rot_y": randf() * TAU, "scale": scale_val})

# ------------------------------------------------------------------------------
# MAIN THREAD
# ------------------------------------------------------------------------------
func _finalize_chunk_generation(data: Dictionary):
	var new_mesh = ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data.mesh_arrays)
	
	var material := StandardMaterial3D.new()
	if terrain_texture: material.albedo_texture = terrain_texture
	new_mesh.surface_set_material(0, material)
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = new_mesh
	mesh_instance.position = data.world_pos
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh_instance.add_to_group("NavSource")
	add_child(mesh_instance)
	
	await get_tree().process_frame
	mesh_instance.create_trimesh_collision()
	await get_tree().process_frame
	
	# Instanciation de la structure
	var s_info = data.structure_info
	if s_info.has("exists") and s_info.exists:
		var scene = structure_scenes[s_info.idx]
		var instance = scene.instantiate()
		
		instance.position = s_info.pos + Vector3(0, 0.05, 0)
		instance.scale = Vector3(1.2, 1.2, 1.2)
		instance.rotation.y = s_info.rot
		add_child(instance)
		
		if instance.has_node("Chest") and randf() < 0.5:
			instance.get_node("Chest").queue_free()
			
		if instance.get_child_count() > 0:
			var child = instance.get_child(0)
			if child is MeshInstance3D: child.create_trimesh_collision()

	# Nature
	var items_spawned = 0
	for item in data.nature_data:
		var scene_array = small_models if item.type == "small" else medium_models
		if scene_array.is_empty(): continue
		
		var instance = scene_array.pick_random().instantiate()
		instance.position = item.pos
		instance.rotation.y = item.rot_y
		instance.scale = item.scale
		add_child(instance)
		
		if item.type == "medium" and instance.get_child_count() > 0:
			var child = instance.get_child(0)
			if child is MeshInstance3D:
				child.add_to_group("Structure")
				child.create_trimesh_collision()
		
		items_spawned += 1
		if items_spawned >= items_per_frame:
			items_spawned = 0
			await get_tree().process_frame

# ------------------------------------------------------------------------------
# UTILITAIRES
# ------------------------------------------------------------------------------
func load_assets():
	terrain_texture = load("res://Assets/Textures/Green.png")
	
	for i in range(1, 23):
		var path = "res://Assets/Forest/Bush" + str(i) + ".gltf"
		if ResourceLoader.exists(path): small_models.push_back(load(path))
	
	for i in range(1, 21):
		var path = "res://Assets/Forest/Tree" + str(i) + ".gltf"
		if ResourceLoader.exists(path): medium_models.push_back(load(path))
	
	var dir_path = "res://Scenes/Structure/"
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and (file_name.ends_with(".tscn") or file_name.ends_with(".scn")):
				structure_scenes.push_back(load(dir_path + "/" + file_name))
			file_name = dir.get_next()

func get_noise_y(global_x: float, global_z: float) -> float:
	if not noise: return 0.0
	var value = noise.get_noise_2d(global_x + map_offset_vector.x, global_z + map_offset_vector.y)
	return value * highest_point
