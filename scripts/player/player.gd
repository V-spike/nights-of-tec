extends CharacterBody3D
@export var crouch_speed: float = 1.5
@export var stand_head_height: float = 1.6
@export var crouch_head_height: float = 1.0
#¿está agachado? el guardia lo lee
var crouching: bool = false
#declaracion de estamina, velocidad al caminar, velocidad al correr
@export var walk_speed: float = 3.0
@export var run_speed: float = 5.5
@export var stamina_drain: float = 0.25
@export var stamina_regen: float = 0.15
@export var stamina_recover_at: float = 0.3
@export var step_distance: float = 1.3 #metros entre pisadas
@export var step_volume_db: float = -32.0 #más negativo = más bajito
#Cansancio del jugador
var exhausted: bool = false
#Estamina del jugador maximo 1
var stamina: float = 1.0
#aviso de stamina para hud
var last_stamina: float = 1.0
#gravedad del juego
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@export var mouse_sensitivity: float = 0.002
@onready var head: Node3D = $Head
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var footsteps: AudioStreamPlayer = $Footsteps
var step_travel: float = 0.0 #metros recorridos desde la última pisada

#Cuando nace el jugador, esconde el cursor
func _ready() -> void: 
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	#escucha la señal de captura del guardia
	GameState.player_caught.connect(_on_caught)
	GameState.game_over.connect(_on_game_over)
		# Al nacer, ir al PlayerSpawn de lab_start
	var spawn := get_tree().get_first_node_in_group("player_spawn") as Node3D
	if spawn != null:
		global_position = spawn.global_position
		rotation.y = spawn.global_rotation.y
#cuando el usuario presiona una tecla o mueve el mouse
func _unhandled_input(event: InputEvent) -> void:
	#pregunta si la entrada es "esc" asociada a ui cancel, activa el cursor
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if GameState.input_locked:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		#clamp es un minimo y un maximo, detiene la rotacion si se llega al min o max
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))
	if event.is_action_pressed("flashlight"):
		flashlight.visible = not flashlight.visible
		
	if event.is_action_pressed("interact"):
		if interact_ray.is_colliding():
			var target = interact_ray.get_collider()
			if target is Interactable:
				target.interact()		
func _physics_process(delta: float) -> void:
	#1. Gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta
	#2. leer teclas
	var input_dir := Vector2.ZERO
	#Si el candado no está puesto, puede moverse el jugador
	if not GameState.input_locked:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	#direccion del mundo 
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	#velocidad actual 
	#Pregunta si esta corriendo shift: presionado y dir: distinta a quieta
	crouching = Input.is_action_pressed("crouch") and not GameState.input_locked
	var running := Input.is_action_pressed("run") and input_dir != Vector2.ZERO and not exhausted and not crouching
	var speed := walk_speed
	if running:
		speed = run_speed
	elif crouching:
		speed = crouch_speed
	if running:
		stamina -= stamina_drain * delta
	else:
		stamina += stamina_regen * delta
	stamina = clamp(stamina, 0.0, 1.0)
	#si estamina es llega a 0, el jugador pasa a estar cansado 
	if stamina <= 0.0:
		exhausted = true
	elif stamina >= stamina_recover_at: 
		exhausted = false
	if stamina != last_stamina:
		GameState.stamina_changed.emit(stamina)
		last_stamina = stamina
	#velocidad  x/z con  speed, multiplica. 
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
		#baja o sube la cámara poco a poco
	var head_target := crouch_head_height if crouching else stand_head_height
	head.position.y = lerp(head.position.y, head_target, 10.0 * delta)
	move_and_slide()
		#pasos: más seguidos al correr, más lentos y bajitos agachado
		#pasos por distancia: más rápido = más seguido, chocando = nada
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horizontal_speed > 0.1:
		step_travel += horizontal_speed * delta
		if step_travel >= step_distance:
			step_travel = 0.0
			footsteps.volume_db = step_volume_db - 10.0 if crouching else step_volume_db
			footsteps.play()
	else:
		step_travel = step_distance
#el guardia te atrapó: bloquear, teletransportar y soltar
func _on_caught() -> void:
	GameState.input_locked = true
	#espera a que la pantalla esté negra
	await get_tree().create_timer(0.6).timeout
	var respawn := get_tree().get_first_node_in_group("capture_respawn") as Node3D
	if respawn == null:
		push_warning("Falta un Marker3D en el grupo capture_respawn")
	else:
		global_position = respawn.global_position
		rotation.y = respawn.global_rotation.y
	head.rotation.x = 0.0
	velocity = Vector3.ZERO
	stamina = 1.0
	exhausted = false
	GameState.stamina_changed.emit(stamina)
	#espera a que la pantalla vuelva y suelta el candado
	await get_tree().create_timer(1.4).timeout
	GameState.input_locked = false
#segunda captura: congelar, esperar y reiniciar todo
func _on_game_over() -> void:
	GameState.input_locked = true
	await get_tree().create_timer(1.5).timeout
	GameState.reset()
	get_tree().reload_current_scene()
