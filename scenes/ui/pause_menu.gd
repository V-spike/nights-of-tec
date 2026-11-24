extends CanvasLayer
# Menú de pausa (Esc o Start). Pausa el juego, suelta el mouse y deja abrir Opciones.
# En el Open Day también sirve para regresar al menú entre visitantes.

@onready var continue_button: Button = $Center/Panel/Box/ContinueButton
@onready var panel: Control = $Center
@onready var options_menu: Control = $OptionsMenu


func _ready() -> void:
	hide()
	continue_button.pressed.connect(resume)
	$Center/Panel/Box/OptionsButton.pressed.connect(_on_options)
	$Center/Panel/Box/MenuButton.pressed.connect(_on_menu)
	$Center/Panel/Box/QuitButton.pressed.connect(_on_quit)
	options_menu.closed.connect(_on_options_closed)
	UiSound.connect_buttons(self)


func _unhandled_input(event: InputEvent) -> void:
	if options_menu.visible:
		return # Opciones maneja su propio Esc
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
	panel.show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	continue_button.grab_focus()


func resume() -> void:
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_options() -> void:
	panel.hide()
	options_menu.open()


func _on_options_closed() -> void:
	panel.show()
	$Center/Panel/Box/OptionsButton.grab_focus()


func _on_menu() -> void:
	get_tree().paused = false
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_quit() -> void:
	get_tree().quit()
