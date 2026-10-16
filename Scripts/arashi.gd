extends CharacterBody2D

# La interfaz escucha esta senal para actualizar la barra de energia.
signal energia_cambiada(actual: float, maxima: float)

# ENERGIA ELECTRICA
@export_range(1.0, 300.0, 1.0) var energia_maxima := 100.0
@export_range(0.0, 100.0, 1.0) var consumo_rayo_por_segundo := 20.0
@export_range(0.0, 100.0, 1.0) var recuperacion_por_segundo := 8.0
# Segundos de espera desde que se corta la descarga hasta regenerar.
@export_range(0.0, 10.0, 0.1) var espera_para_recuperar := 2.5
var energia_actual := 100.0
var tiempo_espera_recuperacion := 0.0

const SPEED := 500.0
const GRAVITY := 900.0
const JUMP_FORCE := -600.0
const DOUBLE_JUMP_FORCE := -700.0

# COMBO
const COMBO_WINDOW := 0.6
var combo_step := 0
var ataque_en_cola := false
var combo_tiempo_restante := 0.0

# DASH
const DASH_SPEED := 1200.0
const DASH_DURATION := 0.25
const DASH_COOLDOWN := 0.6
var en_dash := false
var dash_was_pressed := false
var dash_direccion := -1.0
var dash_tiempo_restante := 0.0
var dash_recarga_restante := 0.0

# JUGADOR
var jumps_left := 2
var space_was_pressed := false
var attack_was_pressed := false
var block_was_pressed := false
var rayo_was_pressed := false
var atacando := false
var saltando := false

# BLOQUEO: "", "start", "hold", "end"
var bloqueo_estado := ""

# RAYO: "", "start", "hold", "end"
var rayo_estado := ""
# En 'rayo' los frames son 0, 1, 2, 3, 4.
# Mostrar la descarga cuando aparece el tercero (indice 2).
const RAYO_FRAME_DISPARO := 2

# El nacimiento de los PNG del rayo esta cerca del borde derecho.
# Ajustar este valor si el nacimiento no coincide con la palma.
@export_range(0.5, 1.0, 0.01) var rayo_origen_en_imagen := 0.95

# CHECKPOINT
var punto_checkpoint: Vector2
var posicion_bandera: Vector2
var bandera_activada: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var lightning_origin: Marker2D = $LightningOrigin
@onready var lightning_beam: AnimatedSprite2D = $LightningOrigin/LightningBeam
var origen_rayo_izquierda := Vector2.ZERO


func _ready() -> void:
	energia_actual = energia_maxima
	energia_cambiada.emit(energia_actual, energia_maxima)
	punto_checkpoint = global_position
	origen_rayo_izquierda = lightning_origin.position

	# Animaciones que terminan al llegar al ultimo frame
	for anim in [
		"attack1", "attack2", "attack3",
		"jump", "double_jump", "block_start", "block_end",
		"dash", "rayo", "rayo_fin"
	]:
		animated_sprite.sprite_frames.set_animation_loop(anim, false)

	# Animaciones que se repiten
	for anim in ["run", "idle", "block_hold"]:
		animated_sprite.sprite_frames.set_animation_loop(anim, true)

	# El rayo externo tiene tres sprites en una sola animacion
	lightning_beam.sprite_frames.set_animation_loop("lightning_beam", true)
	lightning_beam.hide()
	lightning_beam.stop()

	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)
	if not animated_sprite.frame_changed.is_connected(_on_frame_changed):
		animated_sprite.frame_changed.connect(_on_frame_changed)

	actualizar_orientacion_rayo()


func _physics_process(delta: float) -> void:
	# DASH: tiempo de recarga
	if dash_recarga_restante > 0.0:
		dash_recarga_restante = maxf(dash_recarga_restante - delta, 0.0)

	# Recuperar saltos en el suelo
	if is_on_floor():
		jumps_left = 2
		saltando = false

	# Controles
	var direction := obtener_direccion()
	var space_pressed := Input.is_key_pressed(KEY_SPACE)
	var attack_pressed := Input.is_key_pressed(KEY_K)
	var block_pressed := Input.is_key_pressed(KEY_L)
	var dash_pressed := Input.is_key_pressed(KEY_SHIFT)
	var rayo_pressed := Input.is_key_pressed(KEY_J)

	# Activar dash (no puede interrumpir rayo, ataques ni bloqueo)
	if dash_pressed and not dash_was_pressed:
		if not en_dash and not atacando and bloqueo_estado == "" and rayo_estado == "" and dash_recarga_restante <= 0.0:
			iniciar_dash(direction)
	dash_was_pressed = dash_pressed

	# Movimiento fisico mientras esta en dash
	if en_dash:
		dash_tiempo_restante -= delta
		velocity.x = dash_direccion * DASH_SPEED
		velocity.y = 0.0
		move_and_slide()

		# No acumular nuevas pulsaciones durante el dash
		space_was_pressed = space_pressed
		attack_was_pressed = attack_pressed
		block_was_pressed = block_pressed
		rayo_was_pressed = rayo_pressed

		if dash_tiempo_restante <= 0.0:
			finalizar_dash()
		return

	# Gravedad normal, tambien mientras utiliza el rayo en el aire
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Tiempo disponible para continuar el combo
	if not atacando and combo_tiempo_restante > 0.0:
		combo_tiempo_restante -= delta
		if combo_tiempo_restante <= 0.0:
			combo_tiempo_restante = 0.0
			combo_step = 0

	# Consumir desde que el rayo es visible. El corte por energia agotada
	# se comprueba INDEPENDIENTEMENTE de la visibilidad del efecto, para
	# que nunca quede Arashi congelado en la animacion de disparo.
	if rayo_estado == "start" or rayo_estado == "hold":
		if lightning_beam.visible:
			cambiar_energia(-consumo_rayo_por_segundo * delta)
		if energia_actual <= 0.0:
			finalizar_rayo()
	else:
		# La cuenta regresiva comienza al soltar J o agotarse la energia.
		# No recuperamos energia durante este intervalo.
		if tiempo_espera_recuperacion > 0.0:
			tiempo_espera_recuperacion = maxf(tiempo_espera_recuperacion - delta, 0.0)
		elif rayo_estado == "" or rayo_estado == "end":
			cambiar_energia(recuperacion_por_segundo * delta)

	# Seguridad adicional: si por algun cambio de animacion se quedara
	# mostrando el ataque despues de agotarse, forzamos el cierre.
	if rayo_estado == "end" and animated_sprite.animation == "rayo":
		animated_sprite.play("rayo_fin")

	# Ataque electrico continuo con J. Si se agota la energia, requiere
	# soltar J y presionar de nuevo para volver a comenzar.
	if rayo_pressed and not rayo_was_pressed:
		if rayo_estado == "" and not atacando and bloqueo_estado == "" and energia_actual > 0.0:
			iniciar_rayo()
	elif not rayo_pressed and rayo_estado != "" and rayo_estado != "end":
		finalizar_rayo()
	rayo_was_pressed = rayo_pressed

	# Bloqueo con L
	if block_pressed and not block_was_pressed:
		if bloqueo_estado == "" and not atacando and rayo_estado == "" and is_on_floor():
			iniciar_bloqueo()
	if not block_pressed and bloqueo_estado == "hold":
		finalizar_bloqueo()
	block_was_pressed = block_pressed

	# Salto y doble salto con Espacio
	if space_pressed and not space_was_pressed:
		if jumps_left > 0 and bloqueo_estado == "" and rayo_estado == "":
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

	# Combo de tres ataques con K
	if attack_pressed and not attack_was_pressed:
		if bloqueo_estado == "" and rayo_estado == "":
			if atacando:
				if combo_step < 3:
					ataque_en_cola = true
			else:
				if combo_tiempo_restante > 0.0 and combo_step < 3:
					iniciar_ataque(combo_step + 1)
				else:
					iniciar_ataque(1)
	attack_was_pressed = attack_pressed

	# Movimiento A / D; no mover horizontalmente durante acciones
	if not atacando and bloqueo_estado == "" and rayo_estado == "":
		if direction != 0.0:
			velocity.x = direction * SPEED
			animated_sprite.flip_h = direction > 0.0
			actualizar_orientacion_rayo()
		else:
			velocity.x = move_toward(velocity.x, 0.0, SPEED)
	else:
		velocity.x = 0.0

	move_and_slide()

	# No sobreescribir las animaciones de ataque, defensa o electricidad
	if not atacando and bloqueo_estado == "" and rayo_estado == "":
		actualizar_animacion(direction)


# =========================
# RAYO ELECTRICO / ENERGIA
# =========================

func cambiar_energia(cantidad: float) -> void:
	var valor_nuevo := clampf(energia_actual + cantidad, 0.0, energia_maxima)
	# Comparar con igualdad exacta: una comparacion aproximada podria
	# dejar una fraccion minima de energia y evitar llegar al cero real.
	if valor_nuevo == energia_actual:
		return
	energia_actual = valor_nuevo
	energia_cambiada.emit(energia_actual, energia_maxima)


func iniciar_rayo() -> void:
	rayo_estado = "start"
	velocity.x = 0.0

	# El rayo reinicia la secuencia de golpes
	combo_step = 0
	ataque_en_cola = false
	combo_tiempo_restante = 0.0

	actualizar_orientacion_rayo()
	lightning_beam.hide()
	lightning_beam.stop()
	animated_sprite.play("rayo")


func _on_frame_changed() -> void:
	# El frame 3 (indice 2) es cuando empieza a salir la descarga
	if rayo_estado == "start" and animated_sprite.animation == "rayo":
		if animated_sprite.frame >= RAYO_FRAME_DISPARO:
			mostrar_rayo()


func mostrar_rayo() -> void:
	if rayo_estado != "start" and rayo_estado != "hold":
		return
	if energia_actual <= 0.0:
		finalizar_rayo()
		return
	actualizar_orientacion_rayo()
	if not lightning_beam.visible:
		lightning_beam.show()
		lightning_beam.play("lightning_beam")


func finalizar_rayo() -> void:
	if rayo_estado == "" or rayo_estado == "end":
		return
	rayo_estado = "end"
	# Reiniciar la espera cada vez que la habilidad se interrumpe.
	tiempo_espera_recuperacion = espera_para_recuperar
	lightning_beam.hide()
	lightning_beam.stop()
	animated_sprite.play("rayo_fin")


func actualizar_orientacion_rayo() -> void:
	# Coloca el Marker2D en la palma para cada direccion.
	# En el editor, acomodar LightningOrigin para Arashi mirando a la izquierda.
	lightning_origin.position.y = origen_rayo_izquierda.y
	if animated_sprite.flip_h:
		lightning_origin.position.x = -origen_rayo_izquierda.x
	else:
		lightning_origin.position.x = origen_rayo_izquierda.x

	# Cada PNG nace cerca de su borde derecho. Ajustamos el centro
	# del AnimatedSprite2D hasta que su nacimiento quede en el marker.
	lightning_beam.flip_h = animated_sprite.flip_h
	var textura: Texture2D = lightning_beam.sprite_frames.get_frame_texture("lightning_beam", 0)
	if textura != null:
		var ancho_visible := float(textura.get_width()) * absf(lightning_beam.scale.x)
		var separacion := (rayo_origen_en_imagen - 0.5) * ancho_visible
		lightning_beam.position.x = separacion if animated_sprite.flip_h else -separacion
		lightning_beam.position.y = 0.0


# =========================
# DASH
# =========================

func iniciar_dash(direction: float) -> void:
	en_dash = true
	dash_tiempo_restante = DASH_DURATION

	if direction != 0.0:
		dash_direccion = direction
		animated_sprite.flip_h = direction > 0.0
	else:
		dash_direccion = 1.0 if animated_sprite.flip_h else -1.0

	actualizar_orientacion_rayo()
	combo_step = 0
	ataque_en_cola = false
	combo_tiempo_restante = 0.0
	velocity.x = dash_direccion * DASH_SPEED
	velocity.y = 0.0
	animated_sprite.play("dash")


func finalizar_dash() -> void:
	en_dash = false
	dash_recarga_restante = DASH_COOLDOWN
	velocity.x = 0.0
	actualizar_animacion(obtener_direccion())


func esta_en_dash() -> bool:
	return en_dash


# =========================
# BLOQUEO
# =========================

func iniciar_bloqueo() -> void:
	bloqueo_estado = "start"
	velocity.x = 0.0
	combo_step = 0
	ataque_en_cola = false
	combo_tiempo_restante = 0.0
	animated_sprite.play("block_start")


func finalizar_bloqueo() -> void:
	if bloqueo_estado == "":
		return
	bloqueo_estado = "end"
	animated_sprite.play("block_end")


func esta_bloqueando() -> bool:
	return bloqueo_estado == "hold"


# =========================
# ATAQUES CON K
# =========================

func iniciar_ataque(numero: int) -> void:
	atacando = true
	combo_step = numero
	ataque_en_cola = false
	combo_tiempo_restante = 0.0
	velocity.x = 0.0
	animated_sprite.play("attack%d" % numero)


# =========================
# FIN DE ANIMACIONES
# =========================

func _on_animation_finished() -> void:
	var animacion_actual := animated_sprite.animation

	if animacion_actual == "dash":
		return  # La duracion se controla por tiempo en _physics_process

	# Final de la preparacion electrica: sostener ultimo frame
	if animacion_actual == "rayo" and rayo_estado == "start":
		if Input.is_key_pressed(KEY_J) and energia_actual > 0.0:
			rayo_estado = "hold"
			mostrar_rayo()
		else:
			finalizar_rayo()
		return

	# Recuperacion del rayo
	if animacion_actual == "rayo_fin" and rayo_estado == "end":
		rayo_estado = ""
		actualizar_animacion(obtener_direccion())
		return

	if animacion_actual == "block_start" and bloqueo_estado == "start":
		if Input.is_key_pressed(KEY_L):
			bloqueo_estado = "hold"
			animated_sprite.play("block_hold")
		else:
			finalizar_bloqueo()
		return

	if animacion_actual == "block_end" and bloqueo_estado == "end":
		bloqueo_estado = ""
		actualizar_animacion(obtener_direccion())
		return

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
# DIRECCION Y ANIMACIONES
# =========================

func obtener_direccion() -> float:
	if Input.is_key_pressed(KEY_A):
		return -1.0
	elif Input.is_key_pressed(KEY_D):
		return 1.0
	return 0.0


func actualizar_animacion(direction: float) -> void:
	if en_dash or atacando or bloqueo_estado != "" or rayo_estado != "":
		return

	if not is_on_floor():
		var animacion_aerea := "jump"
		if jumps_left == 0:
			animacion_aerea = "double_jump"
		if animated_sprite.animation != animacion_aerea:
			animated_sprite.play(animacion_aerea)
		return

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
	global_position = posicion_bandera if bandera_activada else punto_checkpoint
	velocity = Vector2.ZERO

	atacando = false
	saltando = false
	jumps_left = 2
	bloqueo_estado = ""
	rayo_estado = ""
	tiempo_espera_recuperacion = 0.0
	lightning_beam.hide()
	lightning_beam.stop()

	combo_step = 0
	ataque_en_cola = false
	combo_tiempo_restante = 0.0

	en_dash = false
	dash_tiempo_restante = 0.0
	dash_recarga_restante = 0.0

	space_was_pressed = Input.is_key_pressed(KEY_SPACE)
	attack_was_pressed = Input.is_key_pressed(KEY_K)
	block_was_pressed = Input.is_key_pressed(KEY_L)
	dash_was_pressed = Input.is_key_pressed(KEY_SHIFT)
	rayo_was_pressed = Input.is_key_pressed(KEY_J)

	# Por ahora recuperamos la energia al reaparecer.
	energia_actual = energia_maxima
	energia_cambiada.emit(energia_actual, energia_maxima)

	actualizar_orientacion_rayo()
	animated_sprite.play("idle")
