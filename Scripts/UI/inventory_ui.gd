extends Control

# Références
@onready var right_label = $PanelContainer/VBoxContainer/RightHand/RightHandLabel
@onready var right_btn = $PanelContainer/VBoxContainer/RightHand/UnequipRight

@onready var left_label = $PanelContainer/VBoxContainer/LeftHand/LeftHandLabel
@onready var left_btn = $PanelContainer/VBoxContainer/LeftHand/UnequipLeft

@onready var close_btn = $PanelContainer/CloseButton

@export var player_ref: CharacterBody3D

func _ready():
	hide()
	
	# Connexion des croix
	right_btn.pressed.connect(_on_remove_weapon)
	left_btn.pressed.connect(_on_remove_shield)
	close_btn.pressed.connect(_close_inventory)

func _input(event):
	# Ouvrir / Fermer
	if Input.is_action_just_pressed("pause") and visible:
		_close_inventory()
	
	if event.is_action_pressed("toggle_inventory"):
		visible = !visible
		
		if visible:
			update_ui()
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			_close_inventory()

func set_player(player):
	player_ref = player

func update_ui():
	if not player_ref: return
	
	# --- Main Droite ---
	if player_ref.current_weapon:
		var w_name = player_ref.current_weapon.name.replace("enemy_", "").replace("_", " ")
		right_label.text = "Right Hand : " + w_name
		right_btn.disabled = false
	else:
		right_label.text = "Right Hand : Vide"
		right_btn.disabled = true

	# --- Main Gauche ---
	if player_ref.current_shield:
		var s_name = player_ref.current_shield.name.replace("enemy_", "").replace("_", " ")
		left_label.text = "Left Hand : " + s_name
		left_btn.disabled = false
	else:
		left_label.text = "Left Hand : Vide"
		left_btn.disabled = true

# --- ACTIONS ---

func _on_remove_weapon():
	if player_ref and player_ref.has_method("unequip_item"):
		player_ref.unequip_item("Right")
		update_ui()

func _on_remove_shield():
	if player_ref and player_ref.has_method("unequip_item"):
		player_ref.unequip_item("Left")
		update_ui()

func _close_inventory():
	hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
