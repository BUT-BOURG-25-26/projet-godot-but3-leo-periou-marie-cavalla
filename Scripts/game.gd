extends Node3D

signal player_spawned(player)

func _ready():
	game_manager.initialize()
	var name = game_manager.selected_character
	if name == "":
		push_error("No character selected!")
		return

	var path = "res://Scenes/Player/%s.tscn" % name
	var scene = load(path)
	if scene == null:
		push_error("Player scene not found: " + path)
		return

	var player = scene.instantiate()
	add_child(player)
	emit_signal("player_spawned", player)
