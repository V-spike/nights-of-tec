extends CanvasLayer
# Menú de pausa (Esc o Start). En el Open Day sirve para regresar al menú entre visitantes

@onready var continue_button: Button = $Center/Panel/Box/ContinueButton


func _ready() -> void:
	hide()
	continue_button.pressed.connect(resume)
	$Center/Panel/Box/MenuButton.pressed.connect(_on_menu)
	$Center/Panel/Box/QuitButton.pressed.connect(_on_quit)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			resume()
		elif not GameState.input_locked: # no pausa mientras lees una nota, el código o una captura
			open()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		resume()
		get_viewport().set_input_as_handled()


func open() -> void:
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	continue_button.grab_focus()


func resume() -> void:
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_menu() -> void:
	get_tree().paused = false
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_quit() -> void:
	get_tree().quit()
