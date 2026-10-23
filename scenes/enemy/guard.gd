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
var has_caught: bool = false
var player: Node3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	if has_caught:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if state == State.PATROL:
		patrol()
		if can_see_player():
			state = State.CHASE
			lose_timer = 0.0
	elif state == State.CHASE:
		chase(delta)
	move_and_slide()


func patrol() -> void:
	if path == null:
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
		has_caught = true
		print("¡Te atrapé!")
		GameState.player_caught.emit()
		return
	if can_see_player():
		lose_timer = 0.0
	else:
		lose_timer += delta
		if lose_timer >= lose_time:
			lose_timer = 0.0
			state = State.PATROL


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
