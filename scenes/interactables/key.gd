extends Interactable

@export var key_id: String = ""

func interact() -> void:
	GameState.add_key(key_id)
	GameState.hint_shown.emit("Has tomado una llave.")
	print("Has tomado una llave. ", key_id)
	queue_free()
