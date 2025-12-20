class_name Shield extends Node3D

@export_group("Stats")
@export_range(0, 100) var melee_resistance: float = 70.0 
@export_range(0, 100) var ranged_resistance: float = 40.0 
@export_range(0.0, 1.0) var weight: float = 0.1 
@export var cost: int = 1

@export_group("Spikes")
@export var has_spikes: bool = false
@export var spike_damage: float = 15.0

var wielder: CharacterBody3D = null

func process_hit(damage: float, attacker: Node3D, is_ranged: bool) -> float:
	
	# Calcul réduction
	var resistance = ranged_resistance if is_ranged else melee_resistance
	var multiplier = clamp(1.0 - (resistance / 100.0), 0.0, 1.0)
	var final_damage = damage * multiplier
	
	# Spikes
	if has_spikes and not is_ranged and attacker:
		if attacker.has_method("take_damage"):
			attacker.take_damage(spike_damage, wielder, false)
			
	return final_damage
