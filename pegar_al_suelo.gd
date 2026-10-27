extends Node
## Componente: al empezar el juego baja a su nodo padre hasta apoyarlo sobre el terreno.
## Se agrega como hijo de cualquier Node3D (una caja, una nota, un campamento...).
## Solo actúa al jugar: en el editor el objeto queda donde lo pusiste.

## Qué tan arriba del suelo queda el origen del objeto, en metros.
@export var separacion: float = 0.0

## Desde qué altura sobre el objeto se empieza a buscar el suelo, en metros.
@export var altura_busqueda: float = 100.0


func _ready() -> void:
	var objeto := get_parent() as Node3D
	if objeto == null:
		push_warning("PegarAlSuelo: el nodo padre debe ser un Node3D.")
		return

	# El terreno crea su colisión al iniciar; se espera a que la física esté lista.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_instance_valid(objeto):
		return

	# El rayo debe ignorar las colisiones del propio objeto.
	var excluir: Array[RID] = []
	if objeto is CollisionObject3D:
		excluir.append((objeto as CollisionObject3D).get_rid())
	for hijo in objeto.find_children("*", "CollisionObject3D", true, false):
		excluir.append((hijo as CollisionObject3D).get_rid())

	var origen: Vector3 = objeto.global_position + Vector3.UP * altura_busqueda
	var destino: Vector3 = objeto.global_position + Vector3.DOWN * altura_busqueda
	var consulta := PhysicsRayQueryParameters3D.create(origen, destino)
	consulta.exclude = excluir

	var resultado: Dictionary = objeto.get_world_3d().direct_space_state.intersect_ray(consulta)
	if resultado.is_empty():
		push_warning("PegarAlSuelo: no se encontró terreno debajo de '%s'." % objeto.name)
		return

	var punto: Vector3 = resultado["position"]
	objeto.global_position.y = punto.y + separacion
