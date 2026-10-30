extends Area3D
# Zona de susto: la primera vez que el jugador entra, la niña aparece frente a su cara

@export var show_time: float = 1.2 # segundos que se queda la niña
@export var face_distance: float = 1.1 # qué tan cerca aparece

var used: bool = false # el susto solo pasa una vez
@onready var nina: Node3D = $Nina
@onready var scream: AudioStreamPlayer = $Scream


func _ready() -> void:
	nina.hide()
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if used or not body.is_in_group("player"):
		return
	used = true
	var camera := get_viewport().get_camera_3d()
	# Frente a la cámara, parada en el piso donde está el jugador
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var spot := camera.global_position + forward * face_distance
	spot.y = body.global_position.y
	nina.global_position = spot
	nina.look_at(Vector3(camera.global_position.x, spot.y, camera.global_position.z), Vector3.UP, true)
	nina.show()
	GameState.input_locked = true
	scream.play()
	if body.has_method("shake_camera"):
		body.shake_camera(0.7)
	# Se abalanza un poco hacia ti
	var tween := create_tween()
	tween.tween_property(nina, "global_position", spot - forward * 0.45, 0.15)
	await get_tree().create_timer(show_time).timeout
	nina.hide()
	GameState.input_locked = false
