
extends Area2D

# =========================
# REAPARICION
# =========================

@export var punto_reaparicion: Marker2D

# Duracion de las transiciones
@export var tiempo_oscurecer: float = 0.30
@export var tiempo_pantalla_negra: float = 0.15
@export var tiempo_aclarar: float = 0.35

var reapareciendo: bool = false

# Capa visual para la transicion
var capa_transicion: CanvasLayer
var fondo_negro: ColorRect


func _ready() -> void:
	crear_transicion()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


# =========================
# CREAR PANTALLA NEGRA
# =========================

func crear_transicion() -> void:
	capa_transicion = CanvasLayer.new()
	capa_transicion.layer = 100
	add_child(capa_transicion)

	fondo_negro = ColorRect.new()
	fondo_negro.color = Color(0, 0, 0, 0)
	fondo_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE

	capa_transicion.add_child(fondo_negro)

	# Cubrir toda la pantalla
	fondo_negro.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


# =========================
# DETECTAR CAIDA
# =========================

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	if reapareciendo:
		return

	if not is_instance_valid(punto_reaparicion):
		push_warning("No hay punto de reaparicion asignado.")
		return

	reapareciendo = true

	iniciar_reaparicion(body)


# =========================
# TRANSICION Y REAPARICION
# =========================

func iniciar_reaparicion(body: Node2D) -> void:

	# 1. Oscurecer la pantalla suavemente
	var tween_oscurecer: Tween = create_tween()

	tween_oscurecer.tween_property(
		fondo_negro,
		"color:a",
		1.0,
		tiempo_oscurecer
	)

	await tween_oscurecer.finished

	if not is_instance_valid(body):
		reapareciendo = false
		return

	# 2. Congelar temporalmente a Arashi
	body.set_physics_process(false)

	if body is CharacterBody2D:
		body.velocity = Vector2.ZERO

	# 3. Reaparecer en el punto seguro
	body.global_position = punto_reaparicion.global_position

	# Evitar saltos de interpolacion visual
	body.reset_physics_interpolation()

	# Ajustar la camara a la nueva posicion
	var camara: Camera2D = get_viewport().get_camera_2d()

	if is_instance_valid(camara):
		camara.reset_smoothing()

	# 4. Mantener la pantalla negra un instante
	await get_tree().create_timer(
		tiempo_pantalla_negra
	).timeout

	if not is_instance_valid(body):
		reapareciendo = false
		return

	# 5. Reactivar el movimiento
	body.set_physics_process(true)

	# 6. Iluminar nuevamente la pantalla
	var tween_aclarar: Tween = create_tween()

	tween_aclarar.tween_property(
		fondo_negro,
		"color:a",
		0.0,
		tiempo_aclarar
	)

	await tween_aclarar.finished

	reapareciendo = false

	print("Arashi reaparecio correctamente")
