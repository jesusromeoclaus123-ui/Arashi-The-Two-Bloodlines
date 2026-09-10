extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:

	if body.has_method("activar_bandera"):

		# Guardar el checkpoint
		body.activar_bandera(global_position)

		print("CHECKPOINT ACTIVADO: ", global_position)

		# Desaparecer la bandera completa
		hide()

		# Desactivar la detección
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
