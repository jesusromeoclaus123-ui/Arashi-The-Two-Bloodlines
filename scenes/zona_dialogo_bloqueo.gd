
extends Area2D

var dialogo_mostrado := false

@onready var dialogo = $"../DialogoTutorial"
@onready var indicador_bloqueos = $"../IndicadorBloqueos"


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if dialogo_mostrado:
		return

	if not body.is_in_group("player"):
		return

	dialogo_mostrado = true

	# Mostrar el diálogo del padre.
	dialogo.mostrar_dialogo(
		"Padre",
		"Bien hecho, hijo. Ahora aprenderás a defenderte. Mantené presionada L para bloquear los ataques del enemigo. ¡Bloqueá tres golpes para superar este entrenamiento!"
	)

	# Esperar a que termine el diálogo.
	esperar_fin_dialogo()


func esperar_fin_dialogo() -> void:
	# Esperar mientras el diálogo esté activo
	# o el juego permanezca pausado.
	while is_instance_valid(dialogo) and (dialogo.dialogo_activo or get_tree().paused):
		await get_tree().process_frame

	# Cuando termine el diálogo, activar el entrenamiento.
	if is_inside_tree() and is_instance_valid(indicador_bloqueos):
		indicador_bloqueos.empezar_entrenamiento()
