extends AudioStreamPlayer
# =============================================================================
# Reproduce un sonido en bucle (música o ambiente) y entra con un fade-in.
# Úsalo en un AudioStreamPlayer: pon el sonido en "stream", el bus y listo.
# =============================================================================

@export var fade_in_time: float = 2.5 # segundos que tarda en subir el volumen

func _ready() -> void:
	if stream == null:
		return
	# Duplicamos el stream para activar el bucle sin tocar el archivo original
	stream = stream.duplicate()
	if "loop" in stream:
		stream.loop = true
	var target := volume_db
	volume_db = -60.0
	play()
	var tween := create_tween()
	tween.tween_property(self, "volume_db", target, fade_in_time)
