extends CharacterBody3D
## Enemigo de prueba, sin modelos externos.

signal derrotado

@export var vida_maxima: int = 100
@export var velocidad: float = 3.0
@export var dano: int = 85
@export var alcance_ataque: float = 2.0
@export var espera_entre_ataques: float = 1.5

var jugador: CharacterBody3D
var centro_arena: Vector3
var radio_arena: float = 18.0
var vida: int = 100
var _espera: float = 0.0
var _material: StandardMaterial3D
var _destello: float = 0.0

func _ready() -> void:
	vida = vida_maxima
	add_to_group("enemigos_arena")
	collision_layer = 2
	collision_mask = 1
	var col := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.45
	capsula.height = 2.0
	col.shape = capsula
	col.position.y = 1.0
	add_child(col)
	var cuerpo := MeshInstance3D.new()
	var malla := CapsuleMesh.new()
	malla.radius = 0.45
	malla.height = 2.0
	cuerpo.mesh = malla
	cuerpo.position.y = 1.0
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.18, 0.13, 0.24)
	cuerpo.material_override = _material
	add_child(cuerpo)
	var ojo := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.12
	esfera.height = 0.24
	ojo.mesh = esfera
	ojo.position = Vector3(0.0, 1.55, -0.40)
	var rojo := StandardMaterial3D.new()
	rojo.albedo_color = Color.RED
	rojo.emission_enabled = true
	rojo.emission = Color(1.0, 0.06, 0.02)
	ojo.material_override = rojo
	add_child(ojo)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(jugador):
		return
	_espera = maxf(0.0, _espera - delta)
	_destello = maxf(0.0, _destello - delta)
	_material.albedo_color = Color(0.9, 0.2, 0.2) if _destello > 0.0 else Color(0.18, 0.13, 0.24)
	var posicion_jugador := jugador.global_position
	var hacia := Vector3(posicion_jugador.x - global_position.x, 0.0, posicion_jugador.z - global_position.z)
	var distancia := hacia.length()
	var dentro := Vector2(posicion_jugador.x - centro_arena.x, posicion_jugador.z - centro_arena.z).length() <= radio_arena
	var direccion := Vector3.ZERO
	if dentro and distancia > alcance_ataque * 0.85:
		direccion = hacia.normalized()
	elif not dentro:
		var regreso := Vector3(centro_arena.x - global_position.x, 0.0, centro_arena.z - global_position.z)
		if regreso.length() > 2.0:
			direccion = regreso.normalized()
	var siguiente := global_position + direccion * velocidad * delta
	if Vector2(siguiente.x - centro_arena.x, siguiente.z - centro_arena.z).length() > radio_arena:
		direccion = Vector3.ZERO
	velocity.x = direccion.x * velocidad
	velocity.z = direccion.z * velocidad
	velocity.y = -0.2 if is_on_floor() else velocity.y - 20.0 * delta
	if dentro and distancia > 0.1:
		look_at(Vector3(posicion_jugador.x, global_position.y, posicion_jugador.z), Vector3.UP)
	move_and_slide()
	if dentro and distancia <= alcance_ataque and _espera <= 0.0:
		_espera = espera_entre_ataques
		var barra := get_tree().get_first_node_in_group("barra_vida")
		if barra != null and barra.has_method("recibir_dano"):
			barra.recibir_dano(dano)

func recibir_dano(cantidad: int) -> void:
	if vida <= 0:
		return
	vida -= maxi(0, cantidad)
	_destello = 0.2
	if vida <= 0:
		derrotado.emit()
		queue_free()
