
extends Area2D

# Evitar que el diálogo se repita
var dialogo_mostrado := false

@onready var dialogo = $"../DialogoTutorial"


func _ready() -> void:
	# Detectar cuando Arashi entra en la zona
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	# Evitar repetir el diálogo
	if dialogo_mostrado:
		return

	# Comprobar que sea Arashi
	if not body.is_in_group("player"):
		return

	dialogo_mostrado = true

	# Enseñar el Dash de Viento
	dialogo.mostrar_dialogo(
		"Padre",
		"Para cruzar este precipicio deberás utilizar la técnica Dash de Viento. Pulsá dos veces ESPACIO para realizar el doble salto y luego SHIFT para impulsarte por el aire."
	)
