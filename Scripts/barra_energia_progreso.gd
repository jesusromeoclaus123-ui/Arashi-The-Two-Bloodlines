extends TextureProgressBar

# Arrastra el nodo Arashi de la escena Tutorial hasta esta propiedad
# en el Inspector de BarraEnergiaProgreso.
@export var arashi: CharacterBody2D


func _ready() -> void:
	if arashi == null:
		push_warning("Asigná el nodo Arashi a la propiedad 'arashi' de esta barra.")
		return

	# La barra consulta la energia inicial y escucha sus modificaciones.
	min_value = 0.0
	max_value = arashi.get("energia_maxima")
	value = arashi.get("energia_actual")
	arashi.connect("energia_cambiada", _on_energia_cambiada)


func _on_energia_cambiada(actual: float, maxima: float) -> void:
	max_value = maxima
	value = actual
