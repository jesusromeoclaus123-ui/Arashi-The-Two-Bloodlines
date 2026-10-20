extends CharacterBody2D

# =========================
# MOVIMIENTO
# =========================
@export var velocidad: float = 100.0
@export var gravedad: float = 900.0
@export var distancia_deteccion: float = 350.0
@export var distancia_detenerse: float = 85.0

# =========================
# ATAQUE
# =========================
@export_range(0.0, 200.0, 1.0) var dano_ataque: float = 15.0
# Tiempo aproximado desde el inicio de "attack" hasta el frame de impacto.
@export_range(0.1, 3.0, 0.05) var tiempo_preparacion: float = 0.4
@export_range(0.1, 5.0, 0.1) var espera_entre_ataques: float = 1.5
@export_range(0.0, 100.0, 1.0) var margen_alcance_ataque: float = 15.0
@export_range(0.0, 300.0, 1.0) var tolerancia_vertical: float = 120.0
# Indice 3 = cuarto sprite de la animacion.
@export_range(0, 20, 1) var frame_impacto: int = 3

# =========================
# VIDA Y REACCION AL DANO
# =========================
signal vida_cambiada(actual: float, maxima: float)

@export_range(1.0, 500.0, 1.0) var vida_maxima: float = 100.0
@export_range(0.05, 1.0, 0.05) var duracion_destello: float = 0.15
@export_range(0.0, 2.0, 0.05) var invulnerabilidad_tras_golpe: float = 0.20

# NUEVO: tiempo que permanece el cuerpo antes de desaparecer.
@export_range(0.0, 10.0, 0.1) var tiempo_cuerpo_en_suelo: float = 2.0
@export_range(0.0, 5.0, 0.1) var duracion_desvanecimiento: float = 0.5

var vida_actual: float = 100.0
var tiempo_destello_restante: float = 0.0
var tiempo_inmune_restante: float = 0.0
var derrotado: bool = false

# =========================
# REFERENCIAS Y ESTADO
# =========================
@onready var sprite: AnimatedSprite2D = $Enemigo
@onready var colision_cuerpo: CollisionShape2D = $CollisionShape2D
var colision_cuerpo_x_original: float = 0.0

var jugador: CharacterBody2D = null
var preparando_ataque: bool = false
var impacto_realizado: bool = false
var tiempo_recarga_restante: float = 0.0
var color_normal: Color = Color.WHITE

# NUEVO: estados de animacion de dano y derrota.
var recibiendo_golpe: bool = false
var secuencia_derrota_iniciada: bool = false


func _ready() -> void:
	# Movimiento en bucle, acciones de una sola reproduccion.
	for nombre in ["idle", "run"]:
		if sprite.sprite_frames.has_animation(nombre):
			sprite.sprite_frames.set_animation_loop(nombre, true)

	for nombre in ["attack", "hurt", "death"]:
		if sprite.sprite_frames.has_animation(nombre):
			sprite.sprite_frames.set_animation_loop(nombre, false)
		else:
			push_error("Falta la animacion '%s' en el AnimatedSprite2D Enemigo." % nombre)

	if not sprite.frame_changed.is_connected(_on_sprite_frame_changed):
		sprite.frame_changed.connect(_on_sprite_frame_changed)
	if not sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		sprite.animation_finished.connect(_on_sprite_animation_finished)

	colision_cuerpo_x_original = colision_cuerpo.position.x
	color_normal = sprite.modulate
	vida_actual = vida_maxima
	vida_cambiada.emit(vida_actual, vida_maxima)
	buscar_jugador()
	sprite.play("idle")


func buscar_jugador() -> void:
	jugador = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if jugador:
		print("Samurai encontro a Arashi")
	else:
		print("Samurai no encontro a Arashi: revisa el grupo player")


func _physics_process(delta: float) -> void:
	# Durante la derrota no persigue, no ataca ni cambia animaciones.
	# Solo se conserva la gravedad para que quede sobre el suelo.
	if derrotado:
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y += gravedad * delta
		move_and_slide()
		return

	if tiempo_inmune_restante > 0.0:
		tiempo_inmune_restante = maxf(0.0, tiempo_inmune_restante - delta)
	if tiempo_destello_restante > 0.0:
		tiempo_destello_restante = maxf(0.0, tiempo_destello_restante - delta)
	actualizar_color()

	if not is_on_floor():
		velocity.y += gravedad * delta

	if tiempo_recarga_restante > 0.0:
		tiempo_recarga_restante = maxf(0.0, tiempo_recarga_restante - delta)

	# Mientras reproduce hurt, no persigue ni inicia ataques.
	if recibiendo_golpe:
		velocity.x = 0.0
		move_and_slide()
		return

	if not is_instance_valid(jugador):
		jugador = null
		buscar_jugador()

	if jugador == null:
		velocity.x = 0.0
		cancelar_preparacion()
		actualizar_animacion()
		move_and_slide()
		return

	var diferencia_x: float = jugador.global_position.x - global_position.x
	var distancia: float = absf(diferencia_x)
	var distancia_y: float = absf(jugador.global_position.y - global_position.y)
	var alcance: float = distancia_detenerse + margen_alcance_ataque

	# Durante attack mantiene la orientacion que tenia al empezar.
	if not preparando_ataque:
		if diferencia_x < -1.0:
			sprite.flip_h = false
		elif diferencia_x > 1.0:
			sprite.flip_h = true

	colision_cuerpo.position.x = -colision_cuerpo_x_original if sprite.flip_h else colision_cuerpo_x_original

	if preparando_ataque:
		velocity.x = 0.0
		move_and_slide()
		return

	if distancia > distancia_deteccion or distancia_y > 150.0:
		velocity.x = 0.0
	elif distancia <= alcance:
		velocity.x = 0.0
		if distancia_y <= tolerancia_vertical and tiempo_recarga_restante <= 0.0:
			iniciar_ataque()
	else:
		var direccion: float = signf(diferencia_x)
		velocity.x = direccion * velocidad

	actualizar_animacion()
	move_and_slide()


func actualizar_animacion() -> void:
	if preparando_ataque or recibiendo_golpe or derrotado:
		return
	var animacion_deseada: String = "run" if absf(velocity.x) > 1.0 else "idle"
	if sprite.animation != animacion_deseada:
		sprite.play(animacion_deseada)


func iniciar_ataque() -> void:
	if preparando_ataque or recibiendo_golpe or derrotado:
		return
	if not sprite.sprite_frames.has_animation("attack"):
		return

	preparando_ataque = true
	impacto_realizado = false
	velocity.x = 0.0
	actualizar_color()

	var cantidad_frames: int = sprite.sprite_frames.get_frame_count("attack")
	if cantidad_frames <= 0:
		cancelar_preparacion()
		return
	var indice: int = mini(frame_impacto, cantidad_frames - 1)
	var fps_base: float = sprite.sprite_frames.get_animation_speed("attack")
	var multiplicador: float = 1.0
	if indice > 0 and tiempo_preparacion > 0.0 and fps_base > 0.0:
		multiplicador = (float(indice) / tiempo_preparacion) / fps_base

	sprite.play("attack", multiplicador)
	if indice == 0:
		realizar_ataque()


func _on_sprite_frame_changed() -> void:
	if not preparando_ataque or impacto_realizado or derrotado:
		return
	if sprite.animation != "attack":
		return

	var ultimo_indice: int = sprite.sprite_frames.get_frame_count("attack") - 1
	var indice: int = mini(frame_impacto, ultimo_indice)
	if sprite.frame >= indice:
		realizar_ataque()


func realizar_ataque() -> void:
	if impacto_realizado or derrotado or recibiendo_golpe:
		return
	impacto_realizado = true
	actualizar_color()

	if not is_instance_valid(jugador):
		return

	var alcance: float = distancia_detenerse + margen_alcance_ataque
	var distancia_x: float = absf(jugador.global_position.x - global_position.x)
	var distancia_y: float = absf(jugador.global_position.y - global_position.y)

	if distancia_x <= alcance and distancia_y <= tolerancia_vertical:
		if jugador.has_method("recibir_ataque_enemigo"):
			jugador.recibir_ataque_enemigo(dano_ataque, global_position)
		elif jugador.has_method("recibir_dano"):
			jugador.recibir_dano(dano_ataque)
		else:
			push_warning("Arashi no tiene una funcion para recibir dano.")


func _on_sprite_animation_finished() -> void:
	if sprite.animation == "attack" and preparando_ataque and not derrotado:
		preparando_ataque = false
		impacto_realizado = false
		tiempo_recarga_restante = espera_entre_ataques
		actualizar_color()
		actualizar_animacion()
		return

	if sprite.animation == "hurt" and recibiendo_golpe and not derrotado:
		recibiendo_golpe = false
		actualizar_animacion()
		return

	if sprite.animation == "death" and derrotado and not secuencia_derrota_iniciada:
		secuencia_derrota_iniciada = true
		terminar_derrota()


func cancelar_preparacion() -> void:
	if not preparando_ataque:
		return
	preparando_ataque = false
	impacto_realizado = false
	actualizar_color()
	if sprite.animation == "attack":
		sprite.play("idle")


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

	# El golpe interrumpe cualquier ataque en preparacion.
	cancelar_preparacion()
	tiempo_recarga_restante = espera_entre_ataques
	velocity.x = 0.0
	recibiendo_golpe = true

	tiempo_inmune_restante = invulnerabilidad_tras_golpe
	tiempo_destello_restante = duracion_destello
	actualizar_color()

	if sprite.sprite_frames.has_animation("hurt"):
		sprite.play("hurt")
	else:
		recibiendo_golpe = false
		actualizar_animacion()


func actualizar_color() -> void:
	if tiempo_destello_restante > 0.0:
		# Rojo fuerte al recibir dano.
		sprite.modulate = color_normal * Color(1.0, 0.20, 0.20, 1.0)
	elif preparando_ataque and not impacto_realizado:
		# Rojo suave de aviso de ataque.
		sprite.modulate = color_normal * Color(1.0, 0.55, 0.55, 1.0)
	else:
		sprite.modulate = color_normal


func morir() -> void:
	if derrotado:
		return
	derrotado = true
	recibiendo_golpe = false
	preparando_ataque = false
	impacto_realizado = false
	velocity.x = 0.0
	tiempo_destello_restante = 0.0
	sprite.modulate = color_normal
	print("SAMURAI DERROTADO")

	# Dejar de poder ser detectado como objetivo por las hitboxes.
	remove_from_group("enemigos")

	if sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
	else:
		push_warning("Falta 'death': se eliminara el enemigo sin animacion.")
		queue_free()


func terminar_derrota() -> void:
	# La animacion 'death' se queda mostrando el ultimo frame.
	if tiempo_cuerpo_en_suelo > 0.0:
		await get_tree().create_timer(tiempo_cuerpo_en_suelo).timeout
	if not is_inside_tree():
		return

	if duracion_desvanecimiento > 0.0:
		var tween: Tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, duracion_desvanecimiento)
		await tween.finished

	queue_free()
