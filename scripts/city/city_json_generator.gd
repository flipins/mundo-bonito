
@tool
extends Node3D

# Mundo Bonito — generador de blockout desde Watabou.
# JSON esperado: FeatureCollection con features por ID.

@export_file("*.json") var json_path: String = "res://json.json"

@export_range(0.1, 2.0, 0.05) var escala: float = 0.5
@export var generar_colisiones: bool = true

# Zona donde colocaremos la habitación del protagonista.
# Coordenadas horizontales del mundo Godot: (X, Z).
@export var centro_habitacion_xz: Vector2 = Vector2.ZERO
@export var radio_libre_habitacion: float = 12.0

@export_tool_button("Construir ciudad desde JSON")
var boton_generar = generar_ciudad

const CAPAS := [
	"Buildings", "Castle", "Walls", "Docks", "Environment"
]


func _ready() -> void:
	# En el editor se construye usando el botón.
	# Durante el juego se construye al cargar la escena.
	if not Engine.is_editor_hint():
		generar_ciudad()


func generar_ciudad() -> void:
	if not is_node_ready():
		return

	var archivo := FileAccess.open(json_path, FileAccess.READ)

	if archivo == null:
		push_error("Ciudad: no se encuentra " + json_path)
		return

	var parsed: Variant = JSON.parse_string(archivo.get_as_text())

	if not (parsed is Dictionary):
		push_error("Ciudad: JSON inválido.")
		return

	var datos: Dictionary = parsed
	var features: Dictionary = {}

	for elemento in datos.get("features", []):
		if elemento is Dictionary:
			features[str(elemento.get("id", ""))] = elemento

	for nombre in CAPAS:
		var carpeta := _capa(nombre)

		if carpeta == null:
			push_error("Ciudad: falta GeneratedCity/" + nombre)
			return

		for hijo in carpeta.get_children():
			carpeta.remove_child(hijo)
			hijo.free()

	_crear_suelo(features.get("earth", {}))
	_crear_agua(features.get("water", {}))
	_crear_caminos(features.get("roads", {}))
	_crear_campos(features.get("fields", {}))
	_crear_edificios(features.get("buildings", {}))
	_crear_murallas(features.get("walls", {}))
	_crear_castillo(features.get("districts", {}))
	_crear_muelles(features.get("planks", {}))

	print("Ciudad: generación terminada.")


func _capa(nombre: String) -> Node3D:
	return get_node_or_null(
		"GeneratedCity/" + nombre
	) as Node3D


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


# Convierte las coordenadas del JSON en un polígono 2D.
func _leer_anillo(raw: Variant) -> PackedVector2Array:
	var puntos := PackedVector2Array()

	if not (raw is Array):
		return puntos

	for par in raw:
		if not (par is Array) or par.size() < 2:
			continue

		var punto := Vector2(
			float(par[0]) * escala,
			float(par[1]) * escala
		)

		if puntos.is_empty():
			puntos.append(punto)
		elif puntos[puntos.size() - 1].distance_to(punto) > 0.001:
			puntos.append(punto)

	# Watabou puede repetir el primer punto al cerrar el anillo.
	if puntos.size() >= 2:
		if puntos[0].distance_to(puntos[puntos.size() - 1]) < 0.001:
			puntos.remove_at(puntos.size() - 1)

	return puntos


# +Y del mapa equivale al norte (-Z) en Godot.
func _p3(p: Vector2, altura: float) -> Vector3:
	return Vector3(p.x, altura, -p.y)


func _triangulo(
	st: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3
) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func _triangulo_arriba(
	st: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3
) -> void:
	if (b - a).cross(c - a).y < 0.0:
		_triangulo(st, a, c, b)
	else:
		_triangulo(st, a, b, c)


func _triangulo_afuera(
	st: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	centro: Vector3
) -> void:
	var exterior := (a + b + c) / 3.0 - centro
	exterior.y = 0.0

	if (b - a).cross(c - a).dot(exterior) < 0.0:
		_triangulo(st, a, c, b)
	else:
		_triangulo(st, a, b, c)


# Superficie plana: terreno, campos y agua.
func _malla_plana(
	poligono: PackedVector2Array,
	altura: float
) -> ArrayMesh:
	if poligono.size() < 3:
		return null

	var indices := Geometry2D.triangulate_polygon(poligono)

	if indices.is_empty():
		return null

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(0, indices.size(), 3):
		_triangulo_arriba(
			st,
			_p3(poligono[indices[i]], altura),
			_p3(poligono[indices[i + 1]], altura),
			_p3(poligono[indices[i + 2]], altura)
		)

	st.generate_normals()
	return st.commit()


# Extrusión: techo + paredes verticales.
func _malla_solida(
	poligono: PackedVector2Array,
	base: float,
	altura: float
) -> ArrayMesh:
	if poligono.size() < 3:
		return null

	var indices := Geometry2D.triangulate_polygon(poligono)

	if indices.is_empty():
		return null

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var techo := base + altura

	# Techo.
	for i in range(0, indices.size(), 3):
		_triangulo_arriba(
			st,
			_p3(poligono[indices[i]], techo),
			_p3(poligono[indices[i + 1]], techo),
			_p3(poligono[indices[i + 2]], techo)
		)

	# Centro aproximado del volumen.
	var centro := Vector3.ZERO

	for punto in poligono:
		centro += _p3(punto, base + altura * 0.5)

	centro /= float(poligono.size())

	# Paredes exteriores.
	for i in range(poligono.size()):
		var siguiente := (i + 1) % poligono.size()

		var a := _p3(poligono[i], base)
		var b := _p3(poligono[siguiente], base)
		var c := _p3(poligono[siguiente], techo)
		var d := _p3(poligono[i], techo)

		_triangulo_afuera(st, a, b, c, centro)
		_triangulo_afuera(st, a, c, d, centro)

	st.generate_normals()
	return st.commit()


func _agregar_malla(
	carpeta: String,
	nombre: String,
	malla: ArrayMesh,
	color: Color,
	colision: bool = false
) -> MeshInstance3D:
	if malla == null:
		return null

	var instancia := MeshInstance3D.new()
	instancia.name = nombre
	instancia.mesh = malla
	instancia.material_override = _material(color)

	_capa(carpeta).add_child(instancia)

	# Las colisiones se generan en tiempo de ejecución.
	# create_trimesh_collision crea StaticBody3D + CollisionShape3D.
	if colision and generar_colisiones and not Engine.is_editor_hint():
		instancia.create_trimesh_collision()

	return instancia


func _crear_suelo(feature: Dictionary) -> void:
	var anillos: Array = feature.get("coordinates", [])

	if anillos.is_empty():
		return

	var poligono := _leer_anillo(anillos[0])

	_agregar_malla(
		"Environment",
		"DesertGround",
		_malla_plana(poligono, -0.2),
		Color(0.66, 0.51, 0.34),
		true
	)


func _crear_agua(feature: Dictionary) -> void:
	var poligonos: Array = feature.get("coordinates", [])

	var indice := 0

	for raw in poligonos:
		if not (raw is Array) or raw.is_empty():
			continue

		var poligono := _leer_anillo(raw[0])

		_agregar_malla(
			"Environment",
			"Sea_%03d" % indice,
			_malla_plana(poligono, -0.12),
			Color(0.09, 0.32, 0.48)
		)

		indice += 1


# Crea una franja plana siguiendo una línea del JSON.
func _malla_camino(
	puntos: PackedVector2Array,
	ancho: float,
	altura: float
) -> ArrayMesh:
	if puntos.size() < 2:
		return null

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var segmentos := 0

	for i in range(puntos.size() - 1):
		var a: Vector2 = puntos[i]
		var b: Vector2 = puntos[i + 1]
		var direccion := b - a

		if direccion.length() < 0.001:
			continue

		var lateral := Vector2(
			-direccion.y, direccion.x
		).normalized() * ancho * 0.5

		var v1 := _p3(a + lateral, altura)
		var v2 := _p3(a - lateral, altura)
		var v3 := _p3(b - lateral, altura)
		var v4 := _p3(b + lateral, altura)

		_triangulo_arriba(st, v1, v2, v3)
		_triangulo_arriba(st, v1, v3, v4)

		segmentos += 1

	if segmentos == 0:
		return null

	st.generate_normals()
	return st.commit()


func _crear_caminos(feature: Dictionary) -> void:
	var geometries: Array = feature.get("geometries", [])

	var indice := 0

	for g in geometries:
		if g.get("type", "") != "LineString":
			continue

		var puntos := _leer_anillo(g.get("coordinates", []))
		var ancho := float(g.get("width", 8.0)) * escala

		_agregar_malla(
			"Environment",
			"Road_%03d" % indice,
			_malla_camino(puntos, ancho, -0.16),
			Color(0.42, 0.33, 0.24)
		)

		indice += 1


func _crear_campos(feature: Dictionary) -> void:
	var poligonos: Array = feature.get("coordinates", [])

	var indice := 0

	for raw in poligonos:
		if not (raw is Array) or raw.is_empty():
			continue

		var poligono := _leer_anillo(raw[0])

		_agregar_malla(
			"Environment",
			"Field_%03d" % indice,
			_malla_plana(poligono, -0.15),
			Color(0.39, 0.37, 0.20)
		)

		indice += 1


func _interfiere_habitacion(
	poligono: PackedVector2Array
) -> bool:
	# El polígono viene en X / norte.
	# Convertimos cada punto a X / Z del mundo.
	var mundo := PackedVector2Array()

	for p in poligono:
		mundo.append(Vector2(p.x, -p.y))

	if Geometry2D.is_point_in_polygon(
		centro_habitacion_xz, mundo
	):
		return true

	for p in mundo:
		if p.distance_to(centro_habitacion_xz) < radio_libre_habitacion:
			return true

	return false


func _crear_edificios(feature: Dictionary) -> void:
	var poligonos: Array = feature.get("coordinates", [])

	var indice := 0
	var construidos := 0

	for raw in poligonos:
		if not (raw is Array) or raw.is_empty():
			indice += 1
			continue

		var poligono := _leer_anillo(raw[0])

		# Alturas provisionales variadas.
		var altura := 6.0 + float(indice % 5) * 2.0

		var despejar := _interfiere_habitacion(poligono)

		var instancia := _agregar_malla(
			"Buildings",
			"Building_%03d" % indice,
			_malla_solida(poligono, -0.18, altura),
			Color(
				0.64 + float(indice % 3) * 0.055,
				0.55,
				0.41
			),
			not despejar
		)

		if instancia != null:
			construidos += 1

			# Conservamos el bloque para futura sustitución,
			# pero ocultamos los que invaden la habitación.
			if despejar:
				instancia.visible = false

		indice += 1

	print("Ciudad: edificios construidos: ", construidos)


func _crear_murallas(feature: Dictionary) -> void:
	var geometries: Array = feature.get("geometries", [])

	var indice := 0

	for g in geometries:
		if g.get("type", "") != "Polygon":
			continue

		var anillos: Array = g.get("coordinates", [])

		if anillos.is_empty():
			continue

		var poligono := _leer_anillo(anillos[0])

		_agregar_malla(
			"Walls",
			"Wall_%03d" % indice,
			_malla_solida(poligono, -0.18, 11.0),
			Color(0.49, 0.43, 0.35),
			true
		)

		indice += 1


func _crear_castillo(feature: Dictionary) -> void:
	var geometries: Array = feature.get("geometries", [])

	for g in geometries:
		if str(g.get("name", "")).to_lower() != "castle":
			continue

		var anillos: Array = g.get("coordinates", [])

		if anillos.is_empty():
			continue

		var poligono := _leer_anillo(anillos[0])

		_agregar_malla(
			"Castle",
			"CastleMainBlock",
			_malla_solida(poligono, -0.18, 25.0),
			Color(0.36, 0.34, 0.32),
			true
		)


func _crear_muelles(feature: Dictionary) -> void:
	var geometries: Array = feature.get("geometries", [])

	var indice := 0

	for g in geometries:
		if g.get("type", "") != "LineString":
			continue

		var puntos := _leer_anillo(g.get("coordinates", []))
		var ancho := float(g.get("width", 3.0)) * escala

		_agregar_malla(
			"Docks",
			"Dock_%03d" % indice,
			_malla_camino(puntos, ancho, 0.08),
			Color(0.34, 0.22, 0.13)
		)

		indice += 1
