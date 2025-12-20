extends Control

var selected_character : String = "knight"
var path_to_textures : String = "res://Assets/UI/"
var textures_format: String =  ".png"

var descriptions : Dictionary = {
	"mage" : "Skeletons are waking up from an ancient viking territory, and something tells me one of your spells might have been responsible for this...\nOh, well, it's an opportunity to test some more witchcraft !\n\n[Magic Comming Soon]",
	"knight" : "You've always been ready for the living dead's invasion.\nIt's now finally time for you to wear your armor and to test your knowledge of swordmanship.",
	"rogue" : "Looks like corpses are having a little walk. We'll see if they'll be fast enough to catch you !\nAnd, maybe these dead vikings have valuable things to steal ?",
	"barbarian" : "Enemies, Friends, weird skeletons appearing in your garden...\nAnything's a good thing to battle with ! ",
	"ranger" : "Such filthy creatures have started roaming on your lands.\nBut thank to your bow you won't have to touch these disgusting living deads to fight them !"
}

func start_game(selected_character: String):
	game_manager.selected_character = selected_character
	get_tree().change_scene_to_file("res://Scenes/game.tscn")

func show_details():
	get_node("Details").show()
	get_node("Selection").hide()
	var path:String = path_to_textures + selected_character + textures_format
	get_node("Details/Title").text = selected_character.capitalize()
	get_node("Details/Character").texture = load(path) as Texture2D
	get_node("Details/Description").text = descriptions[selected_character]

func _on_btn_mage_pressed() -> void:
	selected_character = "mage"
	show_details()

func _on_btn_knight_pressed() -> void:
	selected_character = "knight"
	show_details()

func _on_btn_rogue_pressed() -> void:
	selected_character = "rogue"
	show_details()

func _on_btn_barbarian_pressed() -> void:
	selected_character = "barbarian"
	show_details()

func _on_btn_ranger_pressed() -> void:
	selected_character = "ranger"
	show_details()

func _on_start_pressed() -> void:
	start_game(selected_character)

func _on_back_pressed() -> void:
	get_node("Details").hide()
	get_node("Selection").show()
