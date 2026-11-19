extends Node
## Agrega este script a un nodo Node de la escena jugable.
## No necesita Autoload ni modificar project.godot.
const ENEMIGO = preload("res://scripts/enemigos/enemigo_arena.gd")

@export var cantidad_enemigos: int = 4
@export var dano_espada: int = 35
@export var alcance_espada: float = 3.0

var _terreno: Node3D
var _jugador: CharacterBody3D
var _centro: Vector3
var _radio: float = 18.0
var _activado: bool = false
var _espera_golpe: float = 0.0
var _revision: float = 0.0

func _ready() -> void:
	Inventario.objeto_agregado.connect(_al_recoger)

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_espera_golpe = maxf(0.0, _espera_golpe - delta)
	_revision -= delta
	if _revision > 0.0:
		return
	_revision = 0.4
	if not is_instance_valid(_terreno):
		var t := get_tree().get_first_node_in_group("terreno_dunas")
		if t is Node3D:
			_terreno = t
	if not is_instance_valid(_jugador):
		_jugador = _buscar_jugador(get_tree().current_scene)
	if not _activado and _terreno != null and _jugador != null and _tiene_espada():
		_activar()

func _buscar_jugador(nodo: Node) -> CharacterBody3D:
	if nodo == null:
		return null
	if nodo is CharacterBody3D and nodo.has_node("Camera3D"):
		return nodo
	for hijo in nodo.get_children():
		var resultado := _buscar_jugador(hijo)
		if resultado != null:
			return resultado
	return null

func _tiene_espada() -> bool:
	if Inventario.tiene(&"espada") or Inventario.tiene(&"rama_espada"):
		return true
	if is_instance_valid(_jugador):
		var modelo := _jugador.get_node_or_null("UAL1_Standard")
		if modelo != null:
			return modelo.get("con_espada") == true
	return false

func _al_recoger(_id: StringName) -> void:
	_revision = 0.0

func _activar() -> void:
	if not bool(_terreno.get("usar_valle")) or not bool(_terreno.get("con_arena")):
		push_warning("ControlArena: activa Usar Valle y Con Arena en Dunas.")
		return
	_activado = true
	var avance: float = float(_terreno.get("distancia_arena"))
	var x: float = float(_terreno.call("centro_valle", avance))
	_centro = _terreno.to_global(Vector3(x, 0.0, -avance))
	_radio = maxf(5.0, float(_terreno.get("radio_arena")) - 2.0)
	for i in range(cantidad_enemigos):
		var angulo := TAU * float(i) / float(maxi(1, cantidad_enemigos))
		var offset := Vector3(cos(angulo), 0.0, sin(angulo)) * minf(_radio * 0.6, 10.0)
		var enemigo := ENEMIGO.new()
		enemigo.jugador = _jugador
		enemigo.centro_arena = _centro
		enemigo.radio_arena = _radio
		get_parent().add_child(enemigo)
		var origen := _centro + offset + Vector3.UP * 30.0
		var consulta := PhysicsRayQueryParameters3D.create(origen, origen + Vector3.DOWN * 100.0)
		consulta.collision_mask = 1
		var impacto := get_viewport().get_world_3d().direct_space_state.intersect_ray(consulta)
		enemigo.global_position = impacto["position"] + Vector3.UP * 0.15 if not impacto.is_empty() else _centro + offset + Vector3.UP * 2.0
	print("ControlArena: aparecieron ", cantidad_enemigos, " enemigos.")

func _input(event: InputEvent) -> void:
	if not _activado or get_tree().paused:
		return

	if _espera_golpe > 0.0 or not _tiene_espada():
		return

	if not (event is InputEventMouseButton):
		return

	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return

	if not is_instance_valid(_jugador):
		return

	_espera_golpe = 0.55

	for enemigo in get_tree().get_nodes_in_group("enemigos_arena"):
		if not is_instance_valid(enemigo):
			continue

		var distancia := _jugador.global_position.distance_to(
			enemigo.global_position
		)

		if distancia <= 3.5:
			enemigo.recibir_dano(dano_espada)
			print("¡Enemigo golpeado! Daño: ", dano_espada)
