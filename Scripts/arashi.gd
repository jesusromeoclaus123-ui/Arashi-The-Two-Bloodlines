
extends CharacterBody2D

const SPEED := 500.0
const GRAVITY := 900.0
const JUMP_FORCE := -600.0
const DOUBLE_JUMP_FORCE := -700.0

var jumps_left := 2
var space_was_pressed := false
var atacando := false
var saltando := false

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
	animated_sprite.sprite_frames.set_animation_loop("attack2", false)
	animated_sprite.sprite_frames.set_animation_loop("jump", false)
	animated_sprite.sprite_frames.set_animation_loop("double_jump", false)

	# Animaciones que SI se repiten
	animated_sprite.sprite_frames.set_animation_loop("run", true)
	animated_sprite.sprite_frames.set_animation_loop("idle", true)


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
	# SALTO Y DOBLE SALTO
	# =========================

	var space_pressed := Input.is_key_pressed(KEY_SPACE)

	if space_pressed and not space_was_pressed:

		if jumps_left > 0:

			if jumps_left == 2:
				# PRIMER SALTO
				velocity.y = JUMP_FORCE
				saltando = true

				if not atacando:
					animated_sprite.play("jump")

			elif jumps_left == 1:
				# SEGUNDO SALTO
				velocity.y = DOUBLE_JUMP_FORCE
				saltando = true

				if not atacando:
					animated_sprite.play("double_jump")

			jumps_left -= 1

	space_was_pressed = space_pressed


	# =========================
	# ATTACK2
	# =========================

	if Input.is_key_pressed(KEY_K) and not atacando:
		realizar_ataque()


	# =========================
	# MOVIMIENTO A / D
	# =========================

	var direction := 0.0

	if Input.is_key_pressed(KEY_A):
		direction = -1.0

	elif Input.is_key_pressed(KEY_D):
		direction = 1.0


	if not atacando:

		if direction != 0:

			velocity.x = direction * SPEED

			# Dirección del personaje
			if direction < 0:
				animated_sprite.flip_h = false
			else:
				animated_sprite.flip_h = true

		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)


	# =========================
	# MOVIMIENTO FISICO
	# =========================

	move_and_slide()


	# =========================
	# ANIMACIONES
	# =========================

	if not atacando:

		if is_on_floor():

			saltando = false

			# CORRER
			if direction != 0:

				if animated_sprite.animation != "run":
					animated_sprite.play("run")

			# QUIETO
			else:

				if animated_sprite.animation != "idle":
					animated_sprite.play("idle")

		elif saltando:
			# Mantener la animación de salto
			# o doble salto sin reiniciarla.
			pass


# =========================
# REALIZAR ATAQUE
# =========================

func realizar_ataque() -> void:

	atacando = true
	velocity.x = 0

	animated_sprite.play("attack2")

	# Cantidad de frames de attack2
	var cantidad_frames := animated_sprite.sprite_frames.get_frame_count("attack2")

	# FPS de attack2
	var fps := animated_sprite.sprite_frames.get_animation_speed("attack2")

	# Evitar división por cero
	if fps <= 0:
		fps = 5.0

	# Duración total de la animación
	var duracion := float(cantidad_frames) / fps

	await get_tree().create_timer(duracion).timeout

	atacando = false
	velocity.x = 0

	# Recuperar la animación correspondiente
	if is_on_floor():

		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_D):
			animated_sprite.play("run")
		else:
			animated_sprite.play("idle")

	elif jumps_left == 0:
		animated_sprite.play("double_jump")

	else:
		animated_sprite.play("jump")


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

	animated_sprite.play("idle")
