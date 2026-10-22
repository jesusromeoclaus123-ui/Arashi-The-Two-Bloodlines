
extends Node

# Asignar desde el Inspector
@export var arashi: CharacterBody2D
@export var hud_raiz: Node

# Configuracion del HUD dinamico
@export_range(0.5, 10.0, 0.5) var tiempo_visible := 3.0
@export_range(0.05, 2.0, 0.05) var duracion_aparicion := 0.2
@export_range(0.05, 2.0, 0.05) var duracion_desaparicion := 0.6

var elementos: Array[CanvasItem] = []
var alfas_originales: Dictionary = {}

var hud_mostrado := false
var tiempo_restante := 0.0
var vida_anterior := 0.0

var animacion_hud: Tween


# =====================================
# INICIO
# =====================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if arashi == null or hud_raiz == null:
		push_warning(
			"HUDDinamico: asigna Arashi y Hud Raiz en el Inspector."
		)
		set_process(false)
		return

	# Buscar los elementos visuales del HUD.
	recolectar_elementos(hud_raiz)

	if elementos.is_empty():
		push_warning("HUDDinamico: no se encontraron elementos visuales.")
		set_process(false)
		return

	# Guardar sus transparencias originales y ocultarlos.
	for elemento in elementos:
		alfas_originales[elemento.get_instance_id()] = elemento.modulate.a
		elemento.modulate.a = 0.0
		elemento.hide()

	vida_anterior = float(arashi.get("vida_actual"))


# =====================================
# BUSCAR ELEMENTOS DEL HUD
# =====================================

func recolectar_elementos(nodo: Node) -> void:
	# Control, ProgressBar, TextureRect, Sprite2D, etc.
	if nodo is CanvasItem:
		elementos.append(nodo as CanvasItem)
		return

	# Si el HUD es un CanvasLayer, buscar sus hijos.
	for hijo in nodo.get_children():
		recolectar_elementos(hijo)


# =====================================
# DETECTAR ACCIONES DE ARASHI
# =====================================

func _process(delta: float) -> void:
	if not is_instance_valid(arashi):
		return

	var vida_actual: float = float(arashi.get("vida_actual"))

	# Ocultar durante cinematica, dialogos y pausas.
	if get_tree().paused:
		ocultar_inmediatamente()
		vida_anterior = vida_actual
		return

	# No mostrar el HUD durante la derrota.
	if arashi.get("esta_muerto") == true:
		ocultar_inmediatamente()
		vida_anterior = vida_actual
		return

	# Estados reales del jugador.
	var haciendo_dash: bool = arashi.get("en_dash") == true
	var atacando: bool = arashi.get("atacando") == true

	var estado_rayo: String = str(arashi.get("rayo_estado"))
	var usando_rayo: bool = estado_rayo in ["start", "hold"]

	var estado_bloqueo: String = str(arashi.get("bloqueo_estado"))
	var bloqueando: bool = estado_bloqueo in ["start", "hold", "hit"]

	# Solo detectar una disminucion real de vida.
	var recibio_dano: bool = vida_actual < vida_anterior

	vida_anterior = vida_actual

	# Si Arashi realiza una accion, mostrar y renovar el tiempo.
	if haciendo_dash or atacando or usando_rayo or bloqueando or recibio_dano:
		mostrar_hud()
		return

	# Si no realiza acciones, iniciar la cuenta regresiva.
	if hud_mostrado:
		tiempo_restante -= delta

		if tiempo_restante <= 0.0:
			ocultar_hud()


# =====================================
# MOSTRAR HUD
# =====================================

func mostrar_hud() -> void:
	# Renovar los tres segundos.
	tiempo_restante = tiempo_visible

	# Si ya esta apareciendo o visible, no reiniciar el fundido.
	if hud_mostrado:
		return

	hud_mostrado = true
	detener_animacion()

	animacion_hud = create_tween()
	animacion_hud.set_parallel(true)

	for elemento in elementos:
		elemento.show()

		var alfa_final: float = float(
			alfas_originales[elemento.get_instance_id()]
		)

		animacion_hud.tween_property(
			elemento,
			"modulate:a",
			alfa_final,
			duracion_aparicion
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# =====================================
# OCULTAR HUD SUAVEMENTE
# =====================================

func ocultar_hud() -> void:
	if not hud_mostrado:
		return

	hud_mostrado = false
	detener_animacion()

	animacion_hud = create_tween()
	animacion_hud.set_parallel(true)

	for elemento in elementos:
		animacion_hud.tween_property(
			elemento,
			"modulate:a",
			0.0,
			duracion_desaparicion
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Esperar a que todos los elementos terminen su fundido.
	animacion_hud.chain().tween_callback(terminar_ocultamiento)


func terminar_ocultamiento() -> void:
	if hud_mostrado:
		return

	for elemento in elementos:
		elemento.hide()


# =====================================
# OCULTAR SIN ANIMACION
# =====================================

func ocultar_inmediatamente() -> void:
	detener_animacion()

	hud_mostrado = false
	tiempo_restante = 0.0

	for elemento in elementos:
		elemento.modulate.a = 0.0
		elemento.hide()


# =====================================
# DETENER TRANSICION ANTERIOR
# =====================================

func detener_animacion() -> void:
	if animacion_hud != null and animacion_hud.is_valid():
		animacion_hud.kill()
