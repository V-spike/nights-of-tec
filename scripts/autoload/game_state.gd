extends Node #GameState nodo invisible que siempre existe
#Señales: avisa que otras partes del juego pueden escuchar
signal note_opened(text: String) #se leyó una nota; texto
signal stamina_changed(value: float) #cambió la stamina; lleva valores de 0.0 a 1.0
signal objective_changed(text: String) #cambió el objetivo en pantalla
signal player_caught #el guardia atrapó al jugador
signal game_over #segunda captura:fin
signal level_won #el jugador llegó a la salida.
signal hint_shown(text: String) #muestra texto de ayuda en pantalla

#Variables: lo que el juego recuerda
var keys: Array[String] = []  #llaves que tiene el jugador
var clues: Array[String] = [] #pistas encontradas
var second_chance_used: bool = false #¿ya lo atraparon?
var input_locked: bool = false #entrada congelada 

#Guarda una llave nueva en la lista
func add_key(id: String) -> void:
	keys.append(id)

#Responde true si la llave está en la lista, false si no 
func has_key(id: String) -> bool:
	return keys.has(id)
	
#Guarda una pista nueva
func add_clue(id: String) -> void:
	clues.append(id)
#deja todo como al inicio
func reset()-> void:
	keys.clear()
	clues.clear()
	second_chance_used = false
	input_locked = false
