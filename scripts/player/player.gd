extends CharacterBody3D

@export var walk_speed: float = 3.0
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
	#velocidad  x/z con walk speed, multiplica. 
	velocity.x = direction.x * walk_speed
	velocity.z = direction.z * walk_speed
	move_and_slide()
