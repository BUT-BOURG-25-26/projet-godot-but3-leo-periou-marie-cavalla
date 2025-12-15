extends Sprite3D

@export var health_bar: ProgressBar
@export var money_counter: Label
@export var wave_counter: Label
@export var next_wave: Label

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
		next_wave.text = "PROCHAINE VAGUE : " + str(number) + "s"
