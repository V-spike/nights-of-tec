extends Control
# =============================================================================
# Menú principal: fondo con movimiento lento y parpadeo, música, versión del
# juego y botones (Jugar, Opciones, Créditos, Salir).
# =============================================================================

@onready var background: TextureRect = $Background
@onready var flicker: ColorRect = $Flicker
@onready var buttons: VBoxContainer = $Margin/Column/Buttons
@onready var options_menu: Control = $OptionsMenu
@onready var credits: PanelContainer = $Credits
@onready var version_label: Label = $VersionLabel

var time: float = 0.0
var flicker_timer: float = 2.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# La versión sale de Proyecto > Configuración > Aplicación > Config > Versión
	version_label.text = "v" + str(ProjectSettings.get_setting("application/config/version", "1.0"))
	$Margin/Column/Buttons/PlayButton.pressed.connect(_on_play)
	$Margin/Column/Buttons/OptionsButton.pressed.connect(_on_options)
	$Margin/Column/Buttons/CreditsButton.pressed.connect(_on_credits)
	$Margin/Column/Buttons/QuitButton.pressed.connect(_on_quit)
	options_menu.closed.connect(_on_submenu_closed)
	$Credits/Box/CloseCredits.pressed.connect(_on_submenu_closed)
	UiSound.connect_buttons(self)
	$Margin/Column/Buttons/PlayButton.grab_focus()
	# Entrada: el menú aparece desde negro
	modulate = Color.BLACK
	create_tween().tween_property(self, "modulate", Color.WHITE, 1.6)


func _process(delta: float) -> void:
	time += delta
	# Fondo: zoom y paneo muy lentos (efecto "Ken Burns")
	var s := 1.08 + 0.04 * sin(time * 0.05)
	background.scale = Vector2(s, s)
	background.pivot_offset = background.size * Vector2(0.5 + 0.03 * sin(time * 0.03), 0.5)
	# Parpadeo de lámpara: de vez en cuando la imagen se oscurece un instante
	flicker_timer -= delta
	if flicker_timer <= 0.0:
		flicker.color.a = randf_range(0.35, 0.8)
		flicker_timer = randf_range(0.04, 0.12) if randf() < 0.6 else randf_range(2.5, 7.0)
	else:
		flicker.color.a = move_toward(flicker.color.a, 0.0, delta * 6.0)


func _on_play() -> void:
	GameState.reset()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Fundido a negro y baja la música antes de cambiar de escena
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate", Color.BLACK, 1.0)
	tween.tween_property($Music, "volume_db", -40.0, 1.0)
	await tween.finished
	get_tree().change_scene_to_file("res://scenes/ui/intro_cinematica.tscn") # primero la cinemática


func _on_options() -> void:
	$Margin.hide()
	options_menu.open()


func _on_credits() -> void:
	$Margin.hide()
	credits.show()
	$Credits/Box/CloseCredits.grab_focus()


func _on_submenu_closed() -> void:
	credits.hide()
	$Margin.show()
	$Margin/Column/Buttons/OptionsButton.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if credits.visible and event.is_action_pressed("ui_cancel"):
		_on_submenu_closed()
		get_viewport().set_input_as_handled()


func _on_quit() -> void:
	get_tree().quit()
