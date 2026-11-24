extends Node3D
# =============================================================================
# Cinemática de introducción (≈ 40 s). Se ve al presionar JUGAR, antes de la
# tarjeta "2:47 a.m." (IntroScreen) y del juego.
#
# Cómo funciona:
#   - Carga el MISMO nivel del juego (no hay un video: todo es en tiempo real).
#   - Una cámara recorre 5 "tomas". Cada toma dice dónde empieza la cámara,
#     a dónde se mueve y hacia qué punto mira. Un Tween la mueve suave.
#   - Abajo aparece un subtítulo letra por letra (efecto máquina de escribir)
#     y arriba a la izquierda el lugar y la hora.
#   - Entre tomas la pantalla funde a negro.
#   - Mantener Espacio / Enter / Esc / Ⓐ durante 1 s salta la cinemática.
#
# Para cambiar el guion: edita la lista SHOTS (textos, posiciones, duración).
# =============================================================================

const NEXT_SCENE := "res://scenes/ui/IntroScreen.tscn"
const LEVEL := preload("res://scenes/levels/level_edificio_e.tscn")
const NINA := preload("res://scenes/props/nina.tscn")
const SKIP_TIME := 1.0 # segundos manteniendo el botón para saltar

# Cada toma: lugar, subtítulo, cámara desde -> hasta, punto al que mira, duración
# y "extra" (algo especial que pasa en esa toma).
const SHOTS := [
	{
		"lugar": "TEC · EDIFICIO E · 11:58 P.M.",
		"texto": "Dicen que el Edificio E nunca se queda vacío de noche.",
		"desde": Vector3(-13, 2.0, 18.0), "hasta": Vector3(-6.5, 1.8, 15.5),
		"mira": Vector3(1, 1.8, 13.3), "dur": 8.0, "extra": "",
	},
	{
		"lugar": "PASILLO DERECHO · 12:40 A.M.",
		"texto": "Las lámparas empezaron a fallar el día que instalaron el sistema AURORA.",
		"desde": Vector3(21.6, 1.75, 3.5), "hasta": Vector3(21.6, 1.7, 7.5),
		"mira": Vector3(21.6, 1.5, 22), "dur": 7.5, "extra": "",
	},
	{
		"lugar": "PASILLO CENTRAL · 1:15 A.M.",
		"texto": "El guardia nocturno sigue haciendo su ronda. No duerme. No come. No responde por radio.",
		"desde": Vector3(16.0, 1.6, 13.3), "hasta": Vector3(18.6, 1.65, 13.3),
		"mira": Vector3(0, 1.4, 13.3), "dur": 8.5, "extra": "guardia",
	},
	{
		"lugar": "CUBÍCULOS DE MAESTROS · 2:03 A.M.",
		"texto": "Y los maestros hablan de una niña de vestido blanco entre los cubículos.",
		"desde": Vector3(16.0, 1.6, 16.9), "hasta": Vector3(14.3, 1.5, 16.9),
		"mira": Vector3(9, 1.1, 16.9), "dur": 7.0, "extra": "nina",
	},
	{
		"lugar": "LABORATORIO · 2:46 A.M.",
		"texto": "Esta noche, tú te quedaste dormido en el laboratorio.",
		"desde": Vector3(20.2, 2.4, 23), "hasta": Vector3(20.2, 1.5, 23),
		"mira": Vector3(17.6, 0.8, 20), "dur": 7.0, "extra": "",
	},
]

var camera: Camera3D
var guard: CharacterBody3D
var nina: Node3D
var fade: ColorRect
var place_label: Label
var subtitle: Label
var skip_bar: ProgressBar
var skip_hold: float = 0.0
var leaving: bool = false
var look_target: Vector3
var music: AudioStreamPlayer


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	add_child(LEVEL.instantiate())
	# El guardia del nivel se queda quieto e invisible hasta su toma
	guard = get_tree().get_first_node_in_group("guard") as CharacterBody3D
	if guard == null:
		guard = find_child("Guard", true, false) as CharacterBody3D
	if guard != null:
		guard.hide()
		guard.process_mode = Node.PROCESS_MODE_DISABLED
	camera = Camera3D.new()
	camera.fov = 62.0 # un poco más cerrado que en el juego: se ve más "de película"
	add_child(camera)
	camera.make_current()
	_build_ui()
	_build_audio()
	_play_shots()


# ------------------------------------------------------------------ interfaz
func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var theme_res: Theme = load("res://scenes/ui/nights_theme.tres")
	# Grano de película y viñeta (el mismo shader del juego)
	var fx := ColorRect.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/vineta.gdshader")
	mat.set_shader_parameter("intensity", 0.55)
	mat.set_shader_parameter("grain", 0.07)
	mat.set_shader_parameter("desaturate", 0.25)
	fx.material = mat
	ui.add_child(fx)
	# Franjas negras de cine arriba y abajo (12% de la pantalla cada una)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 0.88
		bar.anchor_bottom = 0.12 if top else 1.0
		ui.add_child(bar)
	# Lugar y hora (arriba a la izquierda, dentro de la franja)
	place_label = Label.new()
	place_label.theme = theme_res
	place_label.add_theme_font_size_override("font_size", 22)
	place_label.add_theme_color_override("font_color", Color(0.75, 0.16, 0.14))
	place_label.position = Vector2(48, 28)
	ui.add_child(place_label)
	# Subtítulo (abajo, centrado, dentro de la franja)
	subtitle = Label.new()
	subtitle.theme = theme_res
	subtitle.theme_type_variation = &"SubtitleLabel"
	subtitle.add_theme_font_override("font", load("res://assets/fonts/SpecialElite-Regular.ttf"))
	subtitle.add_theme_font_size_override("font_size", 28)
	subtitle.add_theme_color_override("font_color", Color(0.86, 0.82, 0.74))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.anchor_left = 0.12
	subtitle.anchor_right = 0.88
	subtitle.anchor_top = 0.88
	subtitle.anchor_bottom = 1.0
	ui.add_child(subtitle)
	# Aviso para saltar + barrita que se llena al mantener el botón
	var hint := Label.new()
	hint.theme = theme_res
	hint.text = "Mantén ESPACIO para saltar"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.5, 0.48, 0.45))
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.offset_left = -300
	hint.offset_right = -40
	hint.offset_top = 30
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ui.add_child(hint)
	skip_bar = ProgressBar.new()
	skip_bar.show_percentage = false
	skip_bar.max_value = SKIP_TIME
	skip_bar.anchor_left = 1.0
	skip_bar.anchor_right = 1.0
	skip_bar.offset_left = -300
	skip_bar.offset_right = -40
	skip_bar.offset_top = 58
	skip_bar.offset_bottom = 62
	skip_bar.modulate.a = 0.0
	ui.add_child(skip_bar)
	# Telón negro para los fundidos (empieza tapando todo)
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade)


func _build_audio() -> void:
	# Música del menú muy baja + ambiente del edificio
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/audio/menu_musica.ogg")
	music.bus = &"Music"
	music.volume_db = -14.0
	add_child(music)
	music.play()
	var amb := AudioStreamPlayer.new()
	amb.stream = load("res://assets/audio/ambiente_edificio.ogg")
	amb.bus = &"Ambience"
	amb.volume_db = -6.0
	add_child(amb)
	amb.play()


# ------------------------------------------------------------------ tomas
func _play_shots() -> void:
	# DEBUG: INTRO_SHOT=n empieza en esa toma (para revisar sin ver todo)
	var first := int(OS.get_environment("INTRO_SHOT")) if OS.get_environment("INTRO_SHOT") != "" else 0
	for i in range(first, SHOTS.size()):
		if leaving:
			return
		await _shot(SHOTS[i])
	_finish()


func _shot(s: Dictionary) -> void:
	var dur: float = s["dur"]
	camera.global_position = s["desde"]
	look_target = s["mira"]
	camera.look_at(look_target)
	_start_extra(s["extra"])
	place_label.text = s["lugar"]
	subtitle.text = s["texto"]
	subtitle.visible_ratio = 0.0
	# Cámara: se desliza de "desde" a "hasta" durante toda la toma
	var move := create_tween()
	move.tween_property(camera, "global_position", s["hasta"], dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Fundido desde negro, subtítulo letra por letra, y fundido a negro al final
	var t := create_tween()
	t.tween_property(fade, "color:a", 0.0, 1.0)
	t.tween_property(subtitle, "visible_ratio", 1.0, subtitle.text.length() * 0.04)
	t.tween_interval(maxf(dur - 2.0 - subtitle.text.length() * 0.04, 0.5))
	t.tween_property(fade, "color:a", 1.0, 1.0)
	await t.finished
	move.kill()
	_end_extra(s["extra"])


# Lo especial de cada toma
func _start_extra(extra: String) -> void:
	match extra:
		"guardia":
			# El guardia aparece al fondo del pasillo y camina hacia la cámara
			if guard != null:
				guard.global_position = Vector3(3.5, 0.05, 13.3)
				guard.set("waypoint", 1) # va hacia (21.6, 0, 13.3): justo hacia nosotros
				guard.show()
				guard.process_mode = Node.PROCESS_MODE_INHERIT
		"nina":
			# La niña parada al fondo, entre los separadores, mirando a la cámara
			nina = NINA.instantiate()
			add_child(nina)
			nina.global_position = Vector3(10.2, 0.0, 16.9)
			nina.look_at(Vector3(17, 0, 16.9), Vector3.UP, true)
			# Luz fría y débil encima de ella para que se alcance a ver el vestido
			var cold := OmniLight3D.new()
			cold.light_color = Color(0.7, 0.8, 1.0)
			cold.light_energy = 0.45
			cold.omni_range = 2.5
			cold.position = Vector3(0, 1.7, 0.8)
			nina.add_child(cold)
			# Un instante después: golpe musical
			get_tree().create_timer(3.2).timeout.connect(func():
				var st := AudioStreamPlayer.new()
				st.stream = load("res://assets/audio/aguijon_visto.ogg")
				st.bus = &"SFX"
				st.volume_db = -6.0
				add_child(st)
				st.play())


func _end_extra(extra: String) -> void:
	match extra:
		"guardia":
			if guard != null:
				guard.hide()
				guard.process_mode = Node.PROCESS_MODE_DISABLED
		"nina":
			if nina != null:
				nina.queue_free()


func _process(delta: float) -> void:
	# La cámara siempre mira a su punto (y sigue al guardia en su toma)
	if camera != null:
		var target := look_target
		if guard != null and guard.visible:
			target = guard.global_position + Vector3(0, 1.4, 0)
		camera.look_at(target)
	# Saltar: mantener Espacio / Enter / Esc / Ⓐ
	var holding := Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_cancel")
	skip_hold = clampf(skip_hold + (delta if holding else -delta * 2.0), 0.0, SKIP_TIME)
	skip_bar.value = skip_hold
	skip_bar.modulate.a = 1.0 if skip_hold > 0.0 else 0.0
	if skip_hold >= SKIP_TIME and not leaving:
		_finish()


func _finish() -> void:
	if leaving:
		return
	leaving = true
	var t := create_tween()
	t.tween_property(fade, "color:a", 1.0, 0.6)
	t.parallel().tween_property(music, "volume_db", -60.0, 0.6)
	t.tween_callback(func(): get_tree().change_scene_to_file(NEXT_SCENE))
