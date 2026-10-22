extends CharacterBody2D

# La interfaz escucha esta senal para actualizar la barra de energia.
signal energia_cambiada(actual: float, maxima: float)
signal vida_cambiada(actual: float, maxima: float)
# Se emite solamente si un ataque enemigo fue bloqueado correctamente.
# Servira para el contador de 3 bloqueos del Tutorial.
signal golpe_bloqueado(posicion_atacante: Vector2)

# ENERGIA ELECTRICA
@export_range(1.0, 300.0, 1.0) var energia_maxima := 100.0
@export_range(0.0, 100.0, 1.0) var consumo_rayo_por_segundo := 20.0
@export_range(0.0, 100.0, 1.0) var recuperacion_por_segundo := 8.0
# Segundos de espera desde que se corta la descarga hasta regenerar.
@export_range(0.0, 10.0, 0.1) var espera_para_recuperar := 2.5
var energia_actual := 100.0
var tiempo_espera_recuperacion := 0.0

# VIDA DE ARASHI
@export_range(1.0, 500.0, 1.0) var vida_maxima := 100.0
@export_range(0.0, 5.0, 0.1) var segundos_invulnerable := 1.0
var vida_actual := 100.0
var tiempo_invulnerable_restante := 0.0
var esta_muerto := false

# NUEVO: reaccion al golpe y secuencia de derrota.
@export_range(0.05, 1.0, 0.05) var duracion_destello_dano: float = 0.15
@export_range(0.0, 5.0, 0.1) var tiempo_cuerpo_en_suelo: float = 1.0
@export_range(0.1, 5.0, 0.1) var duracion_fundido_derrota: float = 1.5
var recibiendo_dano: bool = false
var tiempo_destello_restante: float = 0.0
var color_sprite_original: Color = Color.WHITE
var transicion_derrota_iniciada: bool = false

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
@export_range(0.0, 100.0, 1.0) var costo_dash_porcentaje := 25.0

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

# BLOQUEO: "", "start", "hold", "hit", "end"
var bloqueo_estado := ""

# RAYO: "", "start", "hold", "end"
var rayo_estado := ""
# En 'rayo' los frames son 0, 1, 2, 3, 4.
# Mostrar la descarga cuando aparece el tercero (indice 2).
const RAYO_FRAME_DISPARO := 2

# El nacimiento de los PNG del rayo esta cerca del borde derecho.
# Ajustar este valor si el nacimiento no coincide con la palma.
@export_range(0.5, 1.0, 0.01) var rayo_origen_en_imagen := 0.95

# =========================
# DANO DE ARASHI CONTRA ENEMIGOS
# =========================
# Los valores se pueden ajustar desde el Inspector.
@export_range(1.0, 100.0, 1.0) var dano_katana_1: float = 20.0
@export_range(1.0, 100.0, 1.0) var dano_katana_2: float = 25.0
@export_range(1.0, 100.0, 1.0) var dano_katana_3: float = 35.0

# Indice del primer frame que puede golpear (el primero es 0).
@export_range(0, 20, 1) var frame_golpe_1: int = 1
@export_range(0, 20, 1) var frame_golpe_2: int = 1
@export_range(0, 20, 1) var frame_golpe_3: int = 1
@export_range(1, 10, 1) var duracion_golpe_en_frames: int = 2

@export_range(1.0, 100.0, 1.0) var dano_rayo_por_pulso: float = 10.0
@export_range(0.1, 3.0, 0.05) var intervalo_pulso_rayo: float = 0.5

# Cada golpe de katana puede afectar a un enemigo UNA sola vez.
var enemigos_golpeados_este_ataque: Dictionary = {}
var tiempo_para_pulso_rayo: float = 0.0

# CHECKPOINT
var punto_checkpoint: Vector2
var posicion_bandera: Vector2
var bandera_activada: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var escala_original_x: float = absf(animated_sprite.scale.x)
@onready var lightning_origin: Marker2D = $LightningOrigin
@onready var lightning_beam: AnimatedSprite2D = $LightningOrigin/LightningBeam
@onready var katana_hitbox: Area2D = $KatanaHitbox
@onready var rayo_hitbox: Area2D = $LightningOrigin/RayoHitbox
@onready var colision_katana: CollisionShape2D = $KatanaHitbox/CollisionShape2D
@onready var colision_rayo: CollisionShape2D = $LightningOrigin/RayoHitbox/CollisionShape2D
@onready var sonido_salto: AudioStreamPlayer2D = $SonidoSalto
@onready var sonido_dash: AudioStreamPlayer2D = $SonidoDash
@onready var sonido_rayo: AudioStreamPlayer2D = $SonidoRayo
@onready var sonido_katana: AudioStreamPlayer2D = $SonidoKatana
@onready var sonido_bloqueo: AudioStreamPlayer2D = $SonidoBloqueo
@onready var sonido_dano: AudioStreamPlayer2D = $SonidoDano
@onready var sonido_derrota: AudioStreamPlayer2D = $SonidoDerrota







var katana_posicion_derecha: Vector2 = Vector2.ZERO
var rayo_hitbox_posicion_derecha: Vector2 = Vector2.ZERO
var colision_katana_x_derecha: float = 0.0
var colision_rayo_x_derecha: float = 0.0
var origen_rayo_derecha := Vector2.ZERO



func _ready() -> void:
	# Repetir el sonido del rayo.
	if sonido_rayo.stream is AudioStreamMP3:
		sonido_rayo.stream.loop = true

	vida_actual = vida_maxima
	vida_cambiada.emit(vida_actual, vida_maxima)
	energia_actual = energia_maxima
	energia_cambiada.emit(energia_actual, energia_maxima)
	punto_checkpoint = global_position
	origen_rayo_derecha = lightning_origin.position
	# Guardar posiciones con Arashi mirando hacia la DERECHA en el editor.
	# Colocalas en el editor antes de ejecutar la escena.
	katana_posicion_derecha = katana_hitbox.position
	rayo_hitbox_posicion_derecha = rayo_hitbox.position
	# Guardar los desplazamientos de las formas de colision por separado.
	# Estos tambien necesitan invertirse al usar flip_h.
	colision_katana_x_derecha = colision_katana.position.x
	colision_rayo_x_derecha = colision_rayo.position.x

	# Animaciones que terminan al llegar al ultimo frame.
	for anim in [
		"attack1", "attack2", "attack3",
		"jump", "double_jump", "block_start", "block_hit", "block_end",
		"dash", "rayo", "rayo_fin", "hurt", "death"
	]:
		if animated_sprite.sprite_frames.has_animation(anim):
			animated_sprite.sprite_frames.set_animation_loop(anim, false)
		else:
			push_warning("Falta la animacion '%s' en Arashi." % anim)

	color_sprite_original = animated_sprite.modulate

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

	

	# Preparar Arashi mirando hacia la derecha desde el inicio
	animated_sprite.flip_h = true

	# Corregir inmediatamente la orientacion del idle
	animated_sprite.scale.x = -escala_original_x

	# Iniciar la animacion idle
	animated_sprite.play("idle")

	# Mantener la animacion pausada durante los dialogos
	animated_sprite.process_mode = Node.PROCESS_MODE_INHERIT

	# Actualizar orientacion del rayo
	actualizar_orientacion_rayo()




func _physics_process(delta: float) -> void:
	# Mientras termina la animacion de derrota, no aceptar controles.
	# Mantenemos la gravedad por si Arashi fue derrotado en el aire.
	if esta_muerto:
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		move_and_slide()
		return

	# Invulnerabilidad y destello rojo despues de recibir dano.
	if tiempo_invulnerable_restante > 0.0:
		tiempo_invulnerable_restante = maxf(tiempo_invulnerable_restante - delta, 0.0)
	if tiempo_destello_restante > 0.0:
		tiempo_destello_restante = maxf(tiempo_destello_restante - delta, 0.0)
	actualizar_color_dano()

	# Durante hurt no mover, atacar ni iniciar habilidades.
	# Actualizamos los estados de las teclas para evitar pulsaciones retenidas.
	if recibiendo_dano:
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		move_and_slide()
		space_was_pressed = Input.is_key_pressed(KEY_SPACE)
		attack_was_pressed = Input.is_key_pressed(KEY_K)
		block_was_pressed = Input.is_key_pressed(KEY_L)
		dash_was_pressed = Input.is_key_pressed(KEY_SHIFT)
		rayo_was_pressed = Input.is_key_pressed(KEY_J)
		return

	# PRUEBA: P provoca una derrota de prueba, incluyendo la animacion.
	# Esta tecla se puede quitar cuando terminemos de comprobar el sistema.
	if Input.is_key_pressed(KEY_P):
		morir()
		return


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
				# Salto normal
				velocity.y = JUMP_FORCE
				sonido_salto.play()
				saltando = true
				if not atacando:
					animated_sprite.play("jump")

			elif jumps_left == 1:
				# Doble salto
				velocity.y = DOUBLE_JUMP_FORCE
				sonido_salto.play()
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

	# Comprobar impactos despues de mover a Arashi.
	procesar_dano_a_enemigos(delta)


# =========================
# KATANA Y RAYO: DETECCION DE IMPACTOS
# =========================

func obtener_frame_golpe(numero: int) -> int:
	match numero:
		1:
			return frame_golpe_1
		2:
			return frame_golpe_2
		3:
			return frame_golpe_3
	return 1


func obtener_dano_katana(numero: int) -> float:
	match numero:
		1:
			return dano_katana_1
		2:
			return dano_katana_2
		3:
			return dano_katana_3
	return 0.0


func procesar_dano_a_enemigos(delta: float) -> void:
	if esta_muerto:
		return

	# La katana solo golpea durante los frames centrales del ataque.
	if atacando and combo_step >= 1 and combo_step <= 3:
		var animacion_esperada: String = "attack%d" % combo_step
		if animated_sprite.animation == animacion_esperada:
			var frame_inicio: int = obtener_frame_golpe(combo_step)
			var frame_actual: int = animated_sprite.frame
			if frame_actual >= frame_inicio and frame_actual < frame_inicio + duracion_golpe_en_frames:
				for cuerpo in katana_hitbox.get_overlapping_bodies():
					if not is_instance_valid(cuerpo) or cuerpo == self:
						continue
					if not cuerpo.is_in_group("enemigos") or not cuerpo.has_method("recibir_dano"):
						continue
					var identificador: int = cuerpo.get_instance_id()
					if enemigos_golpeados_este_ataque.has(identificador):
						continue
					enemigos_golpeados_este_ataque[identificador] = true
					cuerpo.recibir_dano(obtener_dano_katana(combo_step))

	# La descarga electrica golpea cada cierto intervalo mientras es visible.
	if lightning_beam.visible and (rayo_estado == "start" or rayo_estado == "hold"):
		tiempo_para_pulso_rayo -= delta
		if tiempo_para_pulso_rayo <= 0.0:
			tiempo_para_pulso_rayo = intervalo_pulso_rayo
			for cuerpo in rayo_hitbox.get_overlapping_bodies():
				if not is_instance_valid(cuerpo) or cuerpo == self:
					continue
				if cuerpo.is_in_group("enemigos") and cuerpo.has_method("recibir_dano"):
					cuerpo.recibir_dano(dano_rayo_por_pulso)
	else:
		tiempo_para_pulso_rayo = 0.0


# =========================
# VIDA Y DANO
# =========================



func recibir_dano(cantidad: float) -> void:
	if esta_muerto or cantidad <= 0.0 or tiempo_invulnerable_restante > 0.0:
		return

	# Reducir la vida de Arashi.
	vida_actual = maxf(0.0, vida_actual - cantidad)
	vida_cambiada.emit(vida_actual, vida_maxima)

	print("VIDA ACTUAL DE ARASHI: ", vida_actual)

	# Si el golpe es fatal, reproducir solo el sonido de derrota.
	if vida_actual <= 10.0:
		morir()
		return

	# Si Arashi sobrevive, reproducir el sonido de dano.
	sonido_dano.play()

	# Activar invulnerabilidad temporal.
	tiempo_invulnerable_restante = segundos_invulnerable

	# Activar destello rojo.
	tiempo_destello_restante = duracion_destello_dano
	actualizar_color_dano()

	# Reproducir animacion de daño.
	iniciar_animacion_dano()



func actualizar_color_dano() -> void:
	if tiempo_destello_restante > 0.0 and not esta_muerto:
		animated_sprite.modulate = color_sprite_original * Color(1.0, 0.20, 0.20, 1.0)
	else:
		animated_sprite.modulate = color_sprite_original


func detener_acciones_por_dano() -> void:
	# Si hay rayo activo, cortarlo sin reproducir rayo_fin:
	# la animacion hurt/death debe tener prioridad.
	if rayo_estado != "":
		tiempo_espera_recuperacion = espera_para_recuperar
	rayo_estado = ""
	lightning_beam.hide()
	lightning_beam.stop()
	sonido_rayo.stop()
	tiempo_para_pulso_rayo = 0.0

	# Interrumpir combo, bloqueo y dash sin cambiar a otras animaciones.
	atacando = false
	ataque_en_cola = false
	combo_step = 0
	combo_tiempo_restante = 0.0
	enemigos_golpeados_este_ataque.clear()
	bloqueo_estado = ""
	if en_dash:
		dash_recarga_restante = DASH_COOLDOWN
	en_dash = false
	dash_tiempo_restante = 0.0
	velocity.x = 0.0


func iniciar_animacion_dano() -> void:
	detener_acciones_por_dano()
	if animated_sprite.sprite_frames.has_animation("hurt") and animated_sprite.sprite_frames.get_frame_count("hurt") > 0:
		recibiendo_dano = true
		animated_sprite.play("hurt")
	else:
		push_warning("Falta la animacion 'hurt' en Arashi.")
		recibiendo_dano = false
		actualizar_animacion(obtener_direccion())



func morir() -> void:
	if esta_muerto:
		return

	esta_muerto = true
	recibiendo_dano = false

	detener_acciones_por_dano()

	velocity = Vector2.ZERO
	tiempo_destello_restante = 0.0
	animated_sprite.modulate = color_sprite_original

	print("ARASHI DERROTADO - REPRODUCIENDO DEATH")

	# Detener el sonido de daño para que no se superponga.
	sonido_dano.stop()

	# Reproducir sonido de derrota una sola vez.
	sonido_derrota.play()

	# Reproducir la animacion de muerte.
	if animated_sprite.sprite_frames.has_animation("death") and animated_sprite.sprite_frames.get_frame_count("death") > 0:
		animated_sprite.play("death")
	else:
		push_warning("Falta la animacion 'death' en Arashi.")
		iniciar_transicion_derrota()



func iniciar_transicion_derrota() -> void:
	if transicion_derrota_iniciada:
		return
	transicion_derrota_iniciada = true

	# Mantener visible el ultimo sprite de death durante un instante.
	if tiempo_cuerpo_en_suelo > 0.0:
		await get_tree().create_timer(tiempo_cuerpo_en_suelo).timeout
	if not is_inside_tree():
		return

	# Reutilizar la pantalla negra que ya existe en Tutorial.
	var pantalla_negra: ColorRect = get_tree().current_scene.get_node_or_null(
		"TransicionMuerte/PantallaNegra"
	) as ColorRect
	if pantalla_negra != null:
		pantalla_negra.show()
		pantalla_negra.modulate.a = 0.0
		var tween: Tween = create_tween()
		tween.tween_property(pantalla_negra, "modulate:a", 1.0, duracion_fundido_derrota)
		await tween.finished
	else:
		push_warning("No se encontro TransicionMuerte/PantallaNegra; se abre el menu sin fundido.")

	if is_inside_tree():
		get_tree().change_scene_to_file("res://menu_derrota.tscn")


# =========================
# BLOQUEO DE ATAQUES ENEMIGOS
# =========================

# Bloquea una vez completada la preparacion (block_start) y mientras
# sostiene la defensa o reacciona al impacto con block_hit.
func esta_bloqueando_desde(posicion_atacante: Vector2) -> bool:
	if esta_muerto or bloqueo_estado not in ["hold", "hit"]:
		return false

	var distancia_x: float = posicion_atacante.x - global_position.x
	if absf(distancia_x) < 1.0:
		return false

	# Los sprites originales de Arashi miran hacia la izquierda.
	# flip_h = false: mira a izquierda; true: mira a derecha.
	if distancia_x < 0.0:
		return not animated_sprite.flip_h
	return animated_sprite.flip_h


# El enemigo llama esta funcion en vez de recibir_dano() directamente.
# Devuelve true si el golpe fue bloqueado; en otro caso false.
# El enemigo existente puede seguir llamandola sin usar el valor retornado.

func recibir_ataque_enemigo(cantidad: float, posicion_atacante: Vector2) -> bool:
	if esta_muerto or cantidad <= 0.0:
		return false

	# Arashi bloquea correctamente el ataque enemigo.
	if esta_bloqueando_desde(posicion_atacante):
		print("ARASHI BLOQUEO EL ATAQUE")

		# Reproducir el choque metalico.
		sonido_bloqueo.play()

		# Avisar al contador del Tutorial.
		golpe_bloqueado.emit(posicion_atacante)

		# Reproducir la animacion del impacto.
		if bloqueo_estado == "hold":
			if animated_sprite.sprite_frames.has_animation("block_hit") and animated_sprite.sprite_frames.get_frame_count("block_hit") > 0:
				bloqueo_estado = "hit"
				animated_sprite.play("block_hit")
			else:
				push_warning("Falta la animacion 'block_hit' o no tiene fotogramas.")

		return true

	# Si no bloqueo, recibe dano normalmente.
	recibir_dano(cantidad)
	return false



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
	tiempo_para_pulso_rayo = 0.0
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

		# Reproducir sonido cuando aparece la electricidad.
		if not sonido_rayo.playing:
			sonido_rayo.play(3.0)




func finalizar_rayo() -> void:
	if rayo_estado == "" or rayo_estado == "end":
		return

	rayo_estado = "end"

	tiempo_espera_recuperacion = espera_para_recuperar

	lightning_beam.hide()
	lightning_beam.stop()

	# Detener el sonido al cortar la descarga.
	sonido_rayo.stop()

	animated_sprite.play("rayo_fin")



func actualizar_orientacion_rayo() -> void:
	# En el editor, Arashi y las hitboxes estan configurados mirando a la DERECHA.
	# Los sprites originales miran a la izquierda: flip_h=true significa DERECHA.
	# Solo reflejamos las posiciones cuando Arashi pasa a mirar a la IZQUIERDA.
	var invertir_posiciones := not animated_sprite.flip_h

	lightning_origin.position.y = origen_rayo_derecha.y
	lightning_origin.position.x = -origen_rayo_derecha.x if invertir_posiciones else origen_rayo_derecha.x

	# Reflejar las Areas2D respecto del centro de Arashi.
	katana_hitbox.position.x = -katana_posicion_derecha.x if invertir_posiciones else katana_posicion_derecha.x
	rayo_hitbox.position.x = -rayo_hitbox_posicion_derecha.x if invertir_posiciones else rayo_hitbox_posicion_derecha.x

	# Tambien reflejar el desplazamiento local de cada CollisionShape2D.
	colision_katana.position.x = -colision_katana_x_derecha if invertir_posiciones else colision_katana_x_derecha
	colision_rayo.position.x = -colision_rayo_x_derecha if invertir_posiciones else colision_rayo_x_derecha

	# Mantener la orientacion REAL del efecto electrico.
	# Los PNG nacen por el extremo derecho y avanzan hacia la izquierda.
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
	# Calcular el costo del dash
	var costo_dash: float = energia_maxima * (costo_dash_porcentaje / 100.0)

	# Comprobar que tenga energia suficiente
	if energia_actual < costo_dash:
		return

	# Consumir energia
	cambiar_energia(-costo_dash)

	# Reiniciar la espera de regeneracion
	tiempo_espera_recuperacion = espera_para_recuperar

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

	# Reproducir animacion del dash
	animated_sprite.play("dash")

	# Reproducir sonido del dash
	sonido_dash.play()


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
	return bloqueo_estado == "hold" or bloqueo_estado == "hit"


# =========================
# ATAQUES CON K
# =========================


func iniciar_ataque(numero: int) -> void:
	atacando = true
	combo_step = numero
	ataque_en_cola = false
	combo_tiempo_restante = 0.0
	enemigos_golpeados_este_ataque.clear()
	velocity.x = 0.0

	# Reproducir la animacion correspondiente.
	animated_sprite.play("attack%d" % numero)

	# Variar ligeramente el tono de cada golpe.
	match numero:
		1:
			sonido_katana.pitch_scale = 1.0
		2:
			sonido_katana.pitch_scale = 1.15
		3:
			sonido_katana.pitch_scale = 0.85

	# Reproducir el sonido de la katana.
	sonido_katana.play()



# =========================
# FIN DE ANIMACIONES
# =========================

func _on_animation_finished() -> void:
	var animacion_actual := animated_sprite.animation

	# Las reacciones tienen prioridad sobre todas las demas animaciones.
	if animacion_actual == "death" and esta_muerto:
		iniciar_transicion_derrota()
		return

	if animacion_actual == "hurt" and recibiendo_dano and not esta_muerto:
		recibiendo_dano = false
		actualizar_animacion(obtener_direccion())
		return

	if esta_muerto or recibiendo_dano:
		return

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

	# Al terminar el impacto vuelve a defenderse si L sigue presionada.
	# Si se solto L durante el impacto, reproduce la salida normal.
	if animacion_actual == "block_hit" and bloqueo_estado == "hit":
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
	if esta_muerto or recibiendo_dano or en_dash or atacando or bloqueo_estado != "" or rayo_estado != "":
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
	esta_muerto = false
	recibiendo_dano = false
	transicion_derrota_iniciada = false
	tiempo_destello_restante = 0.0
	animated_sprite.modulate = color_sprite_original
	global_position = posicion_bandera if bandera_activada else punto_checkpoint
	velocity = Vector2.ZERO

	atacando = false
	saltando = false
	jumps_left = 2
	bloqueo_estado = ""
	rayo_estado = ""
	tiempo_para_pulso_rayo = 0.0
	enemigos_golpeados_este_ataque.clear()
	tiempo_espera_recuperacion = 0.0
	lightning_beam.hide()
	lightning_beam.stop()
	sonido_rayo.stop()

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

	# Al reaparecer, restaurar la vida y evitar dano inmediato.
	vida_actual = vida_maxima
	tiempo_invulnerable_restante = segundos_invulnerable
	vida_cambiada.emit(vida_actual, vida_maxima)

	# Por ahora recuperamos la energia al reaparecer.
	energia_actual = energia_maxima
	energia_cambiada.emit(energia_actual, energia_maxima)

	actualizar_orientacion_rayo()
	animated_sprite.play("idle")
	
# =====================================
# CORREGIR ORIENTACION DEL IDLE
# =====================================

func _process(_delta: float) -> void:
	if animated_sprite.animation == "idle":
		# Invertir solamente los sprites de respiracion
		animated_sprite.scale.x = -escala_original_x
	else:
		# Mantener las demas animaciones normales
		animated_sprite.scale.x = escala_original_x
