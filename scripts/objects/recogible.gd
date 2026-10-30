extends Interactuable
## Objeto que el jugador puede recoger: pasa al inventario y desaparece del mundo.
## El texto que aparece al recogerlo es el campo "Mensaje" (por ejemplo "Recogiste: Rama afilada").

## Identificador interno del objeto, sin espacios (por ejemplo "rama_espada").
@export var id_objeto: StringName = &"objeto"

## Nombre que verá el jugador.
@export var nombre_objeto: String = "Objeto"

## Cuántas unidades se suman al recogerlo.
@export var cantidad: int = 1


func interactuar(quien: Node) -> void:
	super.interactuar(quien)
	Inventario.agregar(id_objeto, nombre_objeto, cantidad)
	queue_free()
