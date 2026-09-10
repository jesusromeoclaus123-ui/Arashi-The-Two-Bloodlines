extends Control


func _ready() -> void:
	$RayoJugar.hide()
	$RayoSalir.hide()
	
	$Jugar.mouse_filter = Control.MOUSE_FILTER_STOP
	$Jugar.set_size(Vector2(409, 103))
	
	$Salir.modulate.a = 1.0


func _on_jugar_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Tutorial.tscn")


func _on_salir_pressed() -> void:
	get_tree().quit()


func _on_jugar_mouse_entered() -> void:
	$RayoJugar.show()


func _on_jugar_mouse_exited() -> void:
	$RayoJugar.hide()


func _on_salir_mouse_entered() -> void:
	$Salir.modulate.a = 0.0
	$RayoSalir.show()


func _on_salir_mouse_exited() -> void:
	$RayoSalir.hide()
	$Salir.modulate.a = 1.0
