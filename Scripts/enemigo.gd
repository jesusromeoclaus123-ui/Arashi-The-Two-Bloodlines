extends CharacterBody2D

# =========================
# MOVIMIENTO (valores que ya podes modificar en el Inspector)
# =========================
@export var velocidad: float = 100.0
@export var gravedad: float = 900.0
@export var distancia_deteccion: float = 350.0
@export var distancia_detenerse: float = 85.0

# =========================
# ATAQUE
# =========================
@export_range(0.0, 200.0, 1.0) var dano_ataque: float = 15.0
@export_range(0.1, 3.0, 0.05) var tiempo_preparacion: float = 0.4
@export_range(0.1, 5.0, 0.1) var espera_entre_ataques: float = 1.5
# El alcance se calcula sumando este margen a distancia_detenerse.
@export_range(0.0, 100.0, 1.0) var margen_alcance_ataque: float = 15.0
@export_range(0.0, 300.0, 1.0) var tolerancia_vertical: float = 120.0

# =========================
# VIDA Y REACCION AL DANO
# =========================
signal vida_cambiada(actual: float, maxima: float)

@export_range(1.0, 500.0, 1.0) var vida_maxima: float = 100.0
# El destello rojo es diferente de la advertencia roja del ataque.
@export_range(0.05, 1.0, 0.05) var duracion_destello: float = 0.15
# Evita registrar demasiados impactos seguidos por accidente.
@export_range(0.0, 2.0, 0.05) var invulnerabilidad_tras_golpe: float = 0.20

var vida_actual: float = 100.0
var tiempo_destello_restante: float = 0.0
var tiempo_inmune_restante: float = 0.0
var derrotado: bool = false

# =========================
# REFERENCIAS Y ESTADO
# =========================
@onready var sprite: Sprite2D = $Samurai
@onready var colision_cuerpo: CollisionShape2D = $CollisionShape2D
var colision_cuerpo_x_original: float = 0.0

var jugador: CharacterBody2D = null
var preparando_ataque: bool = false
var tiempo_preparacion_restante: float = 0.0
var tiempo_recarga_restante: float = 0.0
var color_normal: Color = Color.WHITE


func _ready() -> void:
	colision_cuerpo_x_original = colision_cuerpo.position.x
	color_normal = sprite.modulate
	vida_actual = vida_maxima
	vida_cambiada.emit(vida_actual, vida_maxima)
	buscar_jugador()


func buscar_jugador() -> void:
	jugador = get_tree().get_first_node_in_group("player") as CharacterBody2D

	if jugador:
		print("Samurai encontro a Arashi")
	else:
		print("Samurai no encontro a Arashi: revisa el grupo player")


func _physics_process(delta: float) -> void:
	if derrotado:
		return

	if tiempo_inmune_restante > 0.0:
		tiempo_inmune_restante = maxf(0.0, tiempo_inmune_restante - delta)
	if tiempo_destello_restante > 0.0:
		tiempo_destello_restante = maxf(0.0, tiempo_destello_restante - delta)
	actualizar_color()

	# Gravedad: el enemigo siempre permanece sujeto al suelo.
	if not is_on_floor():
		velocity.y += gravedad * delta

	if tiempo_recarga_restante > 0.0:
		tiempo_recarga_restante = maxf(0.0, tiempo_recarga_restante - delta)

	if not is_instance_valid(jugador):
		jugador = null
		buscar_jugador()

	if jugador == null:
		velocity.x = 0.0
		cancelar_preparacion()
		move_and_slide()
		return

	var diferencia_x: float = jugador.global_position.x - global_position.x
	var distancia: float = absf(diferencia_x)
	var distancia_y: float = absf(jugador.global_position.y - global_position.y)
	var alcance: float = distancia_detenerse + margen_alcance_ataque

	# Girar hacia Arashi incluso cuando el samurai esta quieto.
	if diferencia_x < -1.0:
		sprite.flip_h = false  # El dibujo original mira a izquierda.
	elif diferencia_x > 1.0:
		sprite.flip_h = true

	# La colision corporal acompanha al sprite si su forma esta desplazada.
	# Si CollisionShape2D esta centrado (Position X = 0), se queda centrado.
	colision_cuerpo.position.x = -colision_cuerpo_x_original if sprite.flip_h else colision_cuerpo_x_original

	# Durante la preparacion no persigue: espera y lanza el golpe.
	if preparando_ataque:
		velocity.x = 0.0
		tiempo_preparacion_restante -= delta
		if tiempo_preparacion_restante <= 0.0:
			realizar_ataque(alcance)
		move_and_slide()
		return

	# No perseguir al jugador por todo el nivel.
	if distancia > distancia_deteccion or distancia_y > 150.0:
		velocity.x = 0.0
	elif distancia <= alcance:
		velocity.x = 0.0
		if distancia_y <= tolerancia_vertical and tiempo_recarga_restante <= 0.0:
			iniciar_ataque()
	else:
		var direccion: float = signf(diferencia_x)
		velocity.x = direccion * velocidad

	move_and_slide()


func iniciar_ataque() -> void:
	preparando_ataque = true
	tiempo_preparacion_restante = tiempo_preparacion
	velocity.x = 0.0
	# Aviso visual provisional. Luego lo cambiamos por animacion.
	actualizar_color()


func realizar_ataque(alcance: float) -> void:
	cancelar_preparacion()
	tiempo_recarga_restante = espera_entre_ataques

	if not is_instance_valid(jugador):
		return

	# Comprobar el alcance EN EL MOMENTO DEL GOLPE.
	var distancia_x: float = absf(jugador.global_position.x - global_position.x)
	var distancia_y: float = absf(jugador.global_position.y - global_position.y)

	if distancia_x <= alcance and distancia_y <= tolerancia_vertical:
		# Arashi decide si puede bloquear segun su postura y hacia donde mira.
		if jugador.has_method("recibir_ataque_enemigo"):
			jugador.recibir_ataque_enemigo(dano_ataque, global_position)
		elif jugador.has_method("recibir_dano"):
			# Compatible con un jugador que aun no use bloqueo direccional.
			jugador.recibir_dano(dano_ataque)
		else:
			push_warning("Arashi no tiene una funcion para recibir dano.")


func cancelar_preparacion() -> void:
	preparando_ataque = false
	tiempo_preparacion_restante = 0.0
	actualizar_color()


# =========================
# RECIBIR DANO / DERROTA
# =========================
func recibir_dano(cantidad: float) -> void:
	if derrotado or cantidad <= 0.0 or tiempo_inmune_restante > 0.0:
		return

	vida_actual = maxf(0.0, vida_actual - cantidad)
	vida_cambiada.emit(vida_actual, vida_maxima)
	print("VIDA DEL SAMURAI: ", vida_actual)

	if vida_actual <= 0.0:
		morir()
		return

	tiempo_inmune_restante = invulnerabilidad_tras_golpe
	tiempo_destello_restante = duracion_destello
	actualizar_color()


func actualizar_color() -> void:
	if tiempo_destello_restante > 0.0:
		# Destello rojo intenso por recibir dano.
		sprite.modulate = color_normal * Color(1.0, 0.20, 0.20, 1.0)
	elif preparando_ataque:
		# Rojo suave al preparar su propio ataque.
		sprite.modulate = color_normal * Color(1.0, 0.55, 0.55, 1.0)
	else:
		sprite.modulate = color_normal


func morir() -> void:
	if derrotado:
		return
	derrotado = true
	velocity = Vector2.ZERO
	print("SAMURAI DERROTADO")
	# Por ahora desaparece; mas adelante reproducira su animacion de muerte.
	queue_free()
