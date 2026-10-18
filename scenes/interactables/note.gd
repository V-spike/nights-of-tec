class_name Note
extends Interactable

@export_multiline var note_text: String = ""
@export var new_objective: String = "Salir"
@export var ends_demo: bool = false

var finished: bool = false

func interact() -> void:
	GameState.note_opened.emit(note_text)
	print("Nota: ", note_text)
	if new_objective != "":
		GameState.objective_changed.emit(new_objective)
	if ends_demo and not finished:
		finished = true
		await get_tree().create_timer(6.0).timeout
		print("Demo terminada")
		GameState.level_won.emit()
