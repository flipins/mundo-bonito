extends Interactuable
## Objeto que el jugador puede recoger: pasa al inventario y desaparece del mundo.
## El texto que aparece al recogerlo es el campo "Mensaje" (por ejemplo "Recogiste: Rama afilada").

## Identificador interno del objeto, sin espacios (por ejemplo "rama_espada").
@export var id_objeto: StringName = &"objeto"

## Nombre que verá el jugador.
@export var nombre_objeto: String = "Objeto"

## Cuántas unidades se suman al recogerlo.
@export var cantidad: int = 1
## Si está activado, el modelo se queda en la mano del jugador al recogerlo.
@export var equipar_en_mano: bool = true
## El nodo del modelo 3D de la espada (un hijo de este objeto). Arrástralo desde el árbol de escena.
@export var nodo_visual: Node3D
func interactuar(quien: Node) -> void:
	super.interactuar(quien)
	Inventario.agregar(id_objeto, nombre_objeto, cantidad)
	if equipar_en_mano and quien != null and nodo_visual != null:
		var maniqui := quien.find_child("UAL1_Standard", true, false)
		if maniqui != null and maniqui.has_method("equipar_en_mano"):
			maniqui.equipar_en_mano(nodo_visual)
	queue_free()
 	# Si el modelo no pudo pasar a la mano, se elimina con el objeto (comportamiento normal).
