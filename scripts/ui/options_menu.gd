extends Control
# =============================================================================
# Menú de OPCIONES (se usa desde el menú principal y desde la pausa).
#
# En vez de dibujar cada fila a mano en el editor, las filas se CREAN POR CÓDIGO
# a partir de listas. Así agregar una opción nueva es agregar una línea.
#   - add_option(...)  -> lista desplegable (OptionButton)
#   - add_toggle(...)  -> interruptor encendido/apagado (CheckButton)
#   - add_slider(...)  -> barra deslizante (HSlider) con su valor a la derecha
# Cada control lee su valor de Settings.values y, al cambiar, llama a
# Settings.set_value(), que lo aplica al momento y lo guarda en disco.
# =============================================================================

signal closed # avisa a quien lo abrió (menú o pausa) que ya se cerró

@onready var graphics_box: VBoxContainer = %Graficos
@onready var audio_box: VBoxContainer = %Audio
@onready var controls_box: VBoxContainer = %Controles
@onready var back_button: Button = %BackButton
@onready var reset_button: Button = %ResetButton

var updating: bool = false # evita bucles al refrescar los controles por código
var refreshers: Array[Callable] = [] # funciones que vuelven a leer cada valor


func _ready() -> void:
	hide()
	build_rows()
	back_button.pressed.connect(close)
	reset_button.pressed.connect(func(): Settings.reset_to_defaults())
	Settings.changed.connect(refresh_all)
	UiSound.connect_buttons(self)


func open() -> void:
	refresh_all()
	show()
	back_button.grab_focus()


func close() -> void:
	hide()
	closed.emit()


# Esc / B también cierra
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- filas
func build_rows() -> void:
	# --- GRÁFICOS
	var presets: Array = Settings.PRESET_NAMES.duplicate()
	presets.append("Personalizado")
	add_option(graphics_box, "Calidad general", presets, "preset", _on_preset_selected, _get_preset_index)
	add_option(graphics_box, "Sombras", ["Apagadas", "Bajas", "Medias", "Altas"], "shadows")
	add_option(graphics_box, "Antialiasing", ["Ninguno", "FXAA (rápido)", "MSAA 2x", "MSAA 4x"], "aa")
	add_slider(graphics_box, "Resolución de render", "render_scale", 0.5, 1.0, 0.05, func(v): return "%d%%" % roundi(v * 100))
	add_toggle(graphics_box, "Niebla", "fog")
	add_toggle(graphics_box, "Niebla volumétrica (rayos de luz)", "volumetric_fog")
	add_toggle(graphics_box, "Oclusión ambiental (SSAO)", "ssao")
	add_toggle(graphics_box, "Reflejos en pantalla (SSR)", "ssr")
	add_toggle(graphics_box, "Resplandor (glow)", "glow")
	add_slider(graphics_box, "Brillo", "brightness", 0.6, 1.6, 0.05, func(v): return "%d%%" % roundi(v * 100))
	add_toggle(graphics_box, "Pantalla completa", "fullscreen")
	add_toggle(graphics_box, "Sincronización vertical (VSync)", "vsync")
	# --- AUDIO
	var pct := func(v): return "%d%%" % roundi(v * 100)
	add_slider(audio_box, "Volumen general", "vol_master", 0.0, 1.0, 0.05, pct)
	add_slider(audio_box, "Música", "vol_music", 0.0, 1.0, 0.05, pct)
	add_slider(audio_box, "Efectos (pasos, guardia, sustos)", "vol_sfx", 0.0, 1.0, 0.05, pct)
	add_slider(audio_box, "Ambiente", "vol_ambience", 0.0, 1.0, 0.05, pct)
	# --- CONTROLES
	add_slider(controls_box, "Sensibilidad del mouse", "mouse_sensitivity", 0.0005, 0.006, 0.0001,
		func(v): return "%.1f" % (v * 1000.0))
	add_toggle(controls_box, "Invertir eje Y", "invert_y")
	add_slider(controls_box, "Campo de visión (FOV)", "fov", 60.0, 100.0, 1.0, func(v): return "%d°" % roundi(v))
	add_toggle(controls_box, "Bamboleo de cámara al caminar", "head_bob")
	var help := Label.new()
	help.text = "W A S D  moverse     Shift  correr     Ctrl  agacharse\nF  linterna     E (mantener)  interactuar     Esc  pausa"
	help.add_theme_color_override("font_color", Color(0.58, 0.55, 0.5))
	help.add_theme_font_size_override("font_size", 20)
	controls_box.add_child(help)


# Elegir "Personalizado" no cambia nada; los demás aplican su preset
func _on_preset_selected(index: int) -> void:
	if index < Settings.PRESET_NAMES.size():
		Settings.apply_preset(index)


# -1 (personalizado) se muestra como el último elemento de la lista
func _get_preset_index() -> int:
	var p: int = Settings.values["preset"]
	return p if p >= 0 else Settings.PRESET_NAMES.size()


# Crea una fila: etiqueta a la izquierda, control a la derecha
func _row(box: VBoxContainer, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	box.add_child(row)
	return row


# Lista desplegable. on_select y getter son opcionales (para casos especiales)
func add_option(box: VBoxContainer, text: String, items: Array, key: String,
		on_select: Callable = Callable(), getter: Callable = Callable()) -> void:
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(240, 0)
	for item in items:
		opt.add_item(item)
	_row(box, text).add_child(opt)
	opt.item_selected.connect(func(i):
		if updating:
			return
		if on_select.is_valid():
			on_select.call(i)
		else:
			Settings.set_value(key, i))
	refreshers.append(func():
		opt.select(getter.call() if getter.is_valid() else Settings.values[key]))


func add_toggle(box: VBoxContainer, text: String, key: String) -> void:
	var check := CheckButton.new()
	_row(box, text).add_child(check)
	check.toggled.connect(func(on):
		if not updating:
			Settings.set_value(key, on))
	refreshers.append(func(): check.button_pressed = Settings.values[key])


func add_slider(box: VBoxContainer, text: String, key: String, min_v: float, max_v: float,
		step: float, fmt: Callable) -> void:
	var row := _row(box, text)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.custom_minimum_size = Vector2(240, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(64, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(slider)
	row.add_child(value_label)
	slider.value_changed.connect(func(v):
		value_label.text = fmt.call(v)
		if not updating:
			Settings.set_value(key, v))
	refreshers.append(func():
		slider.value = Settings.values[key]
		value_label.text = fmt.call(slider.value))


# Vuelve a leer todos los valores (por ejemplo, después de elegir un preset)
func refresh_all() -> void:
	updating = true
	for r in refreshers:
		r.call()
	updating = false
