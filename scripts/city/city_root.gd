
extends Node3D

@export var preview_only: bool = false


func _enter_tree() -> void:
	if not preview_only:
		return

	# En la toma aérea sólo necesitamos el escenario.
	# Quitamos al personaje antes de inicializar sus scripts.
	for nombre in ["Jugador", "WakeUpController"]:
		var nodo := get_node_or_null(nombre)

		if nodo != null:
			remove_child(nodo)
			nodo.free()

	# La ciudad aérea no requiere colisiones.
	var generador := get_node_or_null("CityJsonGenerator")

	if generador != null:
		generador.set("generar_colisiones", false)
