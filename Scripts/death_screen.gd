extends Control

@export var fade_duration: float = 5.0
@onready var restart_button = $RestartBtn
@onready var exit_button = $ExitBtn
@onready var restart_cooldown = $RestartCooldown
@onready var death_sound = $DeadSound

func _ready():
	modulate.a = 0.0
	visible = false
	restart_button.hide()
	exit_button.hide()

func show_death_screen():
	get_tree().create_tween().kill()
	
	visible = true
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, fade_duration)
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	restart_cooldown.start()
	death_sound.play()


func _restart_cooldown() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	restart_button.show()
	exit_button.show()
	


func _restart_btn_pressed() -> void:
	get_tree().reload_current_scene()


func _exit_btn_pressed() -> void:
	get_tree().quit()
