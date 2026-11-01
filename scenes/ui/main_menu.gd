extends Control

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# El juego exportado (.exe) arranca en pantalla completa; en el editor se queda en ventana
	if not OS.has_feature("editor"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	$Center/MenuContainer/PlayButton.pressed.connect(_on_play)
	$Center/MenuContainer/QuitButton.pressed.connect(_on_quit)
	$Center/MenuContainer/PlayButton.grab_focus()

func _on_play() -> void:
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/ui/IntroScreen.tscn")

func _on_quit() -> void:
	get_tree().quit()
