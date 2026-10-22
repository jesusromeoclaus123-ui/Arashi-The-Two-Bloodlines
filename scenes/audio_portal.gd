
extends Node

# =====================================
# CONFIGURACION DEL PORTAL
# =====================================

# Distancia necesaria para activar el ambiente.
@export var distancia_activacion: float = 650.0

# Distancia donde alcanza el volumen maximo.
@export var distancia_cercana: float = 100.0

# Volumenes del ambiente.
@export var volumen_lejano: float = -50.0
@export var volumen_cercano: float = 0.0

# Suavidad del cambio de volumen.
@export var velocidad_volumen: float = 5.0

# Margen para detectar el borde visual del portal.
@export var margen_pantalla: float = 80.0

# Por si el archivo tiene silencio al principio.
@export_range(0.0, 10.0, 0.01) var inicio_audio_ambiente: float = 0.0


# =====================================
# REFERENCIAS
# =====================================

@onready var zona_portal: Area2D = get_parent() as Area2D

@onready var ambiente: AudioStreamPlayer = $AmbientePortal
@onready var entrada: AudioStreamPlayer = $EntradaPortal

var jugador: Node2D
var portal_activado: bool = false


# =====================================
# INICIO
# =====================================

func _ready() -> void:
	if zona_portal == null:
		push_error("AudioPortal debe ser hijo de ZonaSalidaTutorial.")
		set_process(false)
		return

	process_mode = Node.PROCESS_MODE_ALWAYS
	ambiente.process_mode = Node.PROCESS_MODE_ALWAYS
	entrada.process_mode = Node.PROCESS_MODE_ALWAYS

	# Buscar a Arashi.
	jugador = get_tree().get_first_node_in_group("player") as Node2D

	# IMPORTANTE:
	# Ninguno de los sonidos debe comenzar automaticamente.
	ambiente.autoplay = false
	entrada.autoplay = false

	ambiente.stop()
	entrada.stop()

	ambiente.volume_db = volumen_lejano

	# Configurar repeticion del ambiente.
	if ambiente.stream is AudioStreamMP3:
		var mp3: AudioStreamMP3 = ambiente.stream as AudioStreamMP3
		mp3.loop = true

	# El sonido de entrada solo debe reproducirse una vez.
	if entrada.stream is AudioStreamMP3:
		var mp3_entrada: AudioStreamMP3 = entrada.stream as AudioStreamMP3
		mp3_entrada.loop = false

	# Conectar deteccion de entrada.
	if not zona_portal.body_entered.is_connected(al_entrar_portal):
		zona_portal.body_entered.connect(al_entrar_portal)


# =====================================
# DETECTAR SI EL PORTAL ESTA EN PANTALLA
# =====================================

func portal_esta_en_pantalla() -> bool:
	# Obtener la zona visible de la camara.
	var pantalla: Rect2 = get_viewport().get_visible_rect()

	# Convertir la posicion del portal a coordenadas de pantalla.
	var posicion_portal: Vector2 = (
		zona_portal.get_global_transform_with_canvas().origin
	)

	# Permitir un pequeno margen por el tamano del portal.
	return pantalla.grow(margen_pantalla).has_point(
		posicion_portal
	)


# =====================================
# DETENER SONIDO AMBIENTAL
# =====================================

func detener_ambiente() -> void:
	if ambiente.playing:
		ambiente.stop()

	ambiente.volume_db = volumen_lejano


# =====================================
# SONIDO SEGUN LA DISTANCIA
# =====================================

func _process(delta: float) -> void:
	if portal_activado:
		return

	if ambiente.stream == null:
		return

	# Buscar nuevamente al jugador si hace falta.
	if not is_instance_valid(jugador):
		jugador = get_tree().get_first_node_in_group("player") as Node2D

		if jugador == null:
			detener_ambiente()
			return

	# Durante cinematicas o dialogos no debe sonar.
	if get_tree().paused:
		detener_ambiente()
		return

	# IMPORTANTE:
	# Si el portal NO esta en pantalla, no reproducir audio.
	if not portal_esta_en_pantalla():
		detener_ambiente()
		return

	# Calcular distancia horizontal entre Arashi y el portal.
	var distancia: float = absf(
		jugador.global_position.x - zona_portal.global_position.x
	)

	# IMPORTANTE:
	# Aunque el portal este visible, Arashi debe estar cerca.
	if distancia >= distancia_activacion:
		detener_ambiente()
		return

	# =====================================
	# ACTIVAR AMBIENTE
	# =====================================

	# Solo comenzar cuando se cumplan las dos condiciones.
	if not ambiente.playing:
		ambiente.volume_db = volumen_lejano

		var inicio_seguro: float = clampf(
			inicio_audio_ambiente,
			0.0,
			maxf(0.0, ambiente.stream.get_length() - 0.05)
		)

		ambiente.play(inicio_seguro)

		print("PORTAL: ambiente activado por proximidad")

	# =====================================
	# CALCULAR INTENSIDAD
	# =====================================

	var rango: float = maxf(
		1.0,
		distancia_activacion - distancia_cercana
	)

	var intensidad: float = clampf(
		(distancia_activacion - distancia) / rango,
		0.0,
		1.0
	)

	# Aumento progresivo del sonido.
	intensidad = 1.0 - pow(1.0 - intensidad, 1.5)

	var volumen_objetivo: float = lerpf(
		volumen_lejano,
		volumen_cercano,
		intensidad
	)

	# Suavizar el cambio de volumen.
	var suavizado: float = 1.0 - exp(
		-velocidad_volumen * delta
	)

	ambiente.volume_db = lerpf(
		ambiente.volume_db,
		volumen_objetivo,
		suavizado
	)


# =====================================
# ENTRADA AL PORTAL
# =====================================

func al_entrar_portal(cuerpo: Node2D) -> void:
	if portal_activado:
		return

	# Solamente Arashi puede activar el portal.
	if not cuerpo.is_in_group("player"):
		return

	portal_activado = true

	print("PORTAL ACTIVADO")

	# =====================================
	# OCULTAR HUD
	# =====================================

	var tutorial: Node = get_tree().current_scene

	if tutorial != null:
		var hud: Node = tutorial.find_child(
			"HUDDinamico",
			true,
			false
		)

		if hud != null:
			hud.set_process(false)

			if hud.has_method("ocultar_inmediatamente"):
				hud.call("ocultar_inmediatamente")

	# =====================================
	# DESVANECER AMBIENTE
	# =====================================

	if ambiente.playing:
		var tween_ambiente: Tween = create_tween()
		tween_ambiente.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

		tween_ambiente.tween_property(
			ambiente,
			"volume_db",
			-80.0,
			0.4
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		tween_ambiente.tween_callback(ambiente.stop)

	# =====================================
	# BAJAR MUSICA DEL TUTORIAL
	# =====================================

	if tutorial != null:
		var musica: AudioStreamPlayer = tutorial.get_node_or_null(
			"MusicaTutorial"
		) as AudioStreamPlayer

		if musica != null:
			var tween_musica: Tween = create_tween()
			tween_musica.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

			tween_musica.tween_property(
				musica,
				"volume_db",
				-55.0,
				0.9
			).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# =====================================
	# SONIDO ESPECIAL DE ENTRADA
	# =====================================

	if entrada.stream != null:

		# Mantener el efecto aunque cambie la escena.
		entrada.reparent(get_tree().root)

		# Eliminarlo cuando termine.
		entrada.finished.connect(entrada.queue_free)

		# Reproducir una sola vez.
		entrada.play()

	else:
		push_warning("Falta asignar el sonido de entrada al portal.")
