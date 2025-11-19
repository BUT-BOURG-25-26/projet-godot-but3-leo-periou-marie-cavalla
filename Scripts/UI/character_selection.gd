extends Control

func start_game(selected_character: String):
	game_manager.selected_character = selected_character
	get_tree().change_scene_to_file("res://Scenes/game.tscn")


func _on_btn_mage_pressed() -> void:
	start_game("mage")

func _on_btn_knight_pressed() -> void:
	start_game("knight")

func _on_btn_rogue_pressed() -> void:
	start_game("rogue")

func _on_btn_barbarian_pressed() -> void:
	start_game("barbarian")

func _on_btn_ranger_pressed() -> void:
	start_game("ranger")
