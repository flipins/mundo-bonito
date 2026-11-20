
extends Node3D

# Placeholder de caballo y jinete para la cinemática.

@export var modelo_caballo: PackedScene
@export var lleva_protagonista: bool = false
@export var color_jinete: Color = Color(0.18, 0.17, 0.16)


func _ready() -> void:
	_construir_caballo()
	_construir_jinete()

	if lleva_protagonista:
		_construir_protagonista()


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material


func _caja(
	nombre: String,
	posicion: Vector3,
	tamano: Vector3,
	color: Color
) -> MeshInstance3D:
	var nodo := MeshInstance3D.new()
	nodo.name = nombre

	var malla := BoxMesh.new()
	malla.size = tamano

	nodo.mesh = malla
	nodo.position = posicion
	nodo.material_override = _material(color)

	add_child(nodo)
	return nodo


func _construir_caballo() -> void:
	if modelo_caballo != null:
		add_child(modelo_caballo.instantiate())
		return

	var marron := Color(0.28, 0.17, 0.10)

	_caja(
		"HorseBody",
		Vector3(0, 1.2, 0),
		Vector3(1.15, 1.1, 2.3),
		marron
	)

	_caja(
		"HorseNeck",
		Vector3(0, 1.85, -0.95),
		Vector3(0.55, 1.25, 0.65),
		marron
	)

	_caja(
		"HorseHead",
		Vector3(0, 2.35, -1.35),
		Vector3(0.6, 0.55, 0.9),
		marron
	)

	for x in [-0.4, 0.4]:
		for z in [-0.75, 0.75]:
			_caja(
				"HorseLeg",
				Vector3(x, 0.4, z),
				Vector3(0.24, 0.8, 0.24),
				marron
			)


func _construir_jinete() -> void:
	var cuerpo := MeshInstance3D.new()
	cuerpo.name = "MysteriousRider"

	var capsula := CapsuleMesh.new()
	capsula.radius = 0.34
	capsula.height = 1.3

	cuerpo.mesh = capsula
	cuerpo.position = Vector3(0, 2.35, -0.1)
	cuerpo.material_override = _material(color_jinete)

	add_child(cuerpo)

	var cabeza := MeshInstance3D.new()
	cabeza.name = "RiderHead"

	var esfera := SphereMesh.new()
	esfera.radius = 0.26
	esfera.height = 0.52

	cabeza.mesh = esfera
	cabeza.position = Vector3(0, 3.1, -0.1)
	cabeza.material_override = _material(color_jinete)

	add_child(cabeza)


func _construir_protagonista() -> void:
	# Cuerpo tendido sobre la parte trasera del caballo.
	var cuerpo := MeshInstance3D.new()
	cuerpo.name = "UnconsciousHero"

	var capsula := CapsuleMesh.new()
	capsula.radius = 0.30
	capsula.height = 1.5

	cuerpo.mesh = capsula
	cuerpo.position = Vector3(0, 1.95, 0.7)
	cuerpo.rotation_degrees = Vector3(90, 0, 0)
	cuerpo.material_override = _material(
		Color(0.38, 0.35, 0.30)
	)

	add_child(cuerpo)
