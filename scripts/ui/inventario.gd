extends Node
## Inventario mínimo (se registra como Autoload con el nombre "Inventario").
## Guarda qué objetos tiene el jugador. Todavía no tiene pantalla: por ahora es
## la lista y las señales para que el resto del juego pueda reaccionar.
##
## Uso desde cualquier script:
##   Inventario.agregar(&"rama_espada", "Rama afilada")
##   if Inventario.tiene(&"rama_espada"): ...
##   Inventario.objeto_agregado.connect(mi_funcion)

signal objeto_agregado(id: StringName)
signal objeto_quitado(id: StringName)

# Cada objeto se guarda así:  id -> {"nombre": String, "cantidad": int}
var _objetos: Dictionary = {}


func agregar(id: StringName, nombre: String, cantidad: int = 1) -> void:
	if _objetos.has(id):
		_objetos[id]["cantidad"] += cantidad
	else:
		_objetos[id] = {"nombre": nombre, "cantidad": cantidad}
	objeto_agregado.emit(id)


## Devuelve false si no hay suficientes unidades.
func quitar(id: StringName, cantidad: int = 1) -> bool:
	if not _objetos.has(id) or _objetos[id]["cantidad"] < cantidad:
		return false
	_objetos[id]["cantidad"] -= cantidad
	if _objetos[id]["cantidad"] <= 0:
		_objetos.erase(id)
	objeto_quitado.emit(id)
	return true


func tiene(id: StringName) -> bool:
	return _objetos.has(id)


func cantidad_de(id: StringName) -> int:
	if _objetos.has(id):
		return _objetos[id]["cantidad"]
	return 0


## Copia de todo el contenido (útil más adelante para guardar la partida).
func todos() -> Dictionary:
	return _objetos.duplicate(true)


func vaciar() -> void:
	_objetos.clear()
