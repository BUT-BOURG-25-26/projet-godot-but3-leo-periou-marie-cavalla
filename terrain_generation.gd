class_name TerrainGeneration
extends Node

var mesh: MeshInstance3D
var size_depth : int = 100
var size_width : int = 100
var mesh_resolution : int = 2 #Une valeur haute coûtera plus de temps à générer

var highest_point = 50

@export var noise : FastNoiseLite

func _ready():
	generate()
	
func generate():
	#1 - On crée un terain plat que l'on divise plein de fois
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(size_width,size_depth)
	plane_mesh.subdivide_depth = size_depth * mesh_resolution
	plane_mesh.subdivide_width = size_width * mesh_resolution
	plane_mesh.material =  preload("res://Assets/Textures/Green.png")
	
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

func get_noise_y(x,z) -> float:
	var value = noise.get_noise_2d(x,z)
	return value * highest_point
