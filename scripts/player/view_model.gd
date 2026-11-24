extends Node3D
# =============================================================================
# ViewModel: las manos del jugador sosteniendo la linterna (primera persona).
# Va como hijo de la Camera3D, así siempre se ve en la esquina inferior derecha.
#
# Movimientos (todo con lerp para que se vea suave):
#   - Balanceo (sway): al mover el mouse, la mano se queda un poco atrás.
#   - Bamboleo (bob): al caminar sube y baja; al correr más fuerte y rápido.
#   - Respiración: estando quieto, un vaivén muy leve.
#   - Si hay una pared muy cerca, la mano se retrae para no atravesarla.
#   - El lente de la linterna brilla solo cuando está encendida.
# =============================================================================

@export var sway_amount: float = 0.0009 # cuánto se retrasa con el mouse
@export var sway_max: float = 0.05
@export var bob_walk: float = 0.012
@export var bob_run: float = 0.028

var rest_position: Vector3 # posición de reposo (la que tiene en el editor)
var rest_rotation: Vector3
var sway := Vector2.ZERO
var bob_time: float = 0.0
var wall_ray: RayCast3D
var lens_material: StandardMaterial3D
var bounce: OmniLight3D # luz muy débil que "rebota" y deja ver la mano

@onready var player: CharacterBody3D = owner as CharacterBody3D
@onready var flashlight: SpotLight3D = get_node_or_null("../Flashlight")


func _ready() -> void:
	rest_position = position
	rest_rotation = rotation
	# Las manos no proyectan sombra (si no, se ve una sombra rara frente a ti)
	for n in find_children("*", "GeometryInstance3D", true, false):
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Rayo hacia adelante para detectar paredes muy cercanas
	wall_ray = RayCast3D.new()
	wall_ray.target_position = Vector3(0, 0, -0.55)
	wall_ray.collision_mask = 1 # solo el mundo
	get_parent().add_child.call_deferred(wall_ray)
	_find_lens()
	bounce = OmniLight3D.new()
	bounce.light_energy = 0.12
	bounce.omni_range = 0.6
	bounce.light_color = Color(1, 0.9, 0.8)
	bounce.position = Vector3(-0.05, 0.08, -0.2)
	bounce.shadow_enabled = false
	add_child(bounce)


# Busca el material del lente dentro del modelo para prenderlo/apagarlo
func _find_lens() -> void:
	for mi in find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i) as StandardMaterial3D
			if m != null and m.resource_name == "LinternaLente":
				lens_material = m.duplicate()
				mi.set_surface_override_material(i, lens_material)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not GameState.input_locked:
		sway -= event.relative * sway_amount
		sway = sway.limit_length(sway_max)


func _process(delta: float) -> void:
	# El balanceo regresa al centro poco a poco
	sway = sway.lerp(Vector2.ZERO, 8.0 * delta)
	var speed := 0.0
	var running := false
	if player != null:
		speed = Vector2(player.velocity.x, player.velocity.z).length()
		running = player.get("running")
	# Bamboleo al caminar (ondas seno): más rápido y amplio al correr
	var amp := 0.0
	if speed > 0.2 and player.is_on_floor():
		bob_time += delta * (12.0 if running else 7.5)
		amp = bob_run if running else bob_walk
	else:
		bob_time += delta * 1.6 # respiración en reposo
		amp = 0.004
	var bob := Vector3(cos(bob_time * 0.5) * amp, -absf(sin(bob_time * 0.5)) * amp, 0)
	if speed <= 0.2:
		bob = Vector3(0, sin(bob_time) * amp, 0)
	# Al correr la linterna baja y se inclina
	var run_offset := Vector3(0.02, -0.04, 0.03) if running else Vector3.ZERO
	# Pared cerca: retrae la mano hacia la cámara
	var pull := 0.0
	if wall_ray != null and wall_ray.is_inside_tree() and wall_ray.is_colliding():
		var dist := wall_ray.global_position.distance_to(wall_ray.get_collision_point())
		pull = clampf(0.55 - dist, 0.0, 0.25)
	var target := rest_position + bob + run_offset + Vector3(sway.x, sway.y, pull)
	position = position.lerp(target, 14.0 * delta)
	var tilt := Vector3(sway.y * 1.5, sway.x * 1.5, sway.x * 2.0)
	if running:
		tilt += Vector3(-0.25, 0.15, 0.1)
	rotation = rotation.lerp(rest_rotation + tilt, 10.0 * delta)
	# La luz de la linterna sale del lente y sigue a la mano
	if flashlight != null:
		flashlight.transform = transform * Transform3D(Basis(), Vector3(0, 0, -0.12))
	# Lente encendido/apagado según la linterna
	if lens_material != null and flashlight != null:
		lens_material.emission_energy_multiplier = 4.0 if flashlight.visible else 0.0
	if bounce != null and flashlight != null:
		bounce.visible = flashlight.visible
