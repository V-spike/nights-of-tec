extends Node
# =============================================================================
# UiSound (autoload): sonidos de interfaz para TODOS los botones del juego.
# Uso: UiSound.connect_buttons(self)  -> conecta los botones dentro de ese nodo
#      (al pasar el mouse suena "hover" y al presionar suena "click").
# =============================================================================

var hover_player: AudioStreamPlayer
var click_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # suena aunque el juego esté en pausa
	hover_player = _make("res://assets/audio/ui_hover.ogg", -14.0)
	click_player = _make("res://assets/audio/ui_click.ogg", -8.0)


func _make(path: String, volume: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = volume
	p.bus = &"SFX"
	add_child(p)
	return p


func hover() -> void:
	hover_player.play()


func click() -> void:
	click_player.play()


# Recorre todos los hijos y conecta los que sean botones (Button, CheckButton,
# OptionButton...). Los sliders suenan al soltarlos.
func connect_buttons(root: Node) -> void:
	for node in root.find_children("*", "BaseButton", true, false):
		if not node.mouse_entered.is_connected(hover):
			node.mouse_entered.connect(hover)
			node.focus_entered.connect(hover)
			node.pressed.connect(click)
	for node in root.find_children("*", "Slider", true, false):
		if not node.drag_ended.is_connected(_on_slider_released):
			node.drag_ended.connect(_on_slider_released)


func _on_slider_released(_changed: bool) -> void:
	hover()
