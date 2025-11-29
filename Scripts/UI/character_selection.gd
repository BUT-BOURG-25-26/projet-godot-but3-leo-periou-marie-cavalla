extends Control

var selected_character : String = "knight"
var path_to_textures : String = "res://Assets/UI/"
var textures_format: String =  ".png"

func start_game(selected_character: String):
	game_manager.selected_character = selected_character
	get_tree().change_scene_to_file("res://Scenes/game.tscn")

func show_details():
	get_node("Details").show()
	get_node("Selection").hide()
	var path:String = path_to_textures + selected_character + textures_format
	get_node("Details/Title").text = selected_character.capitalize()
	get_node("Details/Character").texture = load(path)

func _on_btn_mage_pressed() -> void:
	show_details()
	selected_character = "mage"

func _on_btn_knight_pressed() -> void:
	show_details()
	selected_character = "knight"

func _on_btn_rogue_pressed() -> void:
	show_details()
	selected_character = "rogue"

func _on_btn_barbarian_pressed() -> void:
	show_details()
	selected_character = "barbarian"

func _on_btn_ranger_pressed() -> void:
	show_details()
	selected_character = "ranger"

func _on_start_pressed() -> void:
	start_game(selected_character)

func _on_back_pressed() -> void:
	get_node("Details").hide()
	get_node("Selection").show()
