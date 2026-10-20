
extends Area2D

# Evitar que el diálogo se repita
var dialogo_mostrado := false

@onready var dialogo = $"../DialogoTutorial"


func _ready() -> void:
	# Detectar cuando Arashi entra en la zona
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	# No repetir el diálogo
	if dialogo_mostrado:
		return

	# Solo activar si entra Arashi
	if not body.is_in_group("player"):
		return

	dialogo_mostrado = true

	# Enseñar la técnica del doble salto
	dialogo.mostrar_dialogo(
		"Padre",
		"Te enseñaré la técnica del doble salto. Pulsá dos veces ESPACIO para realizarlo."
)
