class_name Door
extends Interactable

@export var key_id: String = ""
@export var open_angle: float = 90.0

var is_open: bool = false

func interact() -> void:
	if is_open:
		return
	if key_id != "" and not GameState.has_key(key_id):
		GameState.hint_shown.emit("Está cerrada. Necesitas una llave.")
		print("Está cerrada. Necesitas una llave.") 
		$LockedSound.play()
		return
	open()
	
func open() -> void:
	is_open = true
	$OpenSound.play()
	var tween := create_tween()
	tween.tween_property(self,"rotation_degrees:y", rotation_degrees.y + open_angle, 1.0)
