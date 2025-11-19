class_name TerrainGeneration
extends Node

@export var player: CharacterBody3D
@export var noise : FastNoiseLite

var mesh: MeshInstance3D
var size_depth : int = 60
var size_width : int = 60
var mesh_resolution : int = 2 #Une valeur haute coûtera plus de temps à générer

var medium_models : Array[PackedScene]
var small_models : Array[PackedScene]
var terrain_texture: Texture2D
var medium_mesh_count = 30
var small_mesh_count = 30

var map_loaded_chunks : Array[Vector2]
var map_x_offset = -568
var map_y_offset = 657

var highest_point = 50

func _ready():
	noise.offset = Vector3(map_x_offset,map_y_offset,0)
	player = get_tree().get_nodes_in_group("Player")[0]
	load_forest_models()
	load_radius_chunks()
	
func _process(_delta:float) -> void:
	load_chunk_if_needed()
	
func load_radius_chunks():
	var temp_chunk_x = floor(player.global_position.x / size_width)
	var temp_chunk_z = floor(player.global_position.z / size_depth)

	var radius_around_player = [
		Vector2(temp_chunk_x, temp_chunk_z),
		Vector2(temp_chunk_x - 1, temp_chunk_z),
		Vector2(temp_chunk_x, temp_chunk_z - 1),
		Vector2(temp_chunk_x - 1, temp_chunk_z - 1)
	]

	for chunk in radius_around_player:
			var chunk_x = chunk.x * size_width
			var chunk_z = chunk.y * size_depth
			map_loaded_chunks.append(chunk)
			generate(chunk_x, chunk_z)


func load_chunk_if_needed():
	if(!player):
		return
	var player_x =  player.global_position.x
	var player_z =  player.global_position.z
	var temp_chunk_x:int = floor(player.global_position.x / size_width)
	var temp_chunk_z:int = floor(player.global_position.z / size_depth)
	var chunk_vector = Vector2(temp_chunk_x,temp_chunk_z)
	var radius_around_player = [
		Vector2(temp_chunk_x, temp_chunk_z),
		Vector2(temp_chunk_x + 1, temp_chunk_z),
		Vector2(temp_chunk_x, temp_chunk_z + 1),
		Vector2(temp_chunk_x + 1, temp_chunk_z + 1),
		Vector2(temp_chunk_x - 1, temp_chunk_z),
		Vector2(temp_chunk_x, temp_chunk_z - 1),
		Vector2(temp_chunk_x - 1, temp_chunk_z - 1),
		Vector2(temp_chunk_x + 1, temp_chunk_z - 1),
		Vector2(temp_chunk_x - 1, temp_chunk_z + 1)
	]
	for chunk in radius_around_player:
		if(!map_loaded_chunks.has(chunk)):
			map_loaded_chunks.push_back(chunk)
			var chunk_x = chunk.x * size_width
			var chunk_z = chunk.y * size_depth
			generate(chunk_x,chunk_z)

func generate(chunk_x:float, chunk_z:float):
	#1 - On crée un terain plat que l'on divise plein de fois
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(size_width,size_depth)
	plane_mesh.subdivide_depth = size_depth * mesh_resolution
	plane_mesh.subdivide_width = size_width * mesh_resolution
	var texture: Texture2D = terrain_texture
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	plane_mesh.material = material
	
	var surface = SurfaceTool.new() #L'outil permettant de créer une mesh à partir de nos objets
	var data = MeshDataTool.new() #L'outil permettant d'accéder aux vertices
	surface.create_from(plane_mesh,0)
	
	var array_plane = surface.commit()
	data.create_from_surface(array_plane,0)
	
	#2 - On vient traiter chaque vertex du terrain plat
	for i in range(data.get_vertex_count()):
		var vertex = data.get_vertex(i)
		var y = get_noise_y(vertex.x + chunk_x,vertex.z + chunk_z)
		vertex.y = y
		data.set_vertex(i,vertex)
		
	
	#3 - On applique des directions et des normes sur nos vertices
	array_plane.clear_surfaces()
	data.commit_to_surface(array_plane)
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.create_from(array_plane,0)
	surface.generate_normals()
	
	#4 - On vient créer la mesh à partir de toutes nos données
	mesh = MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.position = Vector3(chunk_x + size_width/2, 0, chunk_z + size_depth/2)
	mesh.create_trimesh_collision() #La collision de notre terrain
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh.add_to_group("NavSource")
	add_child(mesh)
	
	#5 - On ajoute les structures sur le terrain
	generate_structures(chunk_x,chunk_z)
	

func generate_structures(chunk_x:float, chunk_z:float):
	generate_from_array("small",small_mesh_count,small_models, chunk_x, chunk_z)
	generate_from_array("medium",medium_mesh_count,medium_models, chunk_x, chunk_z)

func generate_from_array(type:String, models_count:int, models_array:Array[PackedScene], chunk_x:float, chunk_z:float) -> void:
	randomize()
	for i in range(models_count):
		var min_x = chunk_x 
		var max_x = chunk_x + size_width 
		var min_z = chunk_z
		var max_z = chunk_z + size_depth 
		var x = randf_range(min_x, max_x)
		var z = randf_range(min_z, max_z)
		var y = get_noise_y(x-size_width/2, z-size_width/2)
		var model_to_instance = models_array.pick_random()
		var instance = model_to_instance.instantiate()
		instance.position = Vector3(x,y,z)
		instance.rotation.y = randf() * (PI*2)
		if(type == "medium"):
			instance.scale = Vector3.ONE * randf_range(0.8, 1.2)
			instance.scale.y = instance.scale.y * 2.5
			instance.scale.x = instance.scale.x * 1.5
		add_child(instance)
		var mesh_instance = instance.get_child(0)
		mesh_instance.add_to_group("Structure")
		if(type != "small"):
			mesh_instance.create_trimesh_collision()


func load_forest_models():
	terrain_texture = preload("res://Assets/Textures/Green.png")
	var bushes_count = 22
	var trees_count = 20
	
	for i in range(1,bushes_count+1):
		small_models.push_back(load("res://Assets/Forest/Bush" + str(i) + ".gltf"))
	
	for i in range(1,trees_count+1):
		medium_models.push_back(load("res://Assets/Forest/Tree" + str(i) + ".gltf"))


func get_noise_y(x,z) -> float:
	var value = noise.get_noise_2d(x+map_x_offset,z+map_x_offset)
	return value * highest_point
