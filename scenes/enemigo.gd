extends CharacterBody2D

const SPEED: float = 100.0
const GRAVITY: float = 700.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var jugador: CharacterBody2D


func _ready() -> void:
	print("================================")
	print("ENEMIGO FUNCIONANDO")
	print("================================")

	jugador = get_tree().get_first_node_in_group("player") as CharacterBody2D

	if jugador:
		print("JUGADOR ENCONTRADO: ", jugador.name)
	else:
		print("NO ENCUENTRO AL JUGADOR")


func _physics_process(delta: float) -> void:

	print("ENEMIGO EJECUTANDO")

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if jugador == null:
		animated_sprite.play("idle")
		move_and_slide()
		return

	if jugador.global_position.x < global_position.x:
		velocity.x = -SPEED
		animated_sprite.flip_h = true
	else:
		velocity.x = SPEED
		animated_sprite.flip_h = false

	animated_sprite.play("walk")

	move_and_slide()
