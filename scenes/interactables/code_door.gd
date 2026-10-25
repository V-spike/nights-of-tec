extends Door

@export var code: String = "0247"

@onready var panel: CanvasLayer = $CodePanel
@onready var code_input: LineEdit = $CodePanel/Box/CodeInput

func _ready() -> void:
	panel.hide()
	# Enter en la caja de texto llama a _on_code_submitted
	code_input.text_submitted.connect(_on_code_submitted)

# Reemplaza el interact() de Door: en vez de llave, pide código
func interact() -> void:
	if is_open:
		return
	panel.show()
	code_input.text = ""
	code_input.grab_focus()
	GameState.input_locked = true # el jugador se queda quieto
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_code_submitted(text: String) -> void:
	close_panel()
	if text.strip_edges() == code:
		open() # open() viene de Door
	else:
		GameState.hint_shown.emit("Código incorrecto.")
		print("Código incorrecto.")
		$LockedSound.play()

# Esc cierra el panel sin abrir
func _unhandled_input(event: InputEvent) -> void:
	if panel.visible and event.is_action_pressed("ui_cancel"):
		close_panel()

func close_panel() -> void:
	panel.hide()
	GameState.input_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
