extends Sprite3D

@export var health_bar: ProgressBar
@export var money_counter: Label
@export var wave_counter: Label
@export var next_wave: Label
@export var boost_container: HBoxContainer

@export var attack_icon_png: Texture2D
@export var speed_icon_png: Texture2D

var boost_icons: Dictionary = {}

func take_damage(damage: float):
	health_bar.value -= damage

func heal(bonus: float):
	health_bar.value += bonus

func set_health_bar(hp):
	health_bar.max_value = hp
	health_bar.value = hp

func set_money_counter(number):
	money_counter.text = str(number)
	
func set_wave_counter(number):
	wave_counter.text = "Wave : " + str(number)
	
func set_next_wave(number):
	if (number == 0):
		next_wave.hide()
	else:
		next_wave.show()
		next_wave.text = "NEXT WAVE : " + str(number) + "s"

# --- GESTION DES BOOSTS UI ---
func update_boosts_display(active_boosts: Dictionary):
	# Nettoyage
	var keys_to_remove = []
	for type in boost_icons:
		if not active_boosts.has(type):
			boost_icons[type].queue_free()
			keys_to_remove.append(type)
	
	for k in keys_to_remove:
		boost_icons.erase(k)

	# Mise à jour
	for type in active_boosts:
		var time_left = active_boosts[type]["time"]
		
		# Création si n'existe pas
		if not boost_icons.has(type):
			var icon = create_boost_icon(type)
			boost_container.add_child(icon)
			boost_icons[type] = icon
		
		var icon_node = boost_icons[type]
		
		# Gestion du clignotement
		if time_left < 3.0:
			icon_node.modulate.a = 0.5 + 0.5 * sin(time_left * 15.0) 
		else:
			icon_node.modulate.a = 1.0

func create_boost_icon(type: String) -> Control:
	var container = VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Création de l'image
	var tex_rect = TextureRect.new()
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.custom_minimum_size = Vector2(80, 80)
	
	match type:
		"Attack": 
			tex_rect.texture = attack_icon_png
		"Speed": 
			tex_rect.texture = speed_icon_png
	container.add_child(tex_rect)
	
	return container
