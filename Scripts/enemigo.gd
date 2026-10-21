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
# RETROCESO CUANDO ARASHI BLOQUEA
# =========================
@export_range(0.0, 500.0, 10.0) var velocidad_retroceso: float = 250.0
@export_range(0.0, 1.0, 0.01) var duracion_desplazamiento_retroceso: float = 0.18

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

# TAMANO DEL ULTIMO FRAME DE MUERTE (EL ENEMIGO ACOSTADO)
@export_range(1.0, 3.0, 0.1) var escala_muerte_final: float = 1.6
@export var ajuste_muerte_final: Vector2 = Vector2(0, -12)

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
var escala_original_muerte: Vector2 = Vector2.ONE
var posicion_original_muerte: Vector2 = Vector2.ZERO

var jugador: CharacterBody2D = null
var preparando_ataque: bool = false
var impacto_realizado: bool = false
var tiempo_recarga_restante: float = 0.0
var color_normal: Color = Color.WHITE

# NUEVO: estados de animacion de dano y derrota.
var recibiendo_golpe: bool = false
var secuencia_derrota_iniciada: bool = false

# Durante block_recoil no puede perseguir ni atacar.
var retrocediendo: bool = false
var tiempo_retroceso_restante: float = 0.0
var direccion_retroceso: float = 0.0

# Salida pacifica del enemigo al completar el entrenamiento.
var desapareciendo_entrenamiento: bool = false


func _ready() -> void:
	# Movimiento en bucle, acciones de una sola reproduccion.
	for nombre in ["idle", "run"]:
		if sprite.sprite_frames.has_animation(nombre):
			sprite.sprite_frames.set_animation_loop(nombre, true)

	for nombre in ["attack", "hurt", "death", "block_recoil"]:
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

	# Reaccion al ataque bloqueado: se desplaza alejandose de Arashi
	# mientras se reproduce block_recoil. Despues espera a que termine.
	if retrocediendo:
		if tiempo_retroceso_restante > 0.0:
			tiempo_retroceso_restante = maxf(0.0, tiempo_retroceso_restante - delta)
			velocity.x = direccion_retroceso * velocidad_retroceso
		else:
			velocity.x = 0.0
		move_and_slide()
		return

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
	if preparando_ataque or recibiendo_golpe or derrotado or retrocediendo:
		return
	var animacion_deseada: String = "run" if absf(velocity.x) > 1.0 else "idle"
	if sprite.animation != animacion_deseada:
		sprite.play(animacion_deseada)


func iniciar_ataque() -> void:
	if preparando_ataque or recibiendo_golpe or derrotado or retrocediendo:
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
	# Esta senal ya estaba conectada: tambien la usamos para death.
	if derrotado and sprite.animation == "death":
		actualizar_frame_muerte()
		return

	if not preparando_ataque or impacto_realizado or derrotado:
		return
	if sprite.animation != "attack":
		return

	var ultimo_indice: int = sprite.sprite_frames.get_frame_count("attack") - 1
	var indice: int = mini(frame_impacto, ultimo_indice)
	if sprite.frame >= indice:
		realizar_ataque()


func realizar_ataque() -> void:
	if impacto_realizado or derrotado or recibiendo_golpe or retrocediendo:
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
			# La version actual de arashi.gd devuelve true si bloqueo
			# correctamente (y reproduce block_hit).
			var fue_bloqueado: bool = bool(jugador.call(
				"recibir_ataque_enemigo", dano_ataque, global_position
			))
			if fue_bloqueado:
				iniciar_retroceso()
		elif jugador.has_method("recibir_dano"):
			jugador.recibir_dano(dano_ataque)
		else:
			push_warning("Arashi no tiene una funcion para recibir dano.")


# Se activa SOLO cuando Arashi efectivamente bloquea el golpe.
func iniciar_retroceso() -> void:
	if derrotado or retrocediendo:
		return

	# Cortar el ataque actual y evitar un segundo impacto.
	retrocediendo = true
	preparando_ataque = false
	impacto_realizado = true
	tiempo_retroceso_restante = duracion_desplazamiento_retroceso
	velocity.x = 0.0

	# Hacia el lado opuesto de Arashi.
	var diferencia_x: float = global_position.x - jugador.global_position.x
	if absf(diferencia_x) > 1.0:
		direccion_retroceso = signf(diferencia_x)
	else:
		direccion_retroceso = -1.0 if sprite.flip_h else 1.0

	actualizar_color()
	if sprite.sprite_frames.has_animation("block_recoil") and sprite.sprite_frames.get_frame_count("block_recoil") > 0:
		sprite.play("block_recoil")
	else:
		push_warning("Falta la animacion 'block_recoil' con sus cuatro frames.")
		finalizar_retroceso()


func finalizar_retroceso() -> void:
	retrocediendo = false
	impacto_realizado = false
	tiempo_retroceso_restante = 0.0
	velocity.x = 0.0
	# Pausa entre golpes para que Arashi pueda prepararse de nuevo.
	tiempo_recarga_restante = maxf(tiempo_recarga_restante, espera_entre_ataques)
	actualizar_animacion()


func _on_sprite_animation_finished() -> void:
	if sprite.animation == "block_recoil" and retrocediendo and not derrotado:
		finalizar_retroceso()
		return

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

	# El golpe interrumpe cualquier ataque o retroceso en curso.
	retrocediendo = false
	tiempo_retroceso_restante = 0.0
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
	# Conservar el color original al preparar y lanzar ataques.
	if tiempo_destello_restante > 0.0:
		# Solo se ilumina rojo al recibir dano real.
		sprite.modulate = color_normal * Color(1.0, 0.20, 0.20, 1.0)
	else:
		sprite.modulate = color_normal


# No reproduce "death": termina el entrenamiento y se desvanece.
func desvanecer_entrenamiento() -> void:
	if derrotado or desapareciendo_entrenamiento:
		return

	desapareciendo_entrenamiento = true
	derrotado = true
	preparando_ataque = false
	recibiendo_golpe = false
	retrocediendo = false
	impacto_realizado = true
	tiempo_retroceso_restante = 0.0
	velocity = Vector2.ZERO

	# Deja de atacar y de bloquear el paso.
	set_physics_process(false)
	sprite.stop()
	tiempo_destello_restante = 0.0
	sprite.modulate = color_normal
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	colision_cuerpo.set_deferred("disabled", true)
	remove_from_group("enemigos")

	# Solo se desvanece el sprite; el nodo se libera al terminar.
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.75)
	await tween.finished
	if is_inside_tree():
		queue_free()


func morir() -> void:
	if derrotado:
		return

	derrotado = true
	recibiendo_golpe = false
	preparando_ataque = false
	impacto_realizado = false
	retrocediendo = false
	tiempo_retroceso_restante = 0.0

	# Detener completamente al enemigo
	velocity = Vector2.ZERO
	set_physics_process(false)

	tiempo_destello_restante = 0.0
	sprite.modulate = color_normal

	print("SAMURAI DERROTADO")

	# Desactivar las colisiones
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	var colision = get_node_or_null("CollisionShape2D")
	if colision:
		colision.set_deferred("disabled", true)

	# Evitar que reciba mas ataques
	remove_from_group("enemigos")

	# Guardar la escala y posicion antes de iniciar la muerte.
	escala_original_muerte = sprite.scale
	posicion_original_muerte = sprite.position

	# Reproducir la animacion conservando los frames iniciales.
	if sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		actualizar_frame_muerte()
	else:
		push_warning("Falta animacion death")
		queue_free()



# Ajustar solo el ultimo fotograma de "death" sin afectar otras animaciones.
func actualizar_frame_muerte() -> void:
	if not derrotado or sprite.animation != "death":
		return

	var ultimo_frame: int = sprite.sprite_frames.get_frame_count("death") - 1
	if ultimo_frame < 0:
		return

	if sprite.frame == ultimo_frame:
		sprite.scale = escala_original_muerte * escala_muerte_final
		sprite.position = posicion_original_muerte + ajuste_muerte_final
	else:
		sprite.scale = escala_original_muerte
		sprite.position = posicion_original_muerte


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
