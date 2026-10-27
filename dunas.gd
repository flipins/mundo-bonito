@tool
extends StaticBody3D
## Terreno de dunas generado con ruido, con colisión incluida.
## Se ve también en el editor, así puedes colocar objetos sobre él.
## Al cambiar cualquier valor del Inspector el terreno se regenera solo.
## El centro (donde aparece el jugador) es una zona plana a altura y = 0.

@export_group("Tamaño")
## Lado del terreno cuadrado, en metros.
@export_range(50.0, 1000.0, 10.0) var tamano: float = 400.0:
	set(valor):
		tamano = valor
		_regenerar_pronto()
## Celdas por lado. Más celdas = dunas más suaves, pero más pesado.
@export_range(20, 400, 10) var celdas: int = 200:
	set(valor):
		celdas = valor
		_regenerar_pronto()

@export_group("Dunas")
## Altura máxima de las dunas, en metros.
@export_range(0.5, 40.0, 0.5) var amplitud: float = 7.0:
	set(valor):
		amplitud = valor
		_regenerar_pronto()
## Distancia aproximada entre una duna y la siguiente, en metros.
@export_range(10.0, 400.0, 5.0) var escala_dunas: float = 90.0:
	set(valor):
		escala_dunas = valor
		_regenerar_pronto()
## Qué tan alargadas son las dunas en la dirección del viento (1 = redondas).
@export_range(1.0, 6.0, 0.1) var estiramiento: float = 2.0:
	set(valor):
		estiramiento = valor
		_regenerar_pronto()
## Dirección del viento en grados. Las dunas se alargan en esa dirección.
@export_range(0.0, 360.0, 1.0) var direccion_viento: float = 25.0:
	set(valor):
		direccion_viento = valor
		_regenerar_pronto()
## Altura de las ondulaciones pequeñas de la arena, en metros.
@export_range(0.0, 1.0, 0.01) var rugosidad: float = 0.12:
	set(valor):
		rugosidad = valor
		_regenerar_pronto()
## Cambia este número para obtener un desierto distinto.
@export var semilla: int = 1:
	set(valor):
		semilla = valor
		_regenerar_pronto()

@export_group("Zona de inicio")
## Radio de la zona plana del centro, donde aparece el jugador.
@export_range(0.0, 100.0, 1.0) var radio_plano: float = 12.0:
	set(valor):
		radio_plano = valor
		_regenerar_pronto()
## Distancia en la que el terreno pasa de plano a dunas.
@export_range(1.0, 200.0, 1.0) var transicion: float = 40.0:
	set(valor):
		transicion = valor
		_regenerar_pronto()

@export_group("Aspecto")
## Material del terreno. Si lo dejas vacío se usa un color de arena.
@export var material_arena: Material:
	set(valor):
		material_arena = valor
		_regenerar_pronto()

var _ruido: FastNoiseLite
var _malla_nodo: MeshInstance3D
var _colision_nodo: CollisionShape3D
var _pendiente: bool = false


func _ready() -> void:
	_generar()


func _regenerar_pronto() -> void:
	# Al abrir la escena los valores se aplican antes de que el nodo esté listo;
	# en ese caso _ready() ya se encarga de generar.
	if not is_node_ready() or _pendiente:
		return
	_pendiente = true
	_generar.call_deferred()


func _generar() -> void:
	_pendiente = false
	_asegurar_nodos()
	_configurar_ruido()

	var n: int = celdas + 1
	var paso: float = tamano / float(celdas)
	var origen: float = -tamano * 0.5

	# 1) Altura de cada vértice de la cuadrícula.
	var alturas := PackedFloat32Array()
	alturas.resize(n * n)
	for i in range(n):
		for j in range(n):
			var x: float = origen + float(j) * paso
			var z: float = origen + float(i) * paso
			alturas[i * n + j] = _altura(x, z)

	# 2) Vértices, normales y coordenadas de textura.
	var vertices := PackedVector3Array()
	var normales := PackedVector3Array()
	var uvs := PackedVector2Array()
	vertices.resize(n * n)
	normales.resize(n * n)
	uvs.resize(n * n)
	for i in range(n):
		var i0: int = maxi(i - 1, 0)
		var i1: int = mini(i + 1, n - 1)
		for j in range(n):
			var j0: int = maxi(j - 1, 0)
			var j1: int = mini(j + 1, n - 1)
			var idx: int = i * n + j
			var x: float = origen + float(j) * paso
			var z: float = origen + float(i) * paso
			vertices[idx] = Vector3(x, alturas[idx], z)
			var dhdx: float = (alturas[i * n + j1] - alturas[i * n + j0]) / (float(j1 - j0) * paso)
			var dhdz: float = (alturas[i1 * n + j] - alturas[i0 * n + j]) / (float(i1 - i0) * paso)
			normales[idx] = Vector3(-dhdx, 1.0, -dhdz).normalized()
			uvs[idx] = Vector2(x, z) / 10.0

	# 3) Triángulos. Godot considera "frente" el sentido de las agujas del reloj.
	var indices := PackedInt32Array()
	indices.resize(celdas * celdas * 6)
	var k: int = 0
	for i in range(celdas):
		for j in range(celdas):
			var a: int = i * n + j
			var b: int = a + 1
			var c: int = a + n
			var d: int = c + 1
			indices[k] = a
			indices[k + 1] = b
			indices[k + 2] = d
			indices[k + 3] = a
			indices[k + 4] = d
			indices[k + 5] = c
			k += 6

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normales
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	malla.surface_set_material(0, _obtener_material())
	_malla_nodo.mesh = malla

	# La colisión solo hace falta al jugar; en el editor se omite para que sea más ligero.
	if not Engine.is_editor_hint():
		var forma: ConcavePolygonShape3D = malla.create_trimesh_shape()
		forma.backface_collision = true
		_colision_nodo.shape = forma


func _altura(x: float, z: float) -> float:
	# Se gira el plano para alargar las dunas en la dirección del viento.
	var ang: float = deg_to_rad(direccion_viento)
	var u: float = x * cos(ang) + z * sin(ang)
	var v: float = -x * sin(ang) + z * cos(ang)

	# Las crestas aparecen donde el ruido cruza por cero: líneas largas y marcadas.
	var ruido_base: float = _ruido.get_noise_2d(u / (escala_dunas * estiramiento), v / escala_dunas)
	var cresta: float = pow(1.0 - absf(ruido_base), 1.5)

	# Ondulaciones pequeñas de la superficie.
	var ondas: float = _ruido.get_noise_2d(u / 6.0 + 100.0, v / 2.5 - 100.0) * rugosidad

	# Zona plana en el centro.
	var plano: float = smoothstep(radio_plano, radio_plano + transicion, Vector2(x, z).length())

	return (cresta * amplitud + ondas) * plano


func _configurar_ruido() -> void:
	_ruido = FastNoiseLite.new()
	_ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ruido.fractal_type = FastNoiseLite.FRACTAL_NONE
	_ruido.frequency = 1.0
	_ruido.seed = semilla


func _asegurar_nodos() -> void:
	# Los nodos generados no se guardan en la escena; se vuelven a crear al abrirla.
	_malla_nodo = get_node_or_null("MallaGenerada") as MeshInstance3D
	if _malla_nodo == null:
		_malla_nodo = MeshInstance3D.new()
		_malla_nodo.name = "MallaGenerada"
		add_child(_malla_nodo)
	_colision_nodo = get_node_or_null("ColisionGenerada") as CollisionShape3D
	if _colision_nodo == null:
		_colision_nodo = CollisionShape3D.new()
		_colision_nodo.name = "ColisionGenerada"
		add_child(_colision_nodo)


func _obtener_material() -> Material:
	if material_arena != null:
		return material_arena
	var arena := StandardMaterial3D.new()
	arena.albedo_color = Color(0.85, 0.7, 0.47)
	arena.roughness = 1.0
	return arena
