extends TextureProgressBar

# Arrastra el nodo Arashi a esta propiedad desde la escena Tutorial.
@export var arashi: CharacterBody2D


func _ready() -> void:
	if arashi == null:
		push_warning("Asigna el nodo Arashi a la propiedad 'arashi' de BarraVidaProgreso.")
		return

	# Leer el valor inicial (aunque el HUD se instancie despues del jugador).
	min_value = 0.0
	max_value = arashi.get("vida_maxima")
	value = arashi.get("vida_actual")

	# Refrescar la barra solo cuando cambia la vida.
	if arashi.has_signal("vida_cambiada"):
		if not arashi.is_connected("vida_cambiada", _on_vida_cambiada):
			arashi.connect("vida_cambiada", _on_vida_cambiada)
	else:
		push_warning("El nodo asignado no tiene la senal vida_cambiada.")


func _on_vida_cambiada(actual: float, maxima: float) -> void:
	max_value = maxima
	value = actual
