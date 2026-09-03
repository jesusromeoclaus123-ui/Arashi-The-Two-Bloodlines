extends CharacterBody2D

const SPEED := 300.0
const GRAVITY := 700.0
const JUMP_FORCE := -500.0
const DOUBLE_JUMP_FORCE := -550.0

var jumps_left := 2
var space_was_pressed := false
var atacando := false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


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

	space_was_pressed = space_pressed


	# =========================
	# ATTACK2
	# =========================

	if Input.is_key_pressed(KEY_K) and not atacando:

		atacando = true
		velocity.x = 0

		animated_sprite.play("attack2")


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

			if direction < 0:
				animated_sprite.flip_h = false
			else:
				animated_sprite.flip_h = true

		else:

			velocity.x = move_toward(velocity.x, 0, SPEED)


	# =========================
	# ANIMACIONES
	# =========================

	if not atacando:

		if not is_on_floor():

			animated_sprite.play("jump")

		else:

			animated_sprite.play("idle")


	move_and_slide()


# =========================
# TERMINÓ ATTACK2
# =========================

func _on_animation_finished() -> void:

	if animated_sprite.animation == "attack2":

		atacando = false
