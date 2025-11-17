extends Camera3D

@export var lerp_power: float = 5.0
@export var spring_arm: Node3D

func _process(delta: float) -> void:
	position = lerp(position, spring_arm.position, delta*lerp_power)
