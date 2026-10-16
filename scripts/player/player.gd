extends CharacterBody3D
#declaracion de estamina, velocidad al caminar, velocidad al correr
@export var walk_speed: float = 3.0
@export var run_speed: float = 5.5
@export var stamina_drain: float = 0.25
@export var stamina_regen: float = 0.15
@export var stamina_recover_at: float = 0.3


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

#Cuando nace el jugador, esconde el cursor
func _ready() -> void: 
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
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
	var running := Input.is_action_pressed("run") and input_dir != Vector2.ZERO and not exhausted
	var speed := walk_speed
	if running:
		speed = run_speed
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
	move_and_slide()
