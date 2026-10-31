extends Door

@export var code: String = "0247"

@onready var panel: CanvasLayer = $CodePanel
@onready var code_input: LineEdit = $CodePanel/Box/CodeInput

func _ready() -> void:
	panel.hide()
	# Enter en la caja de texto llama a _on_code_submitted
	code_input.text_submitted.connect(_on_code_submitted)
	build_keypad()

# Teclado numérico en pantalla para jugar con mando (también sirve con el mouse)
func build_keypad() -> void:
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for label in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "←", "OK"]:
		var button := Button.new()
		button.text = label
		button.custom_minimum_size = Vector2(58, 44)
		button.pressed.connect(_on_keypad.bind(label))
		grid.add_child(button)
	$CodePanel/Box.add_child(grid)
	$CodePanel/Box.move_child(grid, code_input.get_index() + 1)
	# La tarjeta crece para que quepa el teclado
	$CodePanel/Card.offset_top -= 60.0
	$CodePanel/Card.offset_bottom += 60.0
	$CodePanel/Box.offset_top -= 60.0
	$CodePanel/Box.offset_bottom += 60.0
	keypad_first = grid.get_child(0)

var keypad_first: Button

func _on_keypad(label: String) -> void:
	if label == "OK":
		_on_code_submitted(code_input.text)
	elif label == "←":
		code_input.text = code_input.text.left(-1)
	elif code_input.text.length() < 8:
		code_input.text += label

# Si escribes con el teclado mientras un botón tiene el foco, el texto va a la caja
func _input(event: InputEvent) -> void:
	if panel.visible and event is InputEventKey and event.pressed and not code_input.has_focus():
		code_input.grab_focus()

# Reemplaza el interact() de Door: en vez de llave, pide código
func interact() -> void:
	if is_open:
		return
	panel.show()
	code_input.text = ""
	# Con mando conectado, el foco empieza en el teclado de pantalla
	if Input.get_connected_joypads().size() > 0:
		keypad_first.grab_focus()
		$CodePanel/Box/HelpLabel.text = "A pulsar  ·  B salir"
	else:
		code_input.grab_focus()
		$CodePanel/Box/HelpLabel.text = "Enter para confirmar  ·  Esc para salir"
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
		get_viewport().set_input_as_handled()

func close_panel() -> void:
	panel.hide()
	GameState.input_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
