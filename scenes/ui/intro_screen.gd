extends Control

@export var duration: float = 3.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	$Center.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property($Center, "modulate:a", 1.0, 0.8)
	tween.tween_interval(duration)
	tween.tween_property($Center, "modulate:a", 0.0, 0.8)
	tween.tween_callback(_go_to_game)

func _go_to_game() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
