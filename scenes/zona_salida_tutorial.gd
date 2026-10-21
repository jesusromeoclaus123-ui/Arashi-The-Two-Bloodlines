
extends Area2D

# =========================
# CONFIGURACION
# =========================

@export_file("*.tscn") var escena_nivel_1: String = "res://scenes/Nivel1.tscn"

@export var distancia_inicio: float = 450.0
@export_range(0.0, 1.0, 0.05) var blanco_maximo: float = 0.90
@export var velocidad_suavizado: float = 3.0
@export var escala_maxima_luz: float = 4.0


# =========================
# REFERENCIAS
# =========================

@onready var capa_transicion: CanvasLayer = $"../TransicionNivel1"
@onready var pantalla_blanca: ColorRect = $"../TransicionNivel1/PantallaBlanca"
@onready var texto_anterior: Label = $"../TransicionNivel1/TextoNivel1"
@onready var luz_blanca: ColorRect = $LuzBlanca
@onready var control_final: Node = get_node_or_null("../ControlFinalTutorial")

var jugador: CharacterBody2D = null
var transicion_iniciada: bool = false
var escala_original_luz: Vector2 = Vector2.ONE

var pantalla_negra: ColorRect
var panel_titulos: VBoxContainer


# =========================
# INICIO
# =========================

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	jugador = get_tree().get_first_node_in_group("player") as CharacterBody2D

	pantalla_blanca.visible = true
	pantalla_blanca.color = Color(1.0, 1.0, 1.0, 0.0)
	pantalla_blanca.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Ocultamos el texto anterior porque usaremos
	# una presentación cinematográfica nueva.
	texto_anterior.visible = false

	escala_original_luz = luz_blanca.scale
	luz_blanca.pivot_offset = luz_blanca.size / 2.0
	luz_blanca.mouse_filter = Control.MOUSE_FILTER_IGNORE

	crear_pantalla_cinematografica()


# =========================
# CREAR PRESENTACION DEL NIVEL
# =========================

func crear_pantalla_cinematografica() -> void:
	# Fondo negro que aparecerá después del blanco.
	pantalla_negra = ColorRect.new()
	pantalla_negra.name = "PantallaNegraCinematica"
	pantalla_negra.color = Color(0.0, 0.0, 0.0, 0.0)
	pantalla_negra.mouse_filter = Control.MOUSE_FILTER_IGNORE

	capa_transicion.add_child(pantalla_negra)
	pantalla_negra.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	# Contenedor centrado de los títulos.
	panel_titulos = VBoxContainer.new()
	panel_titulos.name = "TitulosCinematicos"
	panel_titulos.alignment = BoxContainer.ALIGNMENT_CENTER
	panel_titulos.add_theme_constant_override("separation", 18)
	panel_titulos.modulate.a = 0.0
	panel_titulos.mouse_filter = Control.MOUSE_FILTER_IGNORE

	capa_transicion.add_child(panel_titulos)
	panel_titulos.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	crear_texto(
		"ARASHI: THE TWO BLOODLINES",
		20,
		Color("B99A72")
	)

	crear_separador()

	crear_texto(
		"NIVEL I",
		64,
		Color("F2E9DC")
	)

	crear_texto(
		"EL VIAJE COMIENZA",
		30,
		Color("D5A96C")
	)

	crear_separador()

	crear_texto(
		"Cargando el siguiente capítulo...",
		17,
		Color("A49C96")
	)


func crear_texto(
	contenido: String,
	tamanio: int,
	color_texto: Color
) -> void:
	var etiqueta: Label = Label.new()

	etiqueta.text = contenido
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE

	etiqueta.add_theme_font_size_override(
		"font_size",
		tamanio
	)

	etiqueta.add_theme_color_override(
		"font_color",
		color_texto
	)

	panel_titulos.add_child(etiqueta)


func crear_separador() -> void:
	var linea: ColorRect = ColorRect.new()

	linea.color = Color("967148")
	linea.custom_minimum_size = Vector2(260, 2)
	linea.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	linea.mouse_filter = Control.MOUSE_FILTER_IGNORE

	panel_titulos.add_child(linea)


# =========================
# EFECTO DE CERCANIA
# =========================

func _process(delta: float) -> void:
	if transicion_iniciada:
		return

	if not is_instance_valid(jugador):
		jugador = get_tree().get_first_node_in_group("player") as CharacterBody2D

		if jugador == null:
			return

	# Solo calcular distancia horizontal.
	var distancia_x: float = absf(
		jugador.global_position.x - global_position.x
	)

	var cercania: float = 1.0 - clampf(
		distancia_x / maxf(distancia_inicio, 1.0),
		0.0,
		1.0
	)

	# Esperar a que termine el entrenamiento.
	if is_instance_valid(control_final):
		if control_final.get("dialogo_final_mostrado") != true:
			cercania = 0.0

	var alpha_objetivo: float = blanco_maximo * cercania

	var suavizado: float = clampf(
		velocidad_suavizado * delta,
		0.0,
		1.0
	)

	var nuevo_alpha: float = lerpf(
		pantalla_blanca.color.a,
		alpha_objetivo,
		suavizado
	)

	pantalla_blanca.color = Color(
		1.0, 1.0, 1.0, nuevo_alpha
	)

	# Agrandar la luz cuando Arashi se acerca.
	var factor_escala: float = lerpf(
		1.0,
		escala_maxima_luz,
		cercania
	)

	var escala_deseada: Vector2 = (
		escala_original_luz * factor_escala
	)

	luz_blanca.scale = luz_blanca.scale.lerp(
		escala_deseada,
		suavizado
	)


# =========================
# ENTRAR AL PORTAL
# =========================

func _on_body_entered(body: Node2D) -> void:
	if transicion_iniciada:
		return

	if not body.is_in_group("player"):
		return

	if get_tree().paused:
		return

	if is_instance_valid(control_final):
		if control_final.get("dialogo_final_mostrado") != true:
			return

	jugador = body as CharacterBody2D

	if jugador == null:
		return

	transicion_iniciada = true
	iniciar_transicion_nivel_1()


# =========================
# TRANSICION CINEMATOGRAFICA
# =========================

func iniciar_transicion_nivel_1() -> void:
	# Detener a Arashi al entrar.
	if is_instance_valid(jugador):
		jugador.velocity = Vector2.ZERO
		jugador.set_physics_process(false)
		jugador.set_process(false)

	# 1. Pantalla completamente blanca.
	var tween_blanco: Tween = create_tween()

	tween_blanco.tween_property(
		pantalla_blanca,
		"color:a",
		1.0,
		0.55
	)

	await tween_blanco.finished

	# 2. Pasar suavemente del blanco al negro.
	var tween_negro: Tween = create_tween()

	tween_negro.tween_property(
		pantalla_negra,
		"color:a",
		1.0,
		0.9
	)

	await tween_negro.finished

	# 3. Aparecen los títulos cinematográficos.
	var tween_titulos: Tween = create_tween()

	tween_titulos.tween_property(
		panel_titulos,
		"modulate:a",
		1.0,
		0.8
	)

	await tween_titulos.finished

	# 4. Mantener la presentación.
	await get_tree().create_timer(2.0).timeout

	# 5. Cargar el Nivel 1.
	if ResourceLoader.exists(escena_nivel_1):
		var resultado: Error = get_tree().change_scene_to_file(
			escena_nivel_1
		)

		if resultado == OK:
			return

		push_error("No se pudo cargar el Nivel 1.")
	else:
		print("Nivel 1 todavía no creado.")
		print("Presentación cinematográfica completada.")

	# =========================
	# REGRESAR SI NIVEL 1 NO EXISTE
	# =========================

	var tween_ocultar: Tween = create_tween()

	tween_ocultar.tween_property(
		panel_titulos,
		"modulate:a",
		0.0,
		0.4
	)

	await tween_ocultar.finished

	var tween_volver: Tween = create_tween()
	tween_volver.set_parallel(true)

	tween_volver.tween_property(
		pantalla_negra,
		"color:a",
		0.0,
		0.7
	)

	tween_volver.tween_property(
		pantalla_blanca,
		"color:a",
		0.0,
		0.7
	)

	await tween_volver.finished

	# Reactivar a Arashi.
	if is_instance_valid(jugador):
		jugador.set_physics_process(true)
		jugador.set_process(true)

	transicion_iniciada = false
