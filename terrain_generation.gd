class_name TerrainGeneration
extends Node

var mesh: MeshInstance3D
var size_depth : int = 100
var size_width : int = 100
var mesh_resolution : int = 2 #Une valeur haute coûtera plus de temps à générer

var medium_models : Array[PackedScene]
var small_models : Array[PackedScene]
var terrain_texture: Texture2D
var medium_mesh_count = 500
var small_mesh_count = 400

var distance_before_chunk_loads = 50
var map_x_loaded : Array
var map_y_loaded : Array

var highest_point = 50

var player_x = 0;
var player_z = 0;

@export var noise : FastNoiseLite

func _ready():
	load_forest_models()
	generate()
	
func generate():
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
		var y = get_noise_y(vertex.x,vertex.z)
		vertex.y = y
		data.set_vertex(i,vertex)
		data.set
		
	
	#3 - On applique des directions et des normes sur nos vertices
	array_plane.clear_surfaces()
	data.commit_to_surface(array_plane)
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.create_from(array_plane,0)
	surface.generate_normals()
	
	#4 - On vient créer la mesh à partir de toutes nos données
	mesh = MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.create_trimesh_collision() #La collision de notre terrain
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh.add_to_group("NavSource")
	add_child(mesh)
	
	#5 - On ajoute les structures sur le terrain
	generate_structures()
	

func generate_structures():
	generate_from_array(small_mesh_count,small_models)
	generate_from_array(medium_mesh_count,medium_models)

func generate_from_array(modelsCount:int, modelsArray:Array[PackedScene]) -> void:
	randomize()
	for i in range(modelsCount):
		var x = randf_range(-size_width/2, size_width/2)
		var z = randf_range(-size_depth/2, size_depth/2)
		var y = get_noise_y(x, z)
		var model_to_instance = modelsArray.pick_random()
		var instance = model_to_instance.instantiate()
		instance.position = Vector3(x,y,z)
		instance.rotation.y = randf() * (PI*2)
		instance.scale = Vector3.ONE * randf_range(0.8, 1.2)
		add_child(instance)
		var mesh_instance = instance.get_child(0)
		mesh_instance.add_to_group("structure")
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
	var value = noise.get_noise_2d(x,z)
	return value * highest_point
