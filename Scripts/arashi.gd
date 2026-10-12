


extends CharacterBody2D

const SPEED := 500.0
const GRAVITY := 900.0
const JUMP_FORCE := -600.0
const DOUBLE_JUMP_FORCE := -700.0

# Tiempo para continuar el combo
const COMBO_WINDOW := 0.6

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

# Estados posibles:
# "" = no bloquea
# "start" = comienza a bloquear
# "hold" = mantiene el bloqueo
# "end" = deja de bloquear

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

	# Animaciones que NO se repiten
	animated_sprite.sprite_frames.set_animation_loop("attack1", false)
	animated_sprite.sprite_frames.set_animation_loop("attack2", false)
	animated_sprite.sprite_frames.set_animation_loop("attack3", false)
	animated_sprite.sprite_frames.set_animation_loop("jump", false)
	animated_sprite.sprite_frames.set_animation_loop("double_jump", false)

	# Animaciones de entrada y salida del bloqueo
	animated_sprite.sprite_frames.set_animation_loop("block_start", false)
	animated_sprite.sprite_frames.set_animation_loop("block_end", false)

	# Animaciones que SI se repiten
	animated_sprite.sprite_frames.set_animation_loop("run", true)
	animated_sprite.sprite_frames.set_animation_loop("idle", true)
	animated_sprite.sprite_frames.set_animation_loop("block_hold", true)

	# Detectar cuando termina una animacion
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:

	# =========================
	# GRAVEDAD
	# =========================

	if not is_on_floor():
		velocity.y += GRAVITY * delta


	# =========================
	# RECUPERAR SALTOS
	# =========================

	if is_on_floor():
		jumps_left = 2
		saltando = false


	# =========================
	# TIEMPO DEL COMBO
	# =========================

	if not atacando and combo_tiempo_restante > 0:

		combo_tiempo_restante -= delta

		if combo_tiempo_restante <= 0:
			combo_tiempo_restante = 0
			combo_step = 0


	# =========================
	# BLOQUEO CON L
	# =========================

	var block_pressed := Input.is_key_pressed(KEY_L)

	# Iniciar bloqueo al presionar L
	if block_pressed and not block_was_pressed:

		if bloqueo_estado == "" and not atacando and is_on_floor():
			iniciar_bloqueo()

	# Soltar L mientras mantiene la defensa
	if not block_pressed and bloqueo_estado == "hold":
		finalizar_bloqueo()

	block_was_pressed = block_pressed


	# =========================
	# SALTO Y DOBLE SALTO
	# =========================

	var space_pressed := Input.is_key_pressed(KEY_SPACE)

	if space_pressed and not space_was_pressed:

		# No permitir saltar durante el bloqueo
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
	# ATAQUE CON K
	# =========================

	var attack_pressed := Input.is_key_pressed(KEY_K)

	if attack_pressed and not attack_was_pressed:

		# No atacar mientras bloquea
		if bloqueo_estado == "":

			if atacando:

				# Guardar el siguiente golpe
				if combo_step < 3:
					ataque_en_cola = true

			else:

				# Continuar el combo
				if combo_tiempo_restante > 0 and combo_step < 3:
					iniciar_ataque(combo_step + 1)

				else:
					# Comenzar desde el primer golpe
					iniciar_ataque(1)

	attack_was_pressed = attack_pressed


	# =========================
	# MOVIMIENTO A / D
	# =========================

	var direction := 0.0

	if Input.is_key_pressed(KEY_A):
		direction = -1.0

	elif Input.is_key_pressed(KEY_D):
		direction = 1.0


	if not atacando and bloqueo_estado == "":

		if direction != 0:

			velocity.x = direction * SPEED

			# Direccion del personaje
			if direction < 0:
				animated_sprite.flip_h = false
			else:
				animated_sprite.flip_h = true

		else:

			velocity.x = move_toward(velocity.x, 0, SPEED)

	else:

		# Detener movimiento durante ataques o bloqueo
		velocity.x = 0


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
# INICIAR BLOQUEO
# =========================

func iniciar_bloqueo() -> void:

	bloqueo_estado = "start"
	velocity.x = 0

	# Reiniciar el combo al bloquear
	combo_step = 0
	ataque_en_cola = false
	combo_tiempo_restante = 0.0

	# Comenzar a desenvainar
	animated_sprite.play("block_start")


# =========================
# FINALIZAR BLOQUEO
# =========================

func finalizar_bloqueo() -> void:

	if bloqueo_estado == "":
		return

	bloqueo_estado = "end"

	# Animacion de guardar la espada
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

	velocity.x = 0

	var nombre_animacion := "attack%d" % numero

	animated_sprite.play(nombre_animacion)


# =========================
# CUANDO TERMINA UNA ANIMACION
# =========================

func _on_animation_finished() -> void:

	var animacion_actual := animated_sprite.animation

	# =========================
	# TERMINO EL INICIO DEL BLOQUEO
	# =========================

	if animacion_actual == "block_start" and bloqueo_estado == "start":

		# Si sigue apretando L, mantener defensa
		if Input.is_key_pressed(KEY_L):

			bloqueo_estado = "hold"
			animated_sprite.play("block_hold")

		else:

			# Si solto L, comenzar a guardar
			finalizar_bloqueo()

		return


	# =========================
	# TERMINO LA SALIDA DEL BLOQUEO
	# =========================

	if animacion_actual == "block_end" and bloqueo_estado == "end":

		bloqueo_estado = ""

		var direction := obtener_direccion()
		actualizar_animacion(direction)

		return


	# =========================
	# TERMINO UN ATAQUE
	# =========================

	if not atacando:
		return

	var ataque_actual := "attack%d" % combo_step

	if animacion_actual != ataque_actual:
		return

	# Si el jugador preparo otro golpe
	if ataque_en_cola and combo_step < 3:

		iniciar_ataque(combo_step + 1)
		return

	# Terminar ataque actual
	atacando = false
	ataque_en_cola = false

	# Permitir continuar el combo
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

	# No interrumpir ataques ni bloqueo
	if atacando or bloqueo_estado != "":
		return

	if not is_on_floor():

		# Mantener animacion aerea
		var animacion_aerea := "jump"

		if jumps_left == 0:
			animacion_aerea = "double_jump"

		if animated_sprite.animation != animacion_aerea:
			animated_sprite.play(animacion_aerea)

		return

	# Personaje en el suelo
	saltando = false

	if direction != 0:

		# CORRER
		if animated_sprite.animation != "run":
			animated_sprite.play("run")

	else:

		# QUIETO
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

	space_was_pressed = Input.is_key_pressed(KEY_SPACE)
	attack_was_pressed = Input.is_key_pressed(KEY_K)
	block_was_pressed = Input.is_key_pressed(KEY_L)

	animated_sprite.play("idle")
