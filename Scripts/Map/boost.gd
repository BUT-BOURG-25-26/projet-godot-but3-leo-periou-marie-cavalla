extends Node3D

@onready var timer = $BoostTimer
@onready var boost_mesh:MeshInstance3D = $BoostMesh
var types_weighted = ["Health","Health","Health","Attack","Speed"]
var type:String = ""
var player:Player = null

func _ready():
	self.type = types_weighted.pick_random()
	var color:Color = Color("52a177da")
	match type :
		"Health" :
			color = Color("52a177da")
		"Attack" : 
			color = Color("d56865da")
		"Speed" :
			color = Color("a98a3fda")
	boost_mesh.mesh.material.albedo_color = color

func _on_boost_body_entered(body: Node3D) -> void:
	if(body.is_in_group("Player")):
		player = body as Player
		player.add_boost(type)
		timer.start()
		hide()

func _on_boost_timer_timeout() -> void:
	if(player):
		player.remove_boost(type)
	queue_free()
