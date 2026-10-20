
extends Area2D

# Evita repetir el diálogo
var dialogo_mostrado := false

@onready var dialogo = $"../DialogoTutorial"


func _ready() -> void:
	# Conectar automáticamente la detección
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	# Evitar que se active varias veces
	if dialogo_mostrado:
		return

	# Comprobar que sea Arashi
	if not body.is_in_group("player"):
		return

	dialogo_mostrado = true

	# Mostrar al padre explicando el salto
	dialogo.mostrar_dialogo(
		"Padre",
		"Arashi, para cruzar este hueco deberás saltar. Presioná ESPACIO para llegar al otro lado."
	)
