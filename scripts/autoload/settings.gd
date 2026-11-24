extends Node
# =============================================================================
# Settings (autoload): guarda y aplica las OPCIONES del juego.
#
# Qué hace:
#   1. Guarda las opciones en "user://opciones.cfg" (en Windows queda en
#      %APPDATA%\Godot\app_userdata\Nights of Tec\opciones.cfg).
#   2. Aplica los gráficos: preset de calidad, sombras, niebla, SSAO, reflejos,
#      resolución de render, antialiasing, pantalla completa y vsync.
#   3. Aplica el volumen de cada bus de audio (Master, Music, SFX, Ambience).
#   4. Guarda los controles: sensibilidad del mouse, invertir Y y campo de visión.
#
# Cómo se usa desde otro script:
#   Settings.values["mouse_sensitivity"]        -> leer una opción
#   Settings.set_value("fog", false)            -> cambiarla (se aplica y se guarda)
#   Settings.changed.connect(mi_funcion)        -> enterarte cuando algo cambia
# =============================================================================

signal changed # se emite cada vez que cambia cualquier opción

const SAVE_PATH := "user://opciones.cfg"

# Nombres de los presets en el orden en que salen en el menú
const PRESET_NAMES := ["Bajo", "Medio", "Alto", "Ultra"]

# Qué activa cada preset. "render_scale" 1.0 = resolución completa.
# aa: 0 = sin antialiasing, 1 = FXAA, 2 = MSAA 2x, 3 = MSAA 4x
# shadows: 0 = apagadas, 1 = bajas, 2 = medias, 3 = altas
const PRESETS := [
	{"shadows": 1, "fog": true, "volumetric_fog": false, "ssao": false, "ssr": false, "glow": true, "render_scale": 0.77, "aa": 1},
	{"shadows": 2, "fog": true, "volumetric_fog": true, "ssao": true, "ssr": false, "glow": true, "render_scale": 1.0, "aa": 1},
	{"shadows": 3, "fog": true, "volumetric_fog": true, "ssao": true, "ssr": true, "glow": true, "render_scale": 1.0, "aa": 2},
	{"shadows": 3, "fog": true, "volumetric_fog": true, "ssao": true, "ssr": true, "glow": true, "render_scale": 1.0, "aa": 3},
]

# Valores por defecto (preset "Alto": la RTX 4050 lo mueve bien)
var defaults := {
	"preset": 2, # índice en PRESET_NAMES; -1 = personalizado
	"shadows": 3,
	"fog": true,
	"volumetric_fog": true,
	"ssao": true,
	"ssr": true,
	"glow": true,
	"render_scale": 1.0,
	"aa": 2,
	"fullscreen": true,
	"vsync": true,
	"brightness": 1.0,
	"vol_master": 0.9,
	"vol_music": 0.7,
	"vol_sfx": 0.9,
	"vol_ambience": 0.8,
	"mouse_sensitivity": 0.0022,
	"invert_y": false,
	"fov": 75.0,
	"head_bob": true, # bamboleo de cámara al caminar (apágalo si te marea)
}
var values: Dictionary = {}


func _ready() -> void:
	# Este nodo sigue funcionando aunque el juego esté en pausa (menú de pausa)
	process_mode = Node.PROCESS_MODE_ALWAYS
	values = defaults.duplicate()
	load_settings()
	apply_all()
	# Cuando aparece un WorldEnvironment nuevo (al cambiar de escena) le aplicamos
	# las opciones de gráficos. call_deferred espera a que la escena termine de cargar.
	get_tree().node_added.connect(_on_node_added)


# ---------------------------------------------------------------- guardar/cargar
func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return # primera vez: se quedan los valores por defecto
	for key in defaults.keys():
		values[key] = cfg.get_value("opciones", key, defaults[key])


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in values.keys():
		cfg.set_value("opciones", key, values[key])
	cfg.save(SAVE_PATH)


# Cambia una opción, la aplica y la guarda
func set_value(key: String, value) -> void:
	values[key] = value
	# Si tocas una opción de gráficos a mano, el preset pasa a "Personalizado"
	if key in PRESETS[0].keys():
		values["preset"] = -1
	apply_all()
	save_settings()
	changed.emit()


# Aplica un preset completo (Bajo/Medio/Alto/Ultra)
func apply_preset(index: int) -> void:
	for key in PRESETS[index].keys():
		values[key] = PRESETS[index][key]
	values["preset"] = index
	apply_all()
	save_settings()
	changed.emit()


func reset_to_defaults() -> void:
	values = defaults.duplicate()
	apply_all()
	save_settings()
	changed.emit()


# ---------------------------------------------------------------- aplicar
func apply_all() -> void:
	apply_window()
	apply_rendering()
	apply_environment()
	apply_audio()


func apply_window() -> void:
	# En el editor no forzamos pantalla completa para no estorbar al probar
	if not OS.has_feature("editor"):
		var mode := DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if values["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	var vsync := DisplayServer.VSYNC_ENABLED if values["vsync"] else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync)


func apply_rendering() -> void:
	var vp := get_viewport()
	# Resolución de render: menos de 1.0 = se dibuja más pequeño y FSR lo escala
	vp.scaling_3d_scale = values["render_scale"]
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if values["render_scale"] < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	# Antialiasing
	var aa: int = values["aa"]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	match aa:
		2: vp.msaa_3d = Viewport.MSAA_2X
		3: vp.msaa_3d = Viewport.MSAA_4X
		_: vp.msaa_3d = Viewport.MSAA_DISABLED
	# Sombras: tamaño del "atlas" (más grande = más nítidas) y suavizado del borde
	var s: int = values["shadows"]
	var atlas_sizes := [0, 2048, 4096, 8192]
	vp.positional_shadow_atlas_size = atlas_sizes[s]
	RenderingServer.directional_shadow_atlas_set_size([512, 2048, 4096, 4096][s], true)
	var soft := [RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH]
	RenderingServer.positional_soft_shadow_filter_set_quality(soft[s])
	RenderingServer.directional_soft_shadow_filter_set_quality(soft[s])


# Activa o desactiva los efectos del WorldEnvironment de la escena actual
func apply_environment() -> void:
	var world := get_viewport().find_world_3d()
	if world == null or world.environment == null:
		return
	var env := world.environment
	env.fog_enabled = values["fog"]
	env.volumetric_fog_enabled = values["volumetric_fog"]
	env.ssao_enabled = values["ssao"]
	env.ssr_enabled = values["ssr"]
	env.glow_enabled = values["glow"]
	# El brillo se maneja con los "ajustes" del entorno
	env.adjustment_enabled = true
	env.adjustment_brightness = values["brightness"]


func apply_audio() -> void:
	_set_bus_volume("Master", values["vol_master"])
	_set_bus_volume("Music", values["vol_music"])
	_set_bus_volume("SFX", values["vol_sfx"])
	_set_bus_volume("Ambience", values["vol_ambience"])


# El volumen se guarda de 0.0 a 1.0; los buses usan decibeles (dB)
func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


func _on_node_added(node: Node) -> void:
	if node is WorldEnvironment:
		apply_environment.call_deferred()
