
extends CanvasLayer

# =====================================
# NODOS DEL MENU DE PAUSA
# =====================================

@onready var interfaz_pausa: Control = $InterfazPausa
@onready var fondo_oscuro: ColorRect = $InterfazPausa/FondoOscuro
@onready var logo_arashi: TextureRect = $InterfazPausa/LogoArashi

@onready var boton_reanudar: TextureButton = $InterfazPausa/BotonReanudar
@onready var boton_opciones: TextureButton = $InterfazPausa/BotonOpciones
@onready var boton_menu: TextureButton = $InterfazPausa/BotonMenu


# =====================================
# CONFIGURACION
# =====================================

@export_range(0.0, 1.0, 0.05) var oscuridad := 0.55
@export var duracion_fundido := 0.4

var menu_abierto := false
var en_transicion := false

# Guardar las animaciones de los botones
var tweens_botones: Dictionary = {}


# =====================================
# INICIO
# =====================================

func _ready() -> void:
	# Permitir que el menu funcione con el juego pausado
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Ocultar el menu al iniciar
	interfaz_pausa.hide()

	# Preparar el fondo negro transparente
	fondo_oscuro.color = Color.BLACK
	fondo_oscuro.modulate.a = 0.0
	fondo_oscuro.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Configurar el centro de los botones
	boton_reanudar.pivot_offset = boton_reanudar.size / 2.0
	boton_opciones.pivot_offset = boton_opciones.size / 2.0
	boton_menu.pivot_offset = boton_menu.size / 2.0

	# Conectar animaciones del mouse
	for boton in [boton_reanudar, boton_opciones, boton_menu]:
		boton.mouse_entered.connect(
			animar_boton.bind(boton, true)
		)
		boton.mouse_exited.connect(
			animar_boton.bind(boton, false)
		)

	# Conectar los botones
	if not boton_reanudar.pressed.is_connected(_on_boton_reanudar_pressed):
		boton_reanudar.pressed.connect(_on_boton_reanudar_pressed)

	if not boton_opciones.pressed.is_connected(_on_boton_opciones_pressed):
		boton_opciones.pressed.connect(_on_boton_opciones_pressed)

	if not boton_menu.pressed.is_connected(_on_boton_menu_pressed):
		boton_menu.pressed.connect(_on_boton_menu_pressed)


# =====================================
# TECLA ESC
# =====================================

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:

			if en_transicion:
				return

			# Si el menu esta abierto, cerrarlo
			if menu_abierto:
				cerrar_menu()
				get_viewport().set_input_as_handled()

			# Abrir solo si el juego no esta pausado
			elif not get_tree().paused:
				abrir_menu()
				get_viewport().set_input_as_handled()


# =====================================
# ABRIR MENU DE PAUSA
# =====================================

func abrir_menu() -> void:
	if menu_abierto or get_tree().paused:
		return

	menu_abierto = true
	en_transicion = true

	# Mostrar la interfaz
	interfaz_pausa.show()

	# Reiniciar apariencia de los botones
	for boton in [boton_reanudar, boton_opciones, boton_menu]:
		boton.scale = Vector2.ONE
		boton.disabled = true

	# Preparar fondo transparente
	fondo_oscuro.modulate.a = 0.0

	# Pausar el juego
	get_tree().paused = true

	# Oscurecer suavemente
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tween.tween_property(
		fondo_oscuro,
		"modulate:a",
		oscuridad,
		duracion_fundido
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await tween.finished

	# Habilitar los botones
	for boton in [boton_reanudar, boton_opciones, boton_menu]:
		boton.disabled = false

	en_transicion = false


# =====================================
# CERRAR MENU DE PAUSA
# =====================================

func cerrar_menu() -> void:
	if not menu_abierto or en_transicion:
		return

	en_transicion = true

	# Desactivar los botones
	for boton in [boton_reanudar, boton_opciones, boton_menu]:
		boton.disabled = true

	# Recuperar iluminacion del escenario
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tween.tween_property(
		fondo_oscuro,
		"modulate:a",
		0.0,
		duracion_fundido
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await tween.finished

	# Ocultar la interfaz
	interfaz_pausa.hide()

	menu_abierto = false
	en_transicion = false

	# Reanudar el juego
	get_tree().paused = false


# =====================================
# ANIMACIONES DE LOS BOTONES
# =====================================

func animar_boton(boton: TextureButton, seleccionado: bool) -> void:
	if en_transicion or boton.disabled:
		return

	# Detener animacion anterior
	if tweens_botones.has(boton):
		var tween_anterior: Tween = tweens_botones[boton]

		if tween_anterior and tween_anterior.is_running():
			tween_anterior.kill()

	# Determinar escala
	var escala_objetivo := Vector2.ONE

	if seleccionado:
		escala_objetivo = Vector2(1.08, 1.08)

	# Crear nueva animacion
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tweens_botones[boton] = tween

	tween.tween_property(
		boton,
		"scale",
		escala_objetivo,
		0.15
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# =====================================
# BOTON REANUDAR
# =====================================

func _on_boton_reanudar_pressed() -> void:
	if en_transicion:
		return

	print("REANUDANDO PARTIDA")
	cerrar_menu()


# =====================================
# BOTON OPCIONES
# =====================================

func _on_boton_opciones_pressed() -> void:
	if en_transicion:
		return

	print("OPCIONES - Pendiente de crear pantalla de ajustes")


# =====================================
# BOTON MENU PRINCIPAL
# =====================================

func _on_boton_menu_pressed() -> void:
	if en_transicion:
		return

	en_transicion = true

	# Desactivar los botones
	for boton in [boton_reanudar, boton_opciones, boton_menu]:
		boton.disabled = true

	# Fundido completo a negro
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tween.tween_property(
		fondo_oscuro,
		"modulate:a",
		1.0,
		1.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await tween.finished

	# Despausar y volver al menu principal
	get_tree().paused = false
	get_tree().change_scene_to_file(
		"res://scenes/menu_principal.tscn"
	)
