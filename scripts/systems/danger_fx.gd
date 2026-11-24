extends CanvasLayer
# =============================================================================
# DangerFX: todo lo que el jugador SIENTE cuando el guardia está cerca.
#
#   - "danger" (0 a 1): qué tanto peligro hay. Sube rápido y baja despacio.
#       * 1.0 si el guardia te persigue
#       * hasta 0.6 según qué tan cerca está (aunque no te vea)
#       * 0.35 si anda buscándote
#   - Viñeta (shader vineta.gdshader): se cierra y se pone roja con el peligro.
#     Además "respira": se abre y se cierra al ritmo de la respiración.
#   - Respiración agitada: suena solo al correr o cuando el guardia te persigue.
#   - Latido: cada vez más rápido y fuerte mientras más cerca está el guardia.
#   - Aguijón (stinger): golpe musical la primera vez que el guardia te ve.
# =============================================================================

@export var near_distance: float = 14.0 # a partir de aquí empieza a subir el peligro
@export var base_vignette: float = 0.35 # viñeta mínima (siempre hay un poco)

@onready var vignette: ColorRect = $Vignette
@onready var heartbeat: AudioStreamPlayer = $Heartbeat
@onready var breathing: AudioStreamPlayer = $Breathing
@onready var stinger: AudioStreamPlayer = $Stinger

var player: Node3D
var guard: Node3D
var danger: float = 0.0
var breath_level: float = 0.0
var beat_timer: float = 0.0
var beat_kick: float = 0.0 # pequeño "golpe" de la viñeta en cada latido
var was_chasing: bool = false
var stinger_cooldown: float = 0.0
var shader: ShaderMaterial


func _ready() -> void:
	shader = vignette.material as ShaderMaterial
	# La respiración se repite sola; empieza callada
	breathing.volume_db = -60.0
	breathing.finished.connect(breathing.play)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if guard == null or not is_instance_valid(guard):
		guard = get_tree().get_first_node_in_group("guard")
	if player == null:
		return

	# ---- 1. ¿Cuánto peligro hay?
	var target := 0.0
	var chasing := false
	if guard != null:
		var dist := guard.global_position.distance_to(player.global_position)
		var closeness := clampf(1.0 - (dist - 2.0) / near_distance, 0.0, 1.0)
		target = closeness * 0.6
		if guard.has_method("is_chasing") and guard.is_chasing():
			chasing = true
			target = 1.0
		elif guard.has_method("is_searching") and guard.is_searching():
			target = maxf(target, 0.35)
	# Sube rápido (te asustas de golpe) y baja despacio (te cuesta calmarte)
	var speed := 1.8 if target > danger else 0.22
	danger = move_toward(danger, target, speed * delta)

	# ---- 2. Aguijón al empezar una persecución (máximo uno cada 10 s)
	stinger_cooldown -= delta
	if chasing and not was_chasing and stinger_cooldown <= 0.0:
		stinger.play()
		stinger_cooldown = 10.0
	was_chasing = chasing

	# ---- 3. Respiración: SOLO cuando corres o el guardia te persigue
	#    (al dejar de correr se va apagando poco a poco, como cuando recuperas el aire)
	var breath_target := 0.0
	if chasing:
		breath_target = 0.8
	elif player.get("running"):
		breath_target = 0.5
	breath_level = move_toward(breath_level, breath_target, 0.35 * delta)
	if breath_level > 0.06:
		if not breathing.playing:
			breathing.play()
		breathing.volume_db = lerpf(-28.0, -8.0, breath_level)
		breathing.pitch_scale = lerpf(0.92, 1.08, breath_level) # apenas un poco más rápida con miedo
	elif breathing.playing:
		breathing.volume_db = move_toward(breathing.volume_db, -60.0, 30.0 * delta)
		if breathing.volume_db <= -59.0:
			breathing.stop()

	# ---- 4. Latido: intervalo de 1.1 s (calmado) a 0.42 s (pánico)
	beat_kick = move_toward(beat_kick, 0.0, 3.0 * delta)
	if danger > 0.12:
		beat_timer -= delta
		if beat_timer <= 0.0:
			beat_timer = lerpf(1.1, 0.42, danger)
			heartbeat.volume_db = lerpf(-22.0, 0.0, danger)
			heartbeat.pitch_scale = lerpf(0.95, 1.1, danger)
			heartbeat.play()
			beat_kick = 1.0
	else:
		beat_timer = 0.0

	# ---- 5. Viñeta sincronizada con la respiración
	# La pista de respiración trae 2 ciclos (inhala/exhala x2). Con la posición
	# de reproducción sabemos en qué parte del ciclo vamos.
	var breath_wave := 0.0
	if breathing.playing and breathing.stream != null:
		var length := breathing.stream.get_length()
		var phase := fmod(breathing.get_playback_position() / length * 2.0, 1.0)
		breath_wave = 0.5 - 0.5 * cos(phase * TAU) # 0 -> 1 -> 0 en cada ciclo
	var intensity := base_vignette + danger * 0.6 + breath_wave * 0.12 * breath_level + beat_kick * 0.07 * danger
	shader.set_shader_parameter("intensity", intensity)
	shader.set_shader_parameter("red_amount", clampf(danger * 1.2 - 0.2, 0.0, 1.0))
	shader.set_shader_parameter("aberration", danger * 0.006 + beat_kick * 0.002 * danger)
	shader.set_shader_parameter("desaturate", danger * 0.35)
