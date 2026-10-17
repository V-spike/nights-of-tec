extends CharacterBody3D

enum State { PATROL, CHASE }

@export var speed: float = 2.0
@export var path: Path3D

var state: State = State.PATROL
var path_offset: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


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


func move_toward_target(target: Vector3) -> void:
	var dir := global_position.direction_to(target)
	dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if dir != Vector3.ZERO:
		look_at(global_position + dir, Vector3.UP, true)
