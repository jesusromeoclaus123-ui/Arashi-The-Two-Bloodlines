
extends Control

@onready var logo_perdiste: TextureRect = $LogoPerdiste
@onready var boton_reintentar: TextureButton = $BotonReintentar
@onready var boton_menu: TextureButton = $BotonMenu
@onready var pantalla_negra: ColorRect = $TransicionSalida/PantallaNegra

# Animaciones activas de los botones
var tween_reintentar: Tween
var tween_menu: Tween

# Evitar cambiar de escena varias veces
var cambiando_escena := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Configurar el centro de los botones
	boton_reintentar.pivot_offset = boton_reintentar.size / 2.0
	boton_menu.pivot_offset = boton_menu.size / 2.0

	# Preparar la pantalla negra
	pantalla_negra.modulate.a = 0.0
	pantalla_negra.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Ocultar logo y botones al comenzar
	logo_perdiste.modulate.a = 0.0
	boton_reintentar.modulate.a = 0.0
	boton_menu.modulate.a = 0.0

	# Desactivar botones mientras aparecen
	boton_reintentar.disabled = true
	boton_menu.disabled = true

	# Conectar las señales del mouse
	if not boton_reintentar.mouse_entered.is_connected(_on_boton_reintentar_mouse_entered):
		boton_reintentar.mouse_entered.connect(_on_boton_reintentar_mouse_entered)

	if not boton_reintentar.mouse_exited.is_connected(_on_boton_reintentar_mouse_exited):
		boton_reintentar.mouse_exited.connect(_on_boton_reintentar_mouse_exited)

	if not boton_menu.mouse_entered.is_connected(_on_boton_menu_mouse_entered):
		boton_menu.mouse_entered.connect(_on_boton_menu_mouse_entered)

	if not boton_menu.mouse_exited.is_connected(_on_boton_menu_mouse_exited):
		boton_menu.mouse_exited.connect(_on_boton_menu_mouse_exited)

	# Iniciar animación de entrada
	animar_menu_derrota()


# =====================================
# ANIMACIÓN INICIAL DEL MENÚ
# =====================================

func animar_menu_derrota() -> void:
	# Esperar mostrando solamente el fondo
	await get_tree().create_timer(0.5).timeout

	# Aparecer logo PERDISTE
	var tween_logo = create_tween()

	tween_logo.tween_property(
		logo_perdiste,
		"modulate:a",
		1.0,
		1.5
	)

	await tween_logo.finished

	# Pequeña pausa antes de mostrar botones
	await get_tree().create_timer(0.3).timeout

	# Mostrar los dos botones simultáneamente
	var tween_botones = create_tween()
	tween_botones.set_parallel(true)

	tween_botones.tween_property(
		boton_reintentar,
		"modulate:a",
		1.0,
		1.0
	)

	tween_botones.tween_property(
		boton_menu,
		"modulate:a",
		1.0,
		1.0
	)

	await tween_botones.finished

	# Activar botones
	boton_reintentar.disabled = false
	boton_menu.disabled = false


# =====================================
# ANIMACIONES AL PASAR EL MOUSE
# =====================================

func animar_boton_hover(boton: TextureButton) -> void:
	if cambiando_escena:
		return

	var tween: Tween

	# Detener animaciones anteriores
	if boton == boton_reintentar:
		if tween_reintentar and tween_reintentar.is_running():
			tween_reintentar.kill()

		tween_reintentar = create_tween()
		tween = tween_reintentar
	else:
		if tween_menu and tween_menu.is_running():
			tween_menu.kill()

		tween_menu = create_tween()
		tween = tween_menu

	# Agrandar suavemente
	tween.tween_property(
		boton,
		"scale",
		Vector2(1.08, 1.08),
		0.15
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func animar_boton_normal(boton: TextureButton) -> void:
	if cambiando_escena:
		return

	var tween: Tween

	# Detener animaciones anteriores
	if boton == boton_reintentar:
		if tween_reintentar and tween_reintentar.is_running():
			tween_reintentar.kill()

		tween_reintentar = create_tween()
		tween = tween_reintentar
	else:
		if tween_menu and tween_menu.is_running():
			tween_menu.kill()

		tween_menu = create_tween()
		tween = tween_menu

	# Volver al tamaño original
	tween.tween_property(
		boton,
		"scale",
		Vector2(1.0, 1.0),
		0.15
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# =====================================
# SEÑALES DEL BOTÓN REINTENTAR
# =====================================

func _on_boton_reintentar_mouse_entered() -> void:
	if not boton_reintentar.disabled:
		animar_boton_hover(boton_reintentar)


func _on_boton_reintentar_mouse_exited() -> void:
	animar_boton_normal(boton_reintentar)


# =====================================
# SEÑALES DEL BOTÓN MENÚ
# =====================================

func _on_boton_menu_mouse_entered() -> void:
	if not boton_menu.disabled:
		animar_boton_hover(boton_menu)


func _on_boton_menu_mouse_exited() -> void:
	animar_boton_normal(boton_menu)


# =====================================
# TRANSICIÓN A NEGRO
# =====================================

func transicion_a_escena(ruta: String) -> void:
	# Evitar que se ejecute dos veces
	if cambiando_escena:
		return

	cambiando_escena = true

	# Desactivar botones
	boton_reintentar.disabled = true
	boton_menu.disabled = true

	# Detener animaciones de hover
	if tween_reintentar and tween_reintentar.is_running():
		tween_reintentar.kill()

	if tween_menu and tween_menu.is_running():
		tween_menu.kill()

	# Preparar fundido a negro
	pantalla_negra.modulate.a = 0.0
	pantalla_negra.show()

	# Crear animación de oscurecimiento
	var tween = create_tween()

	tween.tween_property(
		pantalla_negra,
		"modulate:a",
		1.0,
		1.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Esperar a que termine el fundido
	await tween.finished

	# Despausar el juego y cambiar de escena
	get_tree().paused = false
	get_tree().change_scene_to_file(ruta)


# =====================================
# BOTÓN REINTENTAR
# =====================================

func _on_boton_reintentar_pressed() -> void:
	print("Presionaste REINTENTAR")

	transicion_a_escena("res://scenes/Tutorial.tscn")


# =====================================
# BOTÓN MENÚ
# =====================================

func _on_boton_menu_pressed() -> void:
	print("Presionaste MENU")

	transicion_a_escena("res://scenes/menu_principal.tscn")
