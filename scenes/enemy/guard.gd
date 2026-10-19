extends CharacterBody3D

enum State { PATROL, CHASE }

@export var speed: float = 2.0
@export var path: Path3D
@export var view_distance: float = 8.0
@export var view_angle: float = 45.0

var state: State = State.PATROL
var path_offset: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var player: Node3D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	if state == State.PATROL:
		patrol()
	move_and_slide()


func patrol() -> void:
	if path == null:
		return
	var curve := path.curve
	var target := path.to_global(curve.sample_baked(path_offset))
	target.y = global_position.y
	if global_position.distance_to(target) < 0.5:
		path_offset = fmod(path_offset + 1.0, curve.get_baked_length())
	move_toward_target(target)

func can_see_player() -> bool:
	if player == null:
		return false
	var to_player := global_position.direction_to(player.global_position)
	if global_position.distance_to(player.global_position) > view_distance:
		return false
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


func move_toward_target(target: Vector3) -> void:
	var dir := global_position.direction_to(target)
	dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if dir != Vector3.ZERO:
		look_at(global_position + dir, Vector3.UP, true)
