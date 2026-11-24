extends OmniLight3D
# =============================================================================
# Luz que PARPADEA como una lámpara fluorescente vieja.
# Se pone como script de un OmniLight3D. Opcionalmente apunta a la malla de la
# lámpara (lamp_mesh) para que su brillo se apague y prenda junto con la luz.
#
# Funciona como una pequeña "máquina de estados" dentro de _process:
#   - ESPERA: la luz está normal; cuenta hacia atrás hasta el siguiente parpadeo.
#   - PARPADEO: alterna apagado/encendido varias veces muy rápido.
#   - MUERTA: a veces se queda apagada un rato (con un chasquido eléctrico).
# =============================================================================

enum Mode { WAIT, FLICKER, DEAD }

@export var lamp_mesh: NodePath # la MeshInstance3D de la lámpara (opcional)
@export var min_wait: float = 2.0 # segundos mínimos entre parpadeos
@export var max_wait: float = 8.0 # segundos máximos entre parpadeos
@export_range(0.0, 1.0) var dead_chance: float = 0.2 # probabilidad de quedarse apagada
@export var buzz_volume_db: float = -14.0 # zumbido eléctrico cerca de la lámpara

var mode: Mode = Mode.WAIT
var timer: float = 0.0
var flickers_left: int = 0
var base_energy: float
var lamp_material: StandardMaterial3D
var base_emission: float = 1.0
var buzz: AudioStreamPlayer3D
var spark: AudioStreamPlayer3D


func _ready() -> void:
	base_energy = light_energy
	timer = randf_range(min_wait, max_wait)
	# Copiamos el material de la lámpara: si no, TODAS las lámparas que lo
	# comparten parpadearían al mismo tiempo.
	var lamp := get_node_or_null(lamp_mesh) as MeshInstance3D
	if lamp != null and lamp.material_override is StandardMaterial3D:
		lamp_material = lamp.material_override.duplicate()
		lamp.material_override = lamp_material
		base_emission = lamp_material.emission_energy_multiplier
	# Zumbido en 3D: solo se oye cerca de la lámpara
	var hum := load("res://assets/audio/zumbido_lampara.ogg") as AudioStreamOggVorbis
	hum = hum.duplicate()
	hum.loop = true
	buzz = _make_player(hum, buzz_volume_db)
	buzz.autoplay = true
	spark = _make_player(load("res://assets/audio/chispa_lampara.ogg"), -6.0)


func _make_player(stream: AudioStream, volume: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume
	p.unit_size = 2.0
	p.max_distance = 9.0
	p.bus = &"SFX"
	add_child(p)
	return p


func _process(delta: float) -> void:
	timer -= delta
	if timer > 0.0:
		return
	match mode:
		Mode.WAIT:
			# Empieza una ráfaga de 2 a 7 parpadeos
			mode = Mode.FLICKER
			flickers_left = randi_range(2, 7) * 2
			timer = 0.0
		Mode.FLICKER:
			# Cada paso alterna entre casi apagada y encendida
			flickers_left -= 1
			if flickers_left % 2 == 1:
				set_level(randf_range(0.0, 0.25))
				timer = randf_range(0.03, 0.12)
			else:
				set_level(randf_range(0.8, 1.0))
				timer = randf_range(0.03, 0.25)
			if flickers_left <= 0:
				if randf() < dead_chance:
					mode = Mode.DEAD
					set_level(0.0)
					spark.play()
					timer = randf_range(0.8, 3.0)
				else:
					mode = Mode.WAIT
					set_level(1.0)
					timer = randf_range(min_wait, max_wait)
		Mode.DEAD:
			mode = Mode.WAIT
			set_level(1.0)
			timer = randf_range(min_wait, max_wait)


# 0.0 = apagada, 1.0 = brillo normal. Mueve luz, lámpara y zumbido juntos.
func set_level(level: float) -> void:
	light_energy = base_energy * level
	if lamp_material != null:
		lamp_material.emission_energy_multiplier = base_emission * level
	buzz.volume_db = buzz_volume_db if level > 0.5 else -60.0
