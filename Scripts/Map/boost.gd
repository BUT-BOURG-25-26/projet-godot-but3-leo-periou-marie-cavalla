extends Node3D

@onready var attack_model = $Attack
@onready var health_model = $Health
@onready var speed_model = $Speed

var rng_boost = {
	"Health": 50,
	"Attack": 25,
	"Speed": 25
}

var type: String = ""
var duration: float = 20.0

func _ready():
	type = get_weighted_random_type()
	update_visuals()

func get_weighted_random_type() -> String:
	var total_weight = 0
	for key in rng_boost:
		total_weight += rng_boost[key]
	
	var random_val = randi() % total_weight
	var current_weight = 0
	
	for key in rng_boost:
		current_weight += rng_boost[key]
		if random_val < current_weight:
			return key
	
	return "Health" # Fallback

func update_visuals():
	attack_model.hide()
	health_model.hide()
	speed_model.hide()
	
	match type:
		"Health": health_model.show()
		"Attack": attack_model.show()
		"Speed": speed_model.show()

func _process(delta: float) -> void:
	rotation.y += delta * 1.5

func _on_boost_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		var player = body as Player
		player.apply_boost(type, duration)
		queue_free()
