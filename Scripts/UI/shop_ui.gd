extends Control

@onready var items_container = $Panel/VBoxContainer/ScrollContainer/ItemsContainer
@onready var close_button = $Panel/VBoxContainer/CloseButton

var player_ref: CharacterBody3D = null

func _ready():
	hide()
	close_button.pressed.connect(close_shop)
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(_event):
	# Fermer
	if Input.is_action_just_pressed("pause") and visible:
		visible = !visible
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func open_shop(player: CharacterBody3D, available_weapons_data: Array):
	player_ref = player
	
	for child in items_container.get_children():
		child.queue_free()
	
	for weapon_data in available_weapons_data:
		var btn = Button.new()
		btn.theme = null
		btn.custom_minimum_size.y = 150
		btn.size_flags_horizontal = SIZE_EXPAND_FILL
		btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		var texture_rect = TextureRect.new()
		texture_rect.scale = Vector2(0.5,0.5)
		
		# --- VERIFICATION DU STOCK ---
		if weapon_data["sold"] == true:
			btn.text = "(Sold out)"
			btn.disabled = true
		else:
			texture_rect.texture = load("res://Assets/UI/Weapons/"+weapon_data["name"]+".png")
			btn.add_child(texture_rect)
			btn.text = "%d Gold" % [weapon_data["cost"]]
			if player.money < weapon_data["cost"]:
				btn.disabled = true
		
		btn.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		btn.pressed.connect(_on_buy_item.bind(weapon_data, btn))
		items_container.add_child(btn)
	
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_buy_item(weapon_data: Dictionary, button_ref: Button):
	if player_ref.money >= weapon_data["cost"]:
		player_ref.call("set_money", -weapon_data["cost"])
		
		weapon_data["sold"] = true
		
		# --- EQUIPEMENT ---
		if "Shield" in weapon_data["full_path"]:
			if player_ref.has_method("equip_shield"):
				player_ref.equip_shield(weapon_data["full_path"])
		else:
			if player_ref.has_method("equip_weapon"):
				player_ref.equip_weapon(weapon_data["full_path"])
		
		# UI Update
		button_ref.remove_child(button_ref.get_child(0))
		button_ref.disabled = true
		button_ref.text = weapon_data["name"].capitalize().replace("_", " ") + " - (Bought)"
		
		refresh_buttons_state()

func refresh_buttons_state():
	for btn in items_container.get_children():
		# On ignore ceux déjà vendus/achetés
		if btn.disabled and (btn.text.contains("(Sold out)") or btn.text.contains("(Bought)")):
			continue
		
		var text_parts = btn.text.split(" - ")
		if text_parts.size() > 1:
			var cost_string = text_parts[1].replace(" Gold", "")
			var cost = int(cost_string)
			
			if player_ref.money < cost:
				btn.disabled = true
			else:
				btn.disabled = false

func close_shop():
	hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
