extends CharacterBody3D

enum State { PATROL, CHASE, SEARCH }

@export var speed: float = 1.9
@export var chase_speed: float = 3.6
@export var path: Path3D
@export var view_distance: float = 8.0
@export var view_angle: float = 45.0
@export var catch_distance: float = 1.0
@export var search_time: float = 4.0 # segundos mirando alrededor donde te perdió de vista
@export var give_up_time: float = 10.0 # si no logra llegar a tu última posición, se rinde
@export var hearing_range: float = 6.0 # si corres a esta distancia o menos, te escucha
@export var chase_volume_db: float = -8.0
@export var step_distance: float = 1.4 # metros entre pisadas

var state: State = State.PATROL
var waypoint: int = 0 # punto de la ruta al que va
var last_seen: Vector3 # último lugar donde te vio
var search_timer: float = 0.0
var look_timer: float = 0.0
var stuck_timer: float = 0.0
var stuck_check: Vector3 # dónde estaba en la última revisión de atasco
var catching: bool = false # candado: true mientras dura la captura
var player: Node3D
var player_head: Node3D
var music: AudioStreamPlayer # música de persecución
var steps: AudioStreamPlayer3D # pasos que se oyen desde donde está
var step_travel: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var anim: AnimationPlayer = $Model/AnimationPlayer
@onready var agent: NavigationAgent3D = $Agent

func _ready() -> void:
	add_to_group("guard")
	player = get_tree().get_first_node_in_group("player")
	if player != null:
		player_head = player.get_node_or_null("Head")
	# La música de persecución empieza callada y se repite sola
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/audio/persecucion.wav")
	music.volume_db = -40.0
	music.finished.connect(music.play)
	add_child(music)
	# Pasos pesados en 3D: se oyen más fuerte y del lado donde está el guardia
	var random_steps := AudioStreamRandomizer.new()
	for f in ["footstep00", "footstep02", "footstep04"]:
		random_steps.add_stream(-1, load("res://assets/audio/" + f + ".ogg"))
	random_steps.random_pitch = 1.1
	steps = AudioStreamPlayer3D.new()
	steps.stream = random_steps
	steps.volume_db = -12.0
	steps.pitch_scale = 0.75
	steps.unit_size = 3.0
	steps.max_distance = 18.0
	steps.position.y = 0.1
	add_child(steps)


func _physics_process(delta: float) -> void:
	update_music(delta)
	# Durante la captura el guardia no hace nada
	if catching:
		play_anim("idle")
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	match state:
		State.PATROL:
			patrol(delta)
			if can_see_player():
				start_chase()
			elif can_hear_player():
				start_search(player.global_position)
		State.CHASE:
			chase()
		State.SEARCH:
			search(delta)
			if can_see_player():
				start_chase()
			elif can_hear_player():
				start_search(player.global_position)
	move_and_slide()
	update_steps(delta)
	# Animación según lo que esté haciendo
	if state == State.CHASE:
		play_anim("run")
	elif velocity.x == 0.0 and velocity.z == 0.0:
		play_anim("idle")
	else:
		play_anim("walk")


func start_chase() -> void:
	state = State.CHASE
	last_seen = player.global_position


# Te escuchó correr: va a revisar ese lugar (camina, no te persigue)
func start_search(where: Vector3) -> void:
	state = State.SEARCH
	last_seen = where
	search_timer = 0.0
	look_timer = 0.0


# Ronda: va de punto en punto de GuardPath; el mapa de navegación lo lleva por pasillos y puertas
func patrol(delta: float) -> void:
	if path == null or path.curve == null or path.curve.point_count == 0:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var target := waypoint_position(waypoint)
	# Cada 2 s revisa si avanzó; si algo le estorba, se salta al siguiente punto
	stuck_timer += delta
	var stuck := false
	if stuck_timer >= 2.0:
		stuck = flat_distance(stuck_check) < 0.3
		stuck_check = global_position
		stuck_timer = 0.0
	if flat_distance(target) < 0.7 or stuck:
		waypoint = (waypoint + 1) % path.curve.point_count
		target = waypoint_position(waypoint)
	move_toward_target(target, speed)


# Persecución: solo mientras te ve
func chase() -> void:
	if player == null:
		state = State.PATROL
		return
	if can_see_player():
		last_seen = player.global_position
		move_toward_target(last_seen, chase_speed)
		if global_position.distance_to(player.global_position) < catch_distance:
			catch_player()
	else:
		# Te perdió de vista: ya no te persigue, camina a donde te vio por última vez
		start_search(last_seen)


# Búsqueda: camina (sin correr) a tu última posición, mira alrededor y vuelve a su ronda
func search(delta: float) -> void:
	search_timer += delta
	if flat_distance(last_seen) > 0.8 and search_timer < give_up_time:
		move_toward_target(last_seen, speed)
		return
	velocity.x = 0.0
	velocity.z = 0.0
	look_timer += delta
	rotate_y(sin(look_timer * 2.0) * 1.5 * delta)
	if look_timer >= search_time:
		waypoint = closest_waypoint()
		state = State.PATROL


func catch_player() -> void:
	catching = true
	velocity = Vector3.ZERO
	music.stop()
	# Voltea a verte a la cara para el screamer
	var face := player.global_position
	face.y = global_position.y
	if flat_distance(face) > 0.01:
		look_at(face, Vector3.UP, true)
	print("¡Te atrapé!")
	# Segunda captura: game over (si está activado)
	if GameState.game_over_enabled and GameState.second_chance_used:
		GameState.game_over.emit()
		return
	GameState.second_chance_used = true
	GameState.player_caught.emit()
	# Espera a que pase el screamer y la pantalla esté negra
	await get_tree().create_timer(1.3).timeout
	# Se va a la mitad de su ruta, lejos del jugador
	if path != null and path.curve != null and path.curve.point_count > 0:
		waypoint = int(path.curve.point_count / 2.0)
		global_position = waypoint_position(waypoint)
	state = State.PATROL
	# Espera a que la pantalla vuelva y suelta el candado
	await get_tree().create_timer(1.0).timeout
	catching = false


func move_toward_target(target: Vector3, move_speed: float) -> void:
	# El agente calcula el camino por el mapa (rodea muros, mesas y separadores)
	agent.target_position = target
	var next := agent.get_next_path_position()
	# Sin mapa de navegación (escenas de prueba) camina en línea recta
	if global_position.distance_to(next) < 0.05:
		next = target
	var dir := global_position.direction_to(next)
	dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	if dir != Vector3.ZERO:
		look_at(global_position + dir, Vector3.UP, true)


func can_see_player() -> bool:
	if player == null:
		return false
	var max_distance := view_distance
	if player.get("crouching"):
		max_distance = view_distance / 2.0
	if global_position.distance_to(player.global_position) > max_distance:
		return false
	var to_player := global_position.direction_to(player.global_position)
	var forward := global_transform.basis.z
	var angle := rad_to_deg(forward.angle_to(to_player))
	if angle > view_angle:
		return false
	# Mira a tu cabeza: agachado detrás de una ventana o un separador no te ve
	var eyes := global_position + Vector3(0, 1.6, 0)
	var player_eyes := player.global_position + Vector3(0, 1.0, 0)
	if player_head != null:
		player_eyes = player_head.global_position
	var query := PhysicsRayQueryParameters3D.create(eyes, player_eyes)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == player


# Te escucha si corres dentro de su rango (el oído atraviesa paredes)
func can_hear_player() -> bool:
	if player == null or not player.get("running"):
		return false
	return global_position.distance_to(player.global_position) <= hearing_range


# Suena un paso cada step_distance metros recorridos (más seguidos al correr)
func update_steps(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if horizontal_speed < 0.1:
		return
	step_travel += horizontal_speed * delta
	if step_travel >= step_distance:
		step_travel = 0.0
		steps.play()


# Sube la música mientras te persigue y la apaga poco a poco cuando te pierde
func update_music(delta: float) -> void:
	if state == State.CHASE and not catching:
		if not music.playing:
			music.play()
		music.volume_db = move_toward(music.volume_db, chase_volume_db, 40.0 * delta)
	elif music.playing:
		music.volume_db = move_toward(music.volume_db, -40.0, 8.0 * delta)
		if music.volume_db <= -40.0:
			music.stop()


func waypoint_position(i: int) -> Vector3:
	var p := path.to_global(path.curve.get_point_position(i))
	p.y = global_position.y
	return p


func flat_distance(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func closest_waypoint() -> int:
	var best := 0
	var best_d := INF
	for i in path.curve.point_count:
		var d := flat_distance(waypoint_position(i))
		if d < best_d:
			best_d = d
			best = i
	return best


# Cambia la animación solo si es distinta a la que ya suena
func play_anim(anim_name: String) -> void:
	if anim.current_animation != anim_name:
		anim.play(anim_name)
