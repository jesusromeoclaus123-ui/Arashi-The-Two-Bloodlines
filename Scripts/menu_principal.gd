
extends Control

@onready var jugar: Control = $Jugar
@onready var salir: Control = $Salir

@onready var rayo_jugar: CanvasItem = $RayoJugar
@onready var rayo_salir: CanvasItem = $RayoSalir

# SONIDO
@onready var sonido_seleccion: AudioStreamPlayer = $SonidoSeleccion

# TRANSICION
@onready var pantalla_fundido: ColorRect = $PantallaFundido
@onready var musica_menu: AudioStreamPlayer = $MusicaMenu


var transicion_activa: bool = false


func _ready() -> void:
	# Ocultar efectos inicialmente
	rayo_jugar.hide()
	rayo_salir.hide()

	# Configurar botones
	jugar.mouse_filter = Control.MOUSE_FILTER_STOP
	salir.mouse_filter = Control.MOUSE_FILTER_STOP

	jugar.set_size(Vector2(409, 103))
	salir.modulate.a = 1.0

	# Evitar que los rayos bloqueen el mouse
	if rayo_jugar is Control:
		var control_jugar := rayo_jugar as Control
		control_jugar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if rayo_salir is Control:
		var control_salir := rayo_salir as Control
		control_salir.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Alinear el rayo con el boton Salir
	call_deferred("alinear_rayo_salir")

	# Preparar pantalla de transicion
	pantalla_fundido.color = Color.BLACK
	pantalla_fundido.modulate.a = 0.0
	pantalla_fundido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pantalla_fundido.show()


# =====================================
# POSICION DEL EFECTO SALIR
# =====================================

func alinear_rayo_salir() -> void:
	if rayo_salir is Control:
		var efecto := rayo_salir as Control
		efecto.global_position = salir.global_position

	elif rayo_salir is Node2D:
		var efecto := rayo_salir as Node2D
		efecto.global_position = salir.get_global_rect().get_center()


# =====================================
# SONIDO AL PRESIONAR BOTONES
# =====================================

func reproducir_sonido_seleccion() -> void:
	sonido_seleccion.stop()
	sonido_seleccion.play()


# =====================================
# BOTON JUGAR
# =====================================


func _on_jugar_pressed() -> void:
	if transicion_activa:
		return

	# Sonido al hacer clic en JUGAR.
	reproducir_sonido_seleccion()

	transicion_activa = true

	# Desactivar botones durante la transicion.
	jugar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	salir.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Crear transicion cinematografica.
	var tween: Tween = create_tween()
	tween.set_parallel(true)

	# La pantalla se oscurece lentamente.
	tween.tween_property(
		pantalla_fundido,
		"modulate:a",
		1.0,
		1.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# La musica se desvanece al mismo tiempo.
	if musica_menu.playing:
		tween.tween_property(
			musica_menu,
			"volume_db",
			-60.0,
			1.5
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Esperar a que terminen los fundidos.
	await tween.finished

	# Entrar al Tutorial.
	get_tree().change_scene_to_file("res://scenes/Tutorial.tscn")



# =====================================
# ANIMACION JUGAR
# =====================================

func _on_jugar_mouse_entered() -> void:
	if transicion_activa:
		return

	# Solamente mostrar los rayos
	rayo_jugar.show()


func _on_jugar_mouse_exited() -> void:
	rayo_jugar.hide()


# =====================================
# BOTON SALIR
# =====================================

func _on_salir_pressed() -> void:
	if transicion_activa:
		return

	# Reproducir sonido al hacer clic
	reproducir_sonido_seleccion()

	transicion_activa = true

	# Desactivar botones
	jugar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	salir.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Esperar un instante para escuchar el sonido
	await get_tree().create_timer(0.35).timeout

	# Cerrar el juego
	get_tree().quit()


# =====================================
# ANIMACION SALIR
# =====================================

func _on_salir_mouse_entered() -> void:
	if transicion_activa:
		return

	alinear_rayo_salir()

	# Mostrar solamente la animacion
	salir.modulate.a = 0.0
	rayo_salir.show()


func _on_salir_mouse_exited() -> void:
	rayo_salir.hide()
	salir.modulate.a = 1.0
