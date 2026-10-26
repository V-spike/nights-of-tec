extends CharacterBody3D

enum State { PATROL, CHASE }

@export var speed: float = 2.0
@export var chase_speed: float = 3.5
@export var path: Path3D
@export var view_distance: float = 8.0
@export var view_angle: float = 45.0
@export var lose_time: float = 3.0
@export var catch_distance: float = 1.0

var state: State = State.PATROL
var path_offset: float = 0.0
var lose_timer: float = 0.0
var catching: bool = false # candado: true mientras dura la captura
var player: Node3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var anim: AnimationPlayer = $Model/AnimationPlayer

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	# Durante la captura el guardia no hace nada
	if catching:
		play_anim("idle")
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	if state == State.PATROL:
		patrol()
		if can_see_player():
			state = State.CHASE
			lose_timer = 0.0
	elif state == State.CHASE:
		chase(delta)
	move_and_slide()
	# Animación según lo que esté haciendo
	if state == State.CHASE:
		play_anim("run")
	elif velocity.x == 0.0 and velocity.z == 0.0:
		play_anim("idle")
	else:
		play_anim("walk")


func patrol() -> void:
	# Sin ruta, o con una ruta sin puntos, el guardia se queda quieto
	if path == null or path.curve == null or path.curve.get_baked_length() == 0.0:
		return
	var curve := path.curve
	var target := path.to_global(curve.sample_baked(path_offset))
	target.y = global_position.y
	if global_position.distance_to(target) < 0.5:
		path_offset = fmod(path_offset + 1.0, curve.get_baked_length())
	move_toward_target(target, speed)


func chase(delta: float) -> void:
	if player == null:
		state = State.PATROL
		return
	move_toward_target(player.global_position, chase_speed)
	if global_position.distance_to(player.global_position) < catch_distance:
		catch_player()
		return
	if can_see_player():
		lose_timer = 0.0
	else:
		lose_timer += delta
		if lose_timer >= lose_time:
			lose_timer = 0.0
			state = State.PATROL


func catch_player() -> void:
	catching = true
	velocity = Vector3.ZERO
	print("¡Te atrapé!")
		# Segunda captura: game over (si está activado)
	if GameState.game_over_enabled and GameState.second_chance_used:
		GameState.game_over.emit()
		return
	GameState.second_chance_used = true
	GameState.player_caught.emit()
	# Espera a que la pantalla esté negra
	await get_tree().create_timer(0.6).timeout
	# Se va a la mitad de su ruta: el fondo del pasillo
	if path != null:
		path_offset = path.curve.get_baked_length() / 2.0
		global_position = path.to_global(path.curve.sample_baked(path_offset))
	state = State.PATROL
	lose_timer = 0.0
	# Espera a que la pantalla vuelva y suelta el candado
	await get_tree().create_timer(1.4).timeout
	catching = false


func move_toward_target(target: Vector3, move_speed: float) -> void:
	var dir := global_position.direction_to(target)
	dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	if dir != Vector3.ZERO:
		look_at(global_position + dir, Vector3.UP, true)


func can_see_player() -> bool:
	if player == null:
		return false
	if global_position.distance_to(player.global_position) > view_distance:
		return false
	var to_player := global_position.direction_to(player.global_position)
	var forward := global_transform.basis.z
	var angle := rad_to_deg(forward.angle_to(to_player))
	if angle > view_angle:
		return false
	var eyes := global_position + Vector3(0, 1.0, 0)
	var player_eyes := player.global_position + Vector3(0, 1.0, 0)
	var query := PhysicsRayQueryParameters3D.create(eyes, player_eyes)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == player


# Cambia la animación solo si es distinta a la que ya suena
func play_anim(anim_name: String) -> void:
	if anim.current_animation != anim_name:
		anim.play(anim_name)
