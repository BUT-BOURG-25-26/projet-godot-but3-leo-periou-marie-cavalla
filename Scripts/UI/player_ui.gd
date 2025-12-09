extends Sprite3D

@export var health_bar: ProgressBar
@export var kill_counter: Label

func take_damage(damage: float):
	health_bar.value -= damage

func heal(bonus: float):
	health_bar.value += bonus

func set_health_bar(hp):
	health_bar.max_value = hp
	health_bar.value = hp

func set_kill_counter(number):
	kill_counter.text = "Kills : " + str(number)
