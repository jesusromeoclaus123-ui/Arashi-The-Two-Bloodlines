extends CharacterBody2D

const SPEED := 300.0
const GRAVITY := 700.0
const JUMP_FORCE := -400.0
const DOUBLE_JUMP_FORCE := -350.0

var jumps_left := 2
var space_was_pressed := false


func _physics_process(delta: float) -> void:
	# Gravedad
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Recuperar los dos saltos al tocar el suelo
	if is_on_floor():
		jumps_left = 2

	# Detectar una pulsación NUEVA de espacio
	var space_pressed := Input.is_key_pressed(KEY_SPACE)

	if space_pressed and not space_was_pressed:
		if jumps_left > 0:

			if jumps_left == 2:
				velocity.y = JUMP_FORCE
			else:
				velocity.y = DOUBLE_JUMP_FORCE

			jumps_left -= 1

	space_was_pressed = space_pressed

	# Movimiento A / D
	var direction := 0.0

	if Input.is_key_pressed(KEY_A):
		direction = -1.0
	elif Input.is_key_pressed(KEY_D):
		direction = 1.0

	if direction != 0:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
