extends Node3D

@onready var timer = $BoostTimer
var type:String = ""
var player:Player = null

func set_boost_type(type:String):
	self.type = type

func _on_boost_body_entered(body: Node3D) -> void:
	if(body.is_in_group("Player")):
		player = body as Player
		player.add_boost(type)
		timer.start()
		hide()

func _on_boost_timer_timeout() -> void:
	if(player):
		player.remove_boost(type)
	queue_free()
