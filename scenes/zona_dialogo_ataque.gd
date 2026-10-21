
extends Area2D

# Evitar que el dialogo aparezca varias veces
var dialogo_mostrado := false

@onready var dialogo = $"../DialogoTutorial"


func _ready() -> void:
	# Detectar cuando Arashi entra en la zona
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	# Evitar repetir el dialogo
	if dialogo_mostrado:
		return

	# Comprobar que sea Arashi
	if not body.is_in_group("player"):
		return

	dialogo_mostrado = true

	# Explicacion del combate basico
	dialogo.mostrar_dialogo(
		"Padre",
		"Bien hecho, hijo. Ahora tendrás que aprender a combatir. Presioná K para atacar y pulsala varias veces para realizar un combo de hasta tres golpes. ¡Ahora ponelo en práctica con ese enemigo!"
	)
