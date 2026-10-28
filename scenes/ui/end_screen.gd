extends Control

@export var seconds: int = 10

var leaving: bool = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in range(seconds, 0, -1):
		if leaving:
			return
		$Center/Box/CountdownLabel.text = "Volviendo al menú en %d" % i
		await get_tree().create_timer(1.0).timeout
	_go_to_menu()

# Cualquier tecla o clic regresa al menú sin esperar
func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		_go_to_menu()

func _go_to_menu() -> void:
	if leaving:
		return
	leaving = true
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
