
extends Area2D

var dialogo_mostrado: bool = false

@onready var dialogo = $"../DialogoTutorial"


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if dialogo_mostrado:
		return

	if not body.is_in_group("player"):
		return

	if not is_instance_valid(dialogo):
		push_warning("No se encontró DialogoTutorial.")
		return

	dialogo_mostrado = true

	# El padre explica cómo utilizar el rayo.
	dialogo.mostrar_dialogo(
		"Padre",
		"Excelente, hijo. Ya aprendiste a defenderte, pero no siempre podrás acercarte a tus enemigos. Para enfrentarte a quienes estén lejos, presioná J y utilizá el poder del rayo. ¡Ahora demuéstrame lo que has aprendido!"
	)
