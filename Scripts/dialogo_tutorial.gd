
extends Control

@onready var capa_dialogo: CanvasLayer = $CapaDialogo
@onready var fondo_oscuro: ColorRect = $CapaDialogo/FondoOscuro
@onready var panel_dialogo: Panel = $CapaDialogo/PanelDialogo
@onready var nombre_personaje: Label = $CapaDialogo/PanelDialogo/NombrePersonaje
@onready var texto_dialogo: RichTextLabel = $CapaDialogo/PanelDialogo/TextoDialogo
@onready var indicador_continuar: Label = $CapaDialogo/PanelDialogo/IndicadorContinuar
@onready var papa_arashi: Sprite2D = $CapaDialogo/PanelDialogo/PapaArashi

var dialogo_activo := false
var animacion_oscurecimiento: Tween

# Intensidad y duración del oscurecimiento
@export_range(0.0, 1.0, 0.05) var oscuridad := 0.55
@export var duracion_fundido := 0.4



func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Preparar el fondo oscuro
	fondo_oscuro.color = Color.BLACK
	fondo_oscuro.modulate.a = 0.0

	# Ocultar el diálogo inicialmente
	ocultar_dialogo()

	# Mostrar la introducción al comenzar el Tutorial
	call_deferred("mostrar_introduccion")


# =====================================
# INTRODUCCIÓN DEL PADRE
# =====================================

func mostrar_introduccion() -> void:
	mostrar_dialogo(
		"Padre",
		"Hola hijo, te enseñaré algunos movimientos básicos para enfrentarte a los retos que vendrán hacia ti."
	)



# =====================================
# CONTROLES DEL DIÁLOGO
# =====================================

func _input(event: InputEvent) -> void:
	if not dialogo_activo:
		return

	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_E:
			cerrar_dialogo()
			get_viewport().set_input_as_handled()


# =====================================
# MOSTRAR DIÁLOGO
# =====================================

func mostrar_dialogo(nombre: String, texto: String) -> void:
	if dialogo_activo:
		return

	nombre_personaje.text = nombre
	texto_dialogo.text = texto

	capa_dialogo.show()
	fondo_oscuro.show()
	panel_dialogo.show()
	papa_arashi.show()
	indicador_continuar.show()

	dialogo_activo = true

	# Pausar el juego
	get_tree().paused = true

	# Empezar el fondo transparente
	fondo_oscuro.modulate.a = 0.0

	# Animar oscurecimiento
	if animacion_oscurecimiento:
		animacion_oscurecimiento.kill()

	animacion_oscurecimiento = create_tween()
	animacion_oscurecimiento.tween_property(
		fondo_oscuro,
		"modulate:a",
		oscuridad,
		duracion_fundido
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# =====================================
# CERRAR DIÁLOGO
# =====================================

func cerrar_dialogo() -> void:
	if not dialogo_activo:
		return

	dialogo_activo = false

	if animacion_oscurecimiento:
		animacion_oscurecimiento.kill()

	# Ocultar el panel y el retrato
	panel_dialogo.hide()
	papa_arashi.hide()

	# Recuperar el brillo del escenario
	animacion_oscurecimiento = create_tween()
	animacion_oscurecimiento.tween_property(
		fondo_oscuro,
		"modulate:a",
		0.0,
		duracion_fundido
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await animacion_oscurecimiento.finished

	ocultar_dialogo()

	# Reanudar el juego
	get_tree().paused = false


# =====================================
# OCULTAR INTERFAZ
# =====================================

func ocultar_dialogo() -> void:
	capa_dialogo.hide()
	dialogo_activo = false
