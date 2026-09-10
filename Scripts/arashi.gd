
extends CharacterBody2D

const SPEED := 300.0
const GRAVITY := 700.0
const JUMP_FORCE := -500.0
const DOUBLE_JUMP_FORCE := -550.0

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

	# attack2 NO se repite
	animated_sprite.sprite_frames.set_animation_loop("attack2", false)

	# jump NO se repite
	animated_sprite.sprite_frames.set_animation_loop("jump", false)


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
	# SALTO
	# =========================

	var space_pressed := Input.is_key_pressed(KEY_SPACE)

	if space_pressed and not space_was_pressed:

		if jumps_left > 0:

			if jumps_left == 2:
				velocity.y = JUMP_FORCE
			else:
				velocity.y = DOUBLE_JUMP_FORCE

			jumps_left -= 1
			saltando = true

			# Reproducir animación de salto
			animated_sprite.play("jump")

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
				# A = izquierda
				animated_sprite.flip_h = true
			else:
				# D = derecha
				animated_sprite.flip_h = false

		else:

			velocity.x = move_toward(velocity.x, 0, SPEED)


	# =========================
	# ANIMACIONES
	# =========================

	if not atacando:

		if saltando:
			# La animación ya se inició al apretar espacio.
			# No la reiniciamos constantemente.
			pass

		else:
			animated_sprite.play("idle")


	move_and_slide()


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

	# Volver a idle
	atacando = false
	velocity.x = 0

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

	animated_sprite.play("idle")
