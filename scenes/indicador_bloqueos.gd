extends CanvasLayer

signal entrenamiento_completado

# Arrastra aqui, desde Tutorial.tscn, el nodo del samurai de entrenamiento.
@export var samurai_entrenamiento: CharacterBody2D

@onready var panel_bloqueos: PanelContainer = $PanelBloqueos
@onready var texto_bloqueos: Label = $PanelBloqueos/VBoxContainer/TextoBloqueos
@onready var bloqueo_1: ColorRect = $PanelBloqueos/VBoxContainer/BarraBloqueos/Bloqueo1
@onready var bloqueo_2: ColorRect = $PanelBloqueos/VBoxContainer/BarraBloqueos/Bloqueo2
@onready var bloqueo_3: ColorRect = $PanelBloqueos/VBoxContainer/BarraBloqueos/Bloqueo3

var golpes_bloqueados: int = 0
var golpes_necesarios: int = 3
var entrenamiento_iniciado: bool = false
var entrenamiento_terminado: bool = false

var color_vacio: Color = Color("4A342D")
var color_lleno: Color = Color("D6AD5C")


func _ready() -> void:
	# El contador NO aparece al comenzar el tutorial.
	visible = false
	actualizar_contador()
	actualizar_barras()

	var arashi: Node = get_tree().get_first_node_in_group("player")
	if arashi == null:
		push_warning("No se encontro a Arashi en el grupo player.")
		return

	if arashi.has_signal("golpe_bloqueado"):
		arashi.golpe_bloqueado.connect(_registrar_bloqueo)
	else:
		push_warning("Arashi no tiene la senal golpe_bloqueado.")


# La zona del dialogo llamara esta funcion cuando el padre termine de hablar.
func empezar_entrenamiento() -> void:
	if entrenamiento_iniciado or entrenamiento_terminado:
		return

	entrenamiento_iniciado = true
	golpes_bloqueados = 0
	actualizar_contador()
	actualizar_barras()
	panel_bloqueos.modulate.a = 0.0
	visible = true

	var tween: Tween = create_tween()
	tween.tween_property(panel_bloqueos, "modulate:a", 1.0, 0.3)


func _registrar_bloqueo(_posicion_atacante: Vector2) -> void:
	# No cuenta bloqueos antes de la explicacion del padre.
	if not entrenamiento_iniciado or entrenamiento_terminado:
		return

	golpes_bloqueados = mini(golpes_bloqueados + 1, golpes_necesarios)
	actualizar_contador()
	actualizar_barras()
	print("GOLPES BLOQUEADOS: ", golpes_bloqueados)

	if golpes_bloqueados >= golpes_necesarios:
		entrenamiento_terminado = true
		entrenamiento_completado.emit()
		terminar_entrenamiento()


func actualizar_contador() -> void:
	texto_bloqueos.text = "GOLPES BLOQUEADOS: %d/%d" % [
		golpes_bloqueados,
		golpes_necesarios
	]


func actualizar_barras() -> void:
	bloqueo_1.color = color_lleno if golpes_bloqueados >= 1 else color_vacio
	bloqueo_2.color = color_lleno if golpes_bloqueados >= 2 else color_vacio
	bloqueo_3.color = color_lleno if golpes_bloqueados >= 3 else color_vacio


func terminar_entrenamiento() -> void:
	# Dar tiempo para que se reproduzca el ultimo block_recoil (4 frames a 8 FPS).
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree():
		return

	if is_instance_valid(samurai_entrenamiento):
		if samurai_entrenamiento.has_method("desvanecer_entrenamiento"):
			samurai_entrenamiento.call("desvanecer_entrenamiento")
		else:
			push_warning("El samurai no tiene la funcion desvanecer_entrenamiento().")
	else:
		push_warning("Asigna Samurai Entrenamiento en el Inspector de IndicadorBloqueos.")

	# Permitir ver el 3/3 y el desvanecimiento antes de ocultar el panel.
	await get_tree().create_timer(0.8).timeout
	if not is_inside_tree():
		return

	var tween: Tween = create_tween()
	tween.tween_property(panel_bloqueos, "modulate:a", 0.0, 0.35)
	await tween.finished
	if is_inside_tree():
		visible = false
