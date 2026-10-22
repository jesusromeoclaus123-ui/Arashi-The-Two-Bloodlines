

extends Control

@onready var capa_dialogo: CanvasLayer = $CapaDialogo
@onready var fondo_oscuro: ColorRect = $CapaDialogo/FondoOscuro
@onready var panel_dialogo: Panel = $CapaDialogo/PanelDialogo
@onready var nombre_personaje: Label = $CapaDialogo/PanelDialogo/NombrePersonaje
@onready var texto_dialogo: RichTextLabel = $CapaDialogo/PanelDialogo/TextoDialogo
@onready var indicador_continuar: Label = $CapaDialogo/PanelDialogo/IndicadorContinuar
@onready var papa_arashi: Sprite2D = $CapaDialogo/PanelDialogo/PapaArashi

# SONIDOS DEL DIALOGO
@onready var sonido_abrir_dialogo: AudioStreamPlayer = $SonidoAbrirDialogo
@onready var sonido_cerrar_dialogo: AudioStreamPlayer = $SonidoCerrarDialogo

# MUSICA DEL TUTORIAL
@onready var musica_tutorial: AudioStreamPlayer = get_node_or_null("../MusicaTutorial") as AudioStreamPlayer

# TRANSICION CINEMATOGRAFICA
@onready var transicion_entrada: CanvasLayer = $TransicionEntrada
@onready var pantalla_entrada: ColorRect = $TransicionEntrada/PantallaNegra

var titulo_cinematico: Label
var banda_superior: ColorRect
var banda_inferior: ColorRect

var dialogo_activo := false
var animacion_oscurecimiento: Tween
var entrada_en_curso := true

# CONFIGURACION DE DIALOGOS
@export_range(0.0, 1.0, 0.05) var oscuridad := 0.55
@export var duracion_fundido := 0.4

# CONFIGURACION CINEMATOGRAFICA
@export var espera_inicial: float = 0.25
@export var duracion_titulo: float = 0.65
@export var espera_titulo: float = 0.45
@export var duracion_entrada: float = 2.2
@export var duracion_bandas: float = 0.65

@export var texto_cinematico: String = "EL ENTRENAMIENTO HA COMENZADO"

# CONFIGURACION DE LA MUSICA
@export_range(-60.0, 0.0, 1.0) var volumen_musica_final: float = -24.0
@export_range(0.5, 8.0, 0.1) var duracion_entrada_musica: float = 3.0


# =====================================
# INICIO
# =====================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Permitir sonidos durante las pausas
	sonido_abrir_dialogo.process_mode = Node.PROCESS_MODE_ALWAYS
	sonido_cerrar_dialogo.process_mode = Node.PROCESS_MODE_ALWAYS

	# Preparar la musica del Tutorial
	if musica_tutorial != null:
		musica_tutorial.process_mode = Node.PROCESS_MODE_ALWAYS
		musica_tutorial.stop()
		musica_tutorial.volume_db = -60.0
	else:
		push_warning("No se encontro el nodo MusicaTutorial.")

	# Preparar dialogos
	fondo_oscuro.color = Color.BLACK
	fondo_oscuro.modulate.a = 0.0
	ocultar_dialogo()

	# La capa cinematografica queda encima del escenario
	transicion_entrada.layer = 100

	# Comenzar completamente negro
	pantalla_entrada.color = Color.BLACK
	pantalla_entrada.modulate.a = 1.0
	pantalla_entrada.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pantalla_entrada.show()

	# Congelar el juego durante la presentacion
	get_tree().paused = true

	# Crear elementos visuales
	crear_elementos_cinematograficos()

	# Empezar la secuencia
	call_deferred("iniciar_transicion_entrada")


# =====================================
# CREAR ELEMENTOS CINEMATOGRAFICOS
# =====================================

func crear_elementos_cinematograficos() -> void:
	var alto_pantalla: float = get_viewport_rect().size.y
	var altura_banda: float = alto_pantalla * 0.08

	# BANDA NEGRA SUPERIOR
	banda_superior = ColorRect.new()
	banda_superior.name = "BandaCineSuperior"
	banda_superior.color = Color.BLACK
	banda_superior.mouse_filter = Control.MOUSE_FILTER_IGNORE

	transicion_entrada.add_child(banda_superior)

	banda_superior.anchor_left = 0.0
	banda_superior.anchor_top = 0.0
	banda_superior.anchor_right = 1.0
	banda_superior.anchor_bottom = 0.0

	banda_superior.offset_left = 0.0
	banda_superior.offset_top = 0.0
	banda_superior.offset_right = 0.0
	banda_superior.offset_bottom = altura_banda

	# BANDA NEGRA INFERIOR
	banda_inferior = ColorRect.new()
	banda_inferior.name = "BandaCineInferior"
	banda_inferior.color = Color.BLACK
	banda_inferior.mouse_filter = Control.MOUSE_FILTER_IGNORE

	transicion_entrada.add_child(banda_inferior)

	banda_inferior.anchor_left = 0.0
	banda_inferior.anchor_top = 1.0
	banda_inferior.anchor_right = 1.0
	banda_inferior.anchor_bottom = 1.0

	banda_inferior.offset_left = 0.0
	banda_inferior.offset_top = -altura_banda
	banda_inferior.offset_right = 0.0
	banda_inferior.offset_bottom = 0.0

	# TITULO CINEMATOGRAFICO
	titulo_cinematico = Label.new()
	titulo_cinematico.name = "TituloCinematico"
	titulo_cinematico.text = texto_cinematico

	titulo_cinematico.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo_cinematico.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	titulo_cinematico.mouse_filter = Control.MOUSE_FILTER_IGNORE

	transicion_entrada.add_child(titulo_cinematico)

	titulo_cinematico.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	# Texto dorado inspirado en el atardecer japones
	titulo_cinematico.add_theme_color_override(
		"font_color",
		Color(0.92, 0.74, 0.46)
	)

	titulo_cinematico.add_theme_font_size_override(
		"font_size",
		36
	)

	# Invisible hasta comenzar la secuencia
	titulo_cinematico.modulate.a = 0.0


# =====================================
# INICIAR MUSICA DEL TUTORIAL
# =====================================

func iniciar_musica_tutorial() -> void:
	if musica_tutorial == null:
		return

	if musica_tutorial.stream == null:
		push_warning("MusicaTutorial no tiene un archivo de audio asignado.")
		return

	# Empezar con volumen muy bajo
	musica_tutorial.volume_db = -60.0
	musica_tutorial.play()

	# Subir lentamente hasta el volumen deseado
	var tween_musica: Tween = create_tween()
	tween_musica.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tween_musica.tween_property(
		musica_tutorial,
		"volume_db",
		volumen_musica_final,
		duracion_entrada_musica
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# =====================================
# TRANSICION CINEMATOGRAFICA
# =====================================

func iniciar_transicion_entrada() -> void:
	entrada_en_curso = true

	# Dejar que el Tutorial prepare sus nodos
	await get_tree().process_frame

	if not is_inside_tree():
		return

	# 1. Mantener un breve silencio visual en negro
	await get_tree().create_timer(
		espera_inicial
	).timeout

	if not is_inside_tree():
		return

	# 2. Aparicion suave del titulo dorado
	var tween_titulo: Tween = create_tween()
	tween_titulo.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tween_titulo.tween_property(
		titulo_cinematico,
		"modulate:a",
		1.0,
		duracion_titulo
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await tween_titulo.finished

	if not is_inside_tree():
		return

	# 3. Mantener el titulo unos instantes
	await get_tree().create_timer(
		espera_titulo
	).timeout

	if not is_inside_tree():
		return

	# 4. Iniciar la musica mientras aparece el paisaje
	iniciar_musica_tutorial()

	# Revelar el mundo mientras el titulo desaparece
	var tween_revelado: Tween = create_tween()
	tween_revelado.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tween_revelado.tween_property(
		pantalla_entrada,
		"modulate:a",
		0.0,
		duracion_entrada
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween_revelado.parallel().tween_property(
		titulo_cinematico,
		"modulate:a",
		0.0,
		1.1
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await tween_revelado.finished

	if not is_inside_tree():
		return

	# El escenario ya es completamente visible
	pantalla_entrada.hide()

	# 5. Retirar lentamente las bandas de cine
	var tween_bandas: Tween = create_tween()
	tween_bandas.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tween_bandas.tween_property(
		banda_superior,
		"offset_bottom",
		0.0,
		duracion_bandas
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween_bandas.parallel().tween_property(
		banda_inferior,
		"offset_top",
		0.0,
		duracion_bandas
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await tween_bandas.finished

	if not is_inside_tree():
		return

	# Limpiar los elementos visuales temporales
	titulo_cinematico.queue_free()
	banda_superior.queue_free()
	banda_inferior.queue_free()

	# 6. Pequeña pausa antes de que hable el padre
	await get_tree().create_timer(0.15).timeout

	if not is_inside_tree():
		return

	entrada_en_curso = false

	# Iniciar el dialogo original del Tutorial
	mostrar_introduccion()


# =====================================
# INTRODUCCION DEL PADRE
# =====================================

func mostrar_introduccion() -> void:
	mostrar_dialogo(
		"Padre",
		"Hola hijo, te enseñaré algunos movimientos básicos para enfrentarte a los retos que vendrán hacia ti. mientras tanto pulsa A Y D para moverte horizontalmente."
	)


# =====================================
# CONTROLES DEL DIALOGO
# =====================================

func _input(event: InputEvent) -> void:
	if entrada_en_curso or not dialogo_activo:
		return

	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_E:

			# Sonido al cerrar el dialogo
			sonido_cerrar_dialogo.stop()
			sonido_cerrar_dialogo.play(0.51)

			cerrar_dialogo()

			get_viewport().set_input_as_handled()


# =====================================
# MOSTRAR DIALOGO
# =====================================

func mostrar_dialogo(nombre: String, texto: String) -> void:
	if dialogo_activo:
		return

	# Actualizar textos
	nombre_personaje.text = nombre
	texto_dialogo.text = texto

	# Mostrar interfaz
	capa_dialogo.show()
	fondo_oscuro.show()
	panel_dialogo.show()
	papa_arashi.show()
	indicador_continuar.show()

	dialogo_activo = true

	# Sonido al abrir dialogo
	sonido_abrir_dialogo.stop()
	sonido_abrir_dialogo.play()

	print("DIALOGO ABIERTO - SONIDO REPRODUCIDO: ", nombre)

	# Pausar el escenario
	get_tree().paused = true

	# Oscurecer suavemente el fondo
	fondo_oscuro.modulate.a = 0.0

	if animacion_oscurecimiento:
		animacion_oscurecimiento.kill()

	animacion_oscurecimiento = create_tween()
	animacion_oscurecimiento.set_pause_mode(
		Tween.TWEEN_PAUSE_PROCESS
	)

	animacion_oscurecimiento.tween_property(
		fondo_oscuro,
		"modulate:a",
		oscuridad,
		duracion_fundido
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# =====================================
# CERRAR DIALOGO
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
	animacion_oscurecimiento.set_pause_mode(
		Tween.TWEEN_PAUSE_PROCESS
	)

	animacion_oscurecimiento.tween_property(
		fondo_oscuro,
		"modulate:a",
		0.0,
		duracion_fundido
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await animacion_oscurecimiento.finished

	if not is_inside_tree():
		return

	ocultar_dialogo()

	# Reanudar el juego
	get_tree().paused = false


# =====================================
# OCULTAR INTERFAZ
# =====================================

func ocultar_dialogo() -> void:
	capa_dialogo.hide()
	dialogo_activo = false
