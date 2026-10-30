extends Door
# Puerta doble de vidrio de la entrada principal: abre las dos hojas hacia afuera y termina el demo

@export var win_delay: float = 1.5

func open() -> void:
	is_open = true
	$OpenSound.play()
	$CollisionShape3D.set_deferred("disabled", true)
	var tween := create_tween().set_parallel()
	tween.tween_property($LeafLeft, "rotation_degrees:y", open_angle, 1.0)
	tween.tween_property($LeafRight, "rotation_degrees:y", -open_angle, 1.0)
	GameState.objective_changed.emit("¡Sal del edificio!")
	await get_tree().create_timer(win_delay).timeout
	GameState.level_won.emit()
