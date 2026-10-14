
extends CharacterBody2D

const SPEED := 500.0
const GRAVITY := 900.0
const JUMP_FORCE := -600.0
const DOUBLE_JUMP_FORCE := -700.0

# =========================
# CONFIGURACION DEL COMBO
# =========================

const COMBO_WINDOW := 0.6

# =========================
# CONFIGURACION DEL DASH
# =========================

const DASH_SPEED := 1200.0
const DASH_DURATION := 0.25
const DASH_COOLDOWN := 0.6

var en_dash := false
var dash_was_pressed := false
var dash_direccion := -1.0
var dash_tiempo_restante := 0.0
var dash_recarga_restante := 0.0

# =========================
# ESTADO DEL JUGADOR
# =========================

var jumps_left := 2
var space_was_pressed := false
var attack_was_pressed := false
var block_was_pressed := false

var atacando := false
var saltando := false

# =========================
# SISTEMA DE COMBO
# =========================

var combo_step := 0
var ataque_en_cola := false
var combo_tiempo_restante := 0.0

# =========================
# SISTEMA DE BLOQUEO
# =========================

# "" = libre
# "start" = preparando bloqueo
# "hold" = bloqueando
# "end" = guardando espada

var bloqueo_estado := ""

# =========================
# CHECKPOINT
# =========================

var punto_checkpoint: Vector2
var posicion_bandera: Vector2
var bandera_activada: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:

	punto_checkpoint = global_position

	# Animaciones SIN loop
	for anim in [
		"attack1",
		"attack2",
		"attack3",
		"jump",
		"double_jump",
		"block_start",
		"block_end",
		"dash"
	]:
		animated_sprite.sprite_frames.set_animation_loop(anim, false)

	# Animaciones CON loop
	for anim in [
		"run",
		"idle",
		"block_hold"
	]:
		animated_sprite.sprite_frames.set_animation_loop(anim, true)

	# Detectar final de animaciones
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:

	# =========================
	# RECARGA DEL DASH
	# =========================

	if dash_recarga_restante > 0.0:
		dash_recarga_restante -= delta
		dash_recarga_restante = max(0.0, dash_recarga_restante)

	# =========================
	# RECUPERAR SALTOS
	# =========================

	if is_on_floor():
		jumps_left = 2
		saltando = false

	# =========================
	# LEER CONTROLES
	# =========================

	var direction := obtener_direccion()

	var space_pressed := Input.is_key_pressed(KEY_SPACE)
	var attack_pressed := Input.is_key_pressed(KEY_K)
	var block_pressed := Input.is_key_pressed(KEY_L)
	var dash_pressed := Input.is_key_pressed(KEY_SHIFT)

	# =========================
	# ACTIVAR DASH
	# =========================

	if dash_pressed and not dash_was_pressed:

		if not en_dash and not atacando and bloqueo_estado == "" and dash_recarga_restante <= 0.0:
			iniciar_dash(direction)

	dash_was_pressed = dash_pressed

	# =========================
	# MOVIMIENTO DURANTE EL DASH
	# =========================

	if en_dash:

		dash_tiempo_restante -= delta

		# Desplazamiento horizontal rapido
		velocity.x = dash_direccion * DASH_SPEED

		# Suspender gravedad temporalmente
		velocity.y = 0.0

		move_and_slide()

		# Actualizar controles para evitar
		# acciones acumuladas al terminar
		space_was_pressed = space_pressed
		attack_was_pressed = attack_pressed
		block_was_pressed = block_pressed

		if dash_tiempo_restante <= 0.0:
			finalizar_dash()

		return

	# =========================
	# GRAVEDAD NORMAL
	# =========================

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# =========================
	# TIEMPO DEL COMBO
	# =========================

	if not atacando and combo_tiempo_restante > 0.0:

		combo_tiempo_restante -= delta

		if combo_tiempo_restante <= 0.0:
			combo_tiempo_restante = 0.0
			combo_step = 0

	# =========================
	# BLOQUEO CON L
	# =========================

	if block_pressed and not block_was_pressed:

		if bloqueo_estado == "" and not atacando and is_on_floor():
			iniciar_bloqueo()

	if not block_pressed and bloqueo_estado == "hold":
		finalizar_bloqueo()

	block_was_pressed = block_pressed

	# =========================
	# SALTO Y DOBLE SALTO
	# =========================

	if space_pressed and not space_was_pressed:

		if jumps_left > 0 and bloqueo_estado == "":

			if jumps_left == 2:

				velocity.y = JUMP_FORCE
				saltando = true

				if not atacando:
					animated_sprite.play("jump")

			elif jumps_left == 1:

				velocity.y = DOUBLE_JUMP_FORCE
				saltando = true

				if not atacando:
					animated_sprite.play("double_jump")

			jumps_left -= 1

	space_was_pressed = space_pressed

	# =========================
	# COMBO DE ATAQUES CON K
	# =========================

	if attack_pressed and not attack_was_pressed:

		if bloqueo_estado == "":

			if atacando:

				if combo_step < 3:
					ataque_en_cola = true

			else:

				if combo_tiempo_restante > 0.0 and combo_step < 3:
					iniciar_ataque(combo_step + 1)

				else:
					iniciar_ataque(1)

	attack_was_pressed = attack_pressed

	# =========================
	# MOVIMIENTO A / D
	# =========================

	if not atacando and bloqueo_estado == "":

		if direction != 0.0:

			velocity.x = direction * SPEED

			# Sprites originales miran a izquierda
			if direction < 0.0:
				animated_sprite.flip_h = false
			else:
				animated_sprite.flip_h = true

		else:

			velocity.x = move_toward(velocity.x, 0.0, SPEED)

	else:

		velocity.x = 0.0

	# =========================
	# MOVIMIENTO FISICO
	# =========================

	move_and_slide()

	# =========================
	# ANIMACIONES
	# =========================

	if not atacando and bloqueo_estado == "":
		actualizar_animacion(direction)


# =========================
# INICIAR DASH
# =========================

func iniciar_dash(direction: float) -> void:

	en_dash = true
	dash_tiempo_restante = DASH_DURATION

	# Elegir la direccion del dash
	if direction != 0.0:

		dash_direccion = direction

		if direction < 0.0:
			animated_sprite.flip_h = false
		else:
			animated_sprite.flip_h = true

	else:

		# Si no se mueve, usar la direccion
		# hacia la que esta mirando Arashi
		if animated_sprite.flip_h:
			dash_direccion = 1.0
		else:
			dash_direccion = -1.0

	# Reiniciar combo al comenzar dash
	combo_step = 0
	ataque_en_cola = false
	combo_tiempo_restante = 0.0

	# Impulso del dash
	velocity.x = dash_direccion * DASH_SPEED
	velocity.y = 0.0

	# Animacion del dash
	animated_sprite.play("dash")


# =========================
# FINALIZAR DASH
# =========================

func finalizar_dash() -> void:

	en_dash = false

	# Iniciar tiempo de recarga
	dash_recarga_restante = DASH_COOLDOWN

	# Terminar impulso
	velocity.x = 0.0

	# Recuperar animacion correspondiente
	actualizar_animacion(obtener_direccion())


# =========================
# CONSULTAR SI ESTA EN DASH
# =========================

func esta_en_dash() -> bool:

	return en_dash


# =========================
# INICIAR BLOQUEO
# =========================

func iniciar_bloqueo() -> void:

	bloqueo_estado = "start"
	velocity.x = 0.0

	combo_step = 0
	ataque_en_cola = false
	combo_tiempo_restante = 0.0

	animated_sprite.play("block_start")


# =========================
# FINALIZAR BLOQUEO
# =========================

func finalizar_bloqueo() -> void:

	if bloqueo_estado == "":
		return

	bloqueo_estado = "end"

	animated_sprite.play("block_end")


# =========================
# COMPROBAR BLOQUEO ACTIVO
# =========================

func esta_bloqueando() -> bool:

	return bloqueo_estado == "hold"


# =========================
# INICIAR ATAQUE
# =========================

func iniciar_ataque(numero: int) -> void:

	atacando = true
	combo_step = numero
	ataque_en_cola = false
	combo_tiempo_restante = 0.0

	velocity.x = 0.0

	var nombre_animacion := "attack%d" % numero

	animated_sprite.play(nombre_animacion)


# =========================
# CUANDO TERMINA UNA ANIMACION
# =========================

func _on_animation_finished() -> void:

	var animacion_actual := animated_sprite.animation

	# =========================
	# DASH
	# =========================

	# La duracion del movimiento del dash
	# se controla desde _physics_process
	if animacion_actual == "dash":
		return

	# =========================
	# INICIO DEL BLOQUEO
	# =========================

	if animacion_actual == "block_start" and bloqueo_estado == "start":

		if Input.is_key_pressed(KEY_L):

			bloqueo_estado = "hold"
			animated_sprite.play("block_hold")

		else:

			finalizar_bloqueo()

		return

	# =========================
	# FINAL DEL BLOQUEO
	# =========================

	if animacion_actual == "block_end" and bloqueo_estado == "end":

		bloqueo_estado = ""

		actualizar_animacion(obtener_direccion())

		return

	# =========================
	# FINAL DEL ATAQUE
	# =========================

	if not atacando:
		return

	var ataque_actual := "attack%d" % combo_step

	if animacion_actual != ataque_actual:
		return

	if ataque_en_cola and combo_step < 3:

		iniciar_ataque(combo_step + 1)
		return

	atacando = false
	ataque_en_cola = false

	combo_tiempo_restante = COMBO_WINDOW

	actualizar_animacion(obtener_direccion())


# =========================
# OBTENER DIRECCION
# =========================

func obtener_direccion() -> float:

	if Input.is_key_pressed(KEY_A):
		return -1.0

	elif Input.is_key_pressed(KEY_D):
		return 1.0

	return 0.0


# =========================
# ACTUALIZAR ANIMACIONES
# =========================

func actualizar_animacion(direction: float) -> void:

	# Prioridad para dash, ataque y bloqueo
	if en_dash or atacando or bloqueo_estado != "":
		return

	# =========================
	# EN EL AIRE
	# =========================

	if not is_on_floor():

		var animacion_aerea := "jump"

		if jumps_left == 0:
			animacion_aerea = "double_jump"

		if animated_sprite.animation != animacion_aerea:
			animated_sprite.play(animacion_aerea)

		return

	# =========================
	# EN EL SUELO
	# =========================

	saltando = false

	if direction != 0.0:

		if animated_sprite.animation != "run":
			animated_sprite.play("run")

	else:

		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")


# =========================
# BANDERA / CHECKPOINT
# =========================

func activar_bandera(posicion: Vector2) -> void:

	bandera_activada = true
	posicion_bandera = posicion

	print("Nuevo checkpoint: ", posicion_bandera)


# =========================
# RESPAWN
# =========================

func respawn() -> void:

	if bandera_activada:

		global_position = posicion_bandera

	else:

		global_position = punto_checkpoint

	velocity = Vector2.ZERO

	atacando = false
	saltando = false
	jumps_left = 2

	# Reiniciar bloqueo
	bloqueo_estado = ""

	# Reiniciar combo
	combo_step = 0
	ataque_en_cola = false
	combo_tiempo_restante = 0.0

	# Reiniciar dash
	en_dash = false
	dash_tiempo_restante = 0.0
	dash_recarga_restante = 0.0

	# Sincronizar teclas
	space_was_pressed = Input.is_key_pressed(KEY_SPACE)
	attack_was_pressed = Input.is_key_pressed(KEY_K)
	block_was_pressed = Input.is_key_pressed(KEY_L)
	dash_was_pressed = Input.is_key_pressed(KEY_SHIFT)

	animated_sprite.play("idle")
