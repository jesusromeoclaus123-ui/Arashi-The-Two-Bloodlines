


extends Control

@onready var logo_perdiste: TextureRect = $LogoPerdiste
@onready var boton_reintentar: TextureButton = $BotonReintentar
@onready var boton_menu: TextureButton = $BotonMenu
@onready var pantalla_negra: ColorRect = $TransicionSalida/PantallaNegra

# SONIDO DE LOS BOTONES
@onready var sonido_click: AudioStreamPlayer = $SonidoClick

# MUSICA DEL MENU DE DERROTA
@onready var musica_derrota: AudioStreamPlayer = $MusicaDerrota


# =====================================
# CONFIGURACION
# =====================================

@export var duracion_fundido_salida: float = 1.5
@export var duracion_fundido_entrada: float = 1.5

# CONFIGURACION DE LA MUSICA
@export var volumen_musica_final: float = -20.0
@export var duracion_entrada_musica: float = 2.0

# Animaciones activas de los botones
var tween_reintentar: Tween
var tween_menu: Tween

# Animaciones de la musica
var tween_musica: Tween

# Evitar cambiar de escena varias veces
var cambiando_escena := false


# =====================================
# INICIO
# =====================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Permitir sonido aunque el juego este pausado
	sonido_click.process_mode = Node.PROCESS_MODE_ALWAYS
	musica_derrota.process_mode = Node.PROCESS_MODE_ALWAYS

	# El clic solamente se reproduce al presionar
	sonido_click.autoplay = false

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
	if not boton_reintentar.mouse_entered.is_connected(
		_on_boton_reintentar_mouse_entered
	):
		boton_reintentar.mouse_entered.connect(
			_on_boton_reintentar_mouse_entered
		)

	if not boton_reintentar.mouse_exited.is_connected(
		_on_boton_reintentar_mouse_exited
	):
		boton_reintentar.mouse_exited.connect(
			_on_boton_reintentar_mouse_exited
		)

	if not boton_menu.mouse_entered.is_connected(
		_on_boton_menu_mouse_entered
	):
		boton_menu.mouse_entered.connect(
			_on_boton_menu_mouse_entered
		)

	if not boton_menu.mouse_exited.is_connected(
		_on_boton_menu_mouse_exited
	):
		boton_menu.mouse_exited.connect(
			_on_boton_menu_mouse_exited
		)

	# Iniciar musica del menu de derrota
	iniciar_musica_derrota()

	# Iniciar animacion de entrada
	animar_menu_derrota()


# =====================================
# MUSICA DEL MENU DE DERROTA
# =====================================

func iniciar_musica_derrota() -> void:
	if musica_derrota.stream == null:
		push_warning("MusicaDerrota no tiene un audio asignado.")
		return

	# Activar bucle si es un MP3
	if musica_derrota.stream is AudioStreamMP3:
		var mp3: AudioStreamMP3 = musica_derrota.stream as AudioStreamMP3
		mp3.loop = true

	# Comenzar con volumen muy bajo
	musica_derrota.stop()
	musica_derrota.volume_db = -60.0

	# Reproducir la musica
	musica_derrota.play()

	# Aumentar suavemente el volumen
	if tween_musica and tween_musica.is_running():
		tween_musica.kill()

	tween_musica = create_tween()
	tween_musica.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tween_musica.tween_property(
		musica_derrota,
		"volume_db",
		volumen_musica_final,
		duracion_entrada_musica
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# =====================================
# DESVANECER MUSICA AL SALIR
# =====================================

func desvanecer_musica_derrota() -> void:
	if not musica_derrota.playing:
		return

	# Detener el fundido de entrada si sigue activo
	if tween_musica and tween_musica.is_running():
		tween_musica.kill()

	# Bajar la musica mientras la pantalla se oscurece
	tween_musica = create_tween()
	tween_musica.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tween_musica.tween_property(
		musica_derrota,
		"volume_db",
		-60.0,
		duracion_fundido_salida
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween_musica.tween_callback(musica_derrota.stop)


# =====================================
# ANIMACION INICIAL DEL MENU
# =====================================

func animar_menu_derrota() -> void:

	# Esperar mostrando solamente el fondo
	await get_tree().create_timer(0.5).timeout

	# Aparecer logo PERDISTE
	var tween_logo: Tween = create_tween()

	tween_logo.tween_property(
		logo_perdiste,
		"modulate:a",
		1.0,
		1.5
	)

	await tween_logo.finished

	# Pequeña pausa antes de mostrar botones
	await get_tree().create_timer(0.3).timeout

	# Mostrar los dos botones simultaneamente
	var tween_botones: Tween = create_tween()
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
# SEÑALES DEL BOTON REINTENTAR
# =====================================

func _on_boton_reintentar_mouse_entered() -> void:
	if not boton_reintentar.disabled:
		animar_boton_hover(boton_reintentar)


func _on_boton_reintentar_mouse_exited() -> void:
	animar_boton_normal(boton_reintentar)


# =====================================
# SEÑALES DEL BOTON MENU
# =====================================

func _on_boton_menu_mouse_entered() -> void:
	if not boton_menu.disabled:
		animar_boton_hover(boton_menu)


func _on_boton_menu_mouse_exited() -> void:
	animar_boton_normal(boton_menu)


# =====================================
# SONIDO DE LOS BOTONES
# =====================================

func reproducir_sonido_click() -> void:
	if sonido_click.stream == null:
		push_warning("Falta asignar el sonido en SonidoClick.")
		return

	# Permitir reproduccion durante las pausas
	sonido_click.process_mode = Node.PROCESS_MODE_ALWAYS

	# Evitar que el efecto quede en bucle
	if sonido_click.stream is AudioStreamMP3:
		var mp3: AudioStreamMP3 = sonido_click.stream as AudioStreamMP3
		mp3.loop = false

	# Mantener el sonido aunque cambie la escena
	sonido_click.reparent(get_tree().root)

	# Eliminar el reproductor cuando termine el audio
	sonido_click.finished.connect(
		sonido_click.queue_free
	)

	# Reproducir una sola vez
	sonido_click.play()


# =====================================
# FUNDIDO DE ENTRADA AL MENU PRINCIPAL
# =====================================

func preparar_fundido_entrada() -> void:

	# Crear una capa temporal independiente
	var capa_entrada: CanvasLayer = CanvasLayer.new()

	capa_entrada.name = "FundidoEntradaMenu"
	capa_entrada.layer = 1000
	capa_entrada.process_mode = Node.PROCESS_MODE_ALWAYS

	get_tree().root.add_child(capa_entrada)

	# Crear pantalla negra
	var pantalla_entrada: ColorRect = ColorRect.new()

	pantalla_entrada.name = "PantallaEntradaNegra"
	pantalla_entrada.color = Color.BLACK
	pantalla_entrada.mouse_filter = Control.MOUSE_FILTER_STOP

	capa_entrada.add_child(pantalla_entrada)

	# Cubrir toda la pantalla
	pantalla_entrada.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	pantalla_entrada.modulate.a = 1.0

	# Crear tween independiente de la escena de derrota
	var tween_entrada: Tween = get_tree().create_tween()

	tween_entrada.set_pause_mode(
		Tween.TWEEN_PAUSE_PROCESS
	)

	# Breve espera mientras carga el menu principal
	tween_entrada.tween_interval(0.15)

	# Revelar suavemente el nuevo menu
	tween_entrada.tween_property(
		pantalla_entrada,
		"modulate:a",
		0.0,
		duracion_fundido_entrada
	).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)

	# Eliminar la capa cuando termine
	tween_entrada.tween_callback(
		capa_entrada.queue_free
	)


# =====================================
# TRANSICION A NEGRO
# =====================================

func transicion_a_escena(
	ruta: String,
	usar_fundido_entrada: bool = false
) -> void:

	# Evitar multiples pulsaciones
	if cambiando_escena:
		return

	cambiando_escena = true

	# =====================================
	# SONIDO DE CLIC
	# =====================================

	reproducir_sonido_click()

	# =====================================
	# DESVANECER MUSICA DE DERROTA
	# =====================================

	desvanecer_musica_derrota()

	# =====================================
	# DESACTIVAR BOTONES
	# =====================================

	boton_reintentar.disabled = true
	boton_menu.disabled = true

	# Detener animaciones de hover
	if tween_reintentar and tween_reintentar.is_running():
		tween_reintentar.kill()

	if tween_menu and tween_menu.is_running():
		tween_menu.kill()

	# =====================================
	# FUNDIDO DE SALIDA
	# =====================================

	pantalla_negra.modulate.a = 0.0
	pantalla_negra.show()

	var tween_salida: Tween = create_tween()

	tween_salida.set_pause_mode(
		Tween.TWEEN_PAUSE_PROCESS
	)

	tween_salida.tween_property(
		pantalla_negra,
		"modulate:a",
		1.0,
		duracion_fundido_salida
	).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)

	# Esperar a que la pantalla quede negra
	await tween_salida.finished

	if not is_inside_tree():
		return

	# =====================================
	# CAMBIO DE ESCENA
	# =====================================

	# Despausar el juego antes del cambio
	get_tree().paused = false

	# Preparar entrada al menu principal
	if usar_fundido_entrada:
		preparar_fundido_entrada()

	# Cambiar a la escena solicitada
	var resultado: Error = get_tree().change_scene_to_file(ruta)

	if resultado != OK:
		push_error("No se pudo cambiar a la escena: " + ruta)


# =====================================
# BOTON REINTENTAR
# =====================================

func _on_boton_reintentar_pressed() -> void:
	print("Presionaste REINTENTAR")

	transicion_a_escena(
		"res://scenes/Tutorial.tscn",
		false
	)


# =====================================
# BOTON VOLVER AL MENU
# =====================================

func _on_boton_menu_pressed() -> void:
	print("Presionaste VOLVER AL MENU")

	transicion_a_escena(
		"res://scenes/menu_principal.tscn",
		true
	)
