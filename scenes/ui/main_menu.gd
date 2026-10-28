extends Control

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Center/MenuContainer/PlayButton.pressed.connect(_on_play)
	$Center/MenuContainer/QuitButton.pressed.connect(_on_quit)
	$Center/MenuContainer/PlayButton.grab_focus()

func _on_play() -> void:
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/ui/IntroScreen.tscn")

func _on_quit() -> void:
	get_tree().quit()
