extends Sprite3D

@export var health_bar: ProgressBar

func take_damage(damage: float):
	health_bar.value -= damage

func set_health_bar(hp):
	health_bar.max_value = hp
	health_bar.value = hp
