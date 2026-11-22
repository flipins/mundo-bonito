
@tool
extends Node3D

# ============================================================
# MUNDO BONITO - GENERADOR DE CIUDAD V3
# Godot 4.7
#
# Suelo continuo provisional para corregir zonas invisibles.
# Conserva las construcciones del JSON de Watabou.
# No requiere agregar nodos manualmente.
# ============================================================


@export_group("Configuracion general")

@export_file("*.json")
var json_path: String = "res://json.json"

@export_range(0.1, 2.0, 0.05)
var escala: float = 0.5

@export var generar_colisiones: bool = true


@export_group("Suelo continuo")

# Genera una base plana usando un PlaneMesh de Godot.
# Es independiente de la triangulacion del JSON.
@export var usar_suelo_continuo: bool = true

# La base queda debajo de caminos y del mar.
@export var altura_suelo: float = -0.19
# Amplia ligeramente el suelo alrededor del mapa.
@export_range(0.0, 100.0, 1.0)
var margen_suelo: float = 10.0
# Caja de colision para caminar sobre el suelo.
@export var colision_suelo_continuo: bool = true
@export_group("Materiales del entorno")
# Puedes asignar el ShaderMaterial del tutorial.
@export var material_arena: Material

@export var material_agua: Material
@export var material_camino: Material
@export var material_campo: Material

@export_range(0.01, 2.0, 0.01)
var escala_uv_suelo: float = 0.15


@export_group("Habitacion de recuperacion")

@export var centro_habitacion_xz: Vector2 = Vector2.ZERO

@export_range(1.0, 50.0, 0.5)
var radio_libre_habitacion: float = 12.0


@export_group("Generacion")

@export_tool_button("Construir ciudad desde JSON")
var boton_generar = generar_ciudad


const CAPAS := [
	"Buildings",
	"Castle",
	"Walls",
	"Docks",
    "Environment"
]


# ============================================================
# INICIO
# ============================================================

func _ready() -> void:
	if not Engine.is_editor_hint():
		generar_ciudad()


# ============================================================
# GENERADOR PRINCIPAL
# ============================================================

func generar_ciudad() -> void:
	if not is_node_ready():
		return

	if not FileAccess.file_exists(json_path):
		push_error("Ciudad: falta " + json_path)
		return

	var archivo := FileAccess.open(
		json_path,
		FileAccess.READ
	)

	if archivo == null:
		push_error("Ciudad: error abriendo JSON.")
		return

	var contenido: String = archivo.get_as_text()
	archivo.close()

	var parsed: Variant = JSON.parse_string(contenido)

	if not (parsed is Dictionary):
		push_error("Ciudad: JSON invalido.")
		return

	var datos: Dictionary = parsed
	var features: Dictionary = {}

	for elemento in datos.get("features", []):
		if elemento is Dictionary:
			var id: String = str(
				elemento.get("id", "")
			)
			features[id] = elemento

	# Verificar los contenedores antes de limpiarlos.
	for nombre in CAPAS:
		if _capa(nombre) == null:
			push_error(
				"Ciudad: falta GeneratedCity/" + nombre
			)
			return

	# Limpiar solamente objetos generados.
	for nombre in CAPAS:
		var carpeta: Node3D = _capa(nombre)

		for hijo in carpeta.get_children():
			carpeta.remove_child(hijo)
			hijo.free()

	print("Mundo Bonito: generando ciudad...")

	# Primero el suelo, despues las demas capas.
	_crear_suelo(features.get("earth", {}))
	_crear_agua(features.get("water", {}))
	_crear_caminos(features.get("roads", {}))
	_crear_campos(features.get("fields", {}))
	_crear_edificios(features.get("buildings", {}))
	_crear_murallas(features.get("walls", {}))
	_crear_castillo(features.get("districts", {}))
	_crear_muelles(features.get("planks", {}))

	print("Mundo Bonito: ciudad generada.")


# ============================================================
# CONTENEDORES
# ============================================================

func _capa(nombre: String) -> Node3D:
	return get_node_or_null(
		"GeneratedCity/" + nombre
	) as Node3D


# ============================================================
# MATERIALES
# ============================================================

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()

	mat.albedo_color = color
	mat.roughness = 0.95
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	return mat


func _material_del_suelo() -> Material:
	if material_arena != null:
		return material_arena

	return _material(Color(0.72, 0.60, 0.43))


# ============================================================
# COORDENADAS DE WATABOU
# ============================================================

func _leer_anillo(raw: Variant) -> PackedVector2Array:
	var puntos := PackedVector2Array()

	if not (raw is Array):
		return puntos

	for par in raw:
		if not (par is Array):
			continue

		if par.size() < 2:
			continue

		var punto := Vector2(
			float(par[0]) * escala,
			float(par[1]) * escala
		)

		if puntos.is_empty():
			puntos.append(punto)
		elif puntos[puntos.size() - 1].distance_to(
			punto
		) > 0.001:
			puntos.append(punto)

	if puntos.size() > 2:
		if puntos[0].distance_to(
			puntos[puntos.size() - 1]
		) < 0.001:
			puntos.remove_at(puntos.size() - 1)

	return puntos


func _p3(p: Vector2, altura: float) -> Vector3:
	return Vector3(p.x, altura, -p.y)


# ============================================================
# TRIANGULOS
# ============================================================

func _triangulo(
	st: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3
) -> void:
	for vertice in [a, b, c]:
		st.set_color(Color.WHITE)
		st.set_uv(
			Vector2(vertice.x, -vertice.z)
			* escala_uv_suelo
		)
		st.add_vertex(vertice)


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
	var exterior := (
		(a + b + c) / 3.0 - centro
	)

	exterior.y = 0.0

	if (b - a).cross(c - a).dot(exterior) < 0.0:
		_triangulo(st, a, c, b)
	else:
		_triangulo(st, a, b, c)


# Superficies con normales hacia arriba.
func _triangulo_suelo(
	st: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3
) -> void:
	var cruz := (b - a).cross(c - a)

	if cruz.y > 0.0:
		var temporal := b
		b = c
		c = temporal

	for vertice in [a, b, c]:
		st.set_normal(Vector3.UP)
		st.set_color(Color.WHITE)
		st.set_uv(
			Vector2(vertice.x, -vertice.z)
			* escala_uv_suelo
		)
		st.add_vertex(vertice)


# ============================================================
# MALLA PLANA DESDE POLIGONO
# ============================================================

func _malla_plana(
	poligono: PackedVector2Array,
	altura: float
) -> ArrayMesh:
	if poligono.size() < 3:
		return null

	var indices := Geometry2D.triangulate_polygon(
		poligono
	)

	if indices.is_empty():
		return null

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(0, indices.size(), 3):
		var a := _p3(
			poligono[indices[i]], altura
		)
		var b := _p3(
			poligono[indices[i + 1]], altura
		)
		var c := _p3(
			poligono[indices[i + 2]], altura
		)

		_triangulo_suelo(st, a, b, c)

	return st.commit()


# ============================================================
# MALLA SOLIDA PARA EDIFICIOS
# ============================================================

func _malla_solida(
	poligono: PackedVector2Array,
	base: float,
	altura: float
) -> ArrayMesh:
	if poligono.size() < 3:
		return null

	var indices := Geometry2D.triangulate_polygon(
		poligono
	)

	if indices.is_empty():
		return null

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var techo: float = base + altura

	for i in range(0, indices.size(), 3):
		_triangulo_arriba(
			st,
			_p3(poligono[indices[i]], techo),
			_p3(poligono[indices[i + 1]], techo),
			_p3(poligono[indices[i + 2]], techo)
		)

	var centro := Vector3.ZERO

	for punto in poligono:
		centro += _p3(
			punto,
			base + altura * 0.5
		)

	centro /= float(poligono.size())

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


# ============================================================
# AGREGAR MALLA GENERADA
# ============================================================

func _agregar_malla(
	carpeta: String,
	nombre: String,
	malla: ArrayMesh,
	color: Color,
	colision: bool = false,
	material_personalizado: Material = null
) -> MeshInstance3D:
	if malla == null:
		return null

	var instancia := MeshInstance3D.new()

	instancia.name = nombre
	instancia.mesh = malla

	if material_personalizado != null:
		instancia.material_override = material_personalizado
	else:
		instancia.material_override = _material(color)

	_capa(carpeta).add_child(instancia)

	if colision and generar_colisiones:
		if not Engine.is_editor_hint():
			instancia.create_trimesh_collision()

	return instancia


# ============================================================
# SUELO DE LA CIUDAD
# ============================================================

func _crear_suelo(feature: Dictionary) -> void:
	var anillos: Array = feature.get(
		"coordinates", []
	)

	if anillos.is_empty():
		push_warning("Ciudad: falta poligono earth.")
		return

	var poligono := _leer_anillo(anillos[0])

	if poligono.size() < 3:
		push_warning("Ciudad: contorno earth invalido.")
		return

	# Suelo original del mapa.
	_agregar_malla(
		"Environment",
		"DesertGround",
		_malla_plana(poligono, -0.2),
		Color(0.72, 0.60, 0.43),
		not usar_suelo_continuo,
		_material_del_suelo()
	)

	# Respaldo visible desde arriba.
	# Queda por encima del suelo original,
	# pero debajo de caminos, campos y agua.
	if usar_suelo_continuo:
		_crear_suelo_rectangular(poligono)


# ============================================================
# SUELO CONTINUO DE RESPALDO
#
# PlaneMesh de Godot:
# - No depende de Geometry2D.triangulate_polygon.
# - Tiene normales horizontales propias.
# - Utiliza el mismo material que el tutorial.
# - Cubre toda la zona rectangular del mapa.
#
# Es temporal: no respeta exactamente la costa.
# ============================================================

func _crear_suelo_rectangular(
	poligono: PackedVector2Array
) -> void:
	if poligono.is_empty():
		return

	var minimo := Vector2(INF, INF)
	var maximo := Vector2(-INF, -INF)

	for punto in poligono:
		minimo.x = minf(minimo.x, punto.x)
		minimo.y = minf(minimo.y, punto.y)
		maximo.x = maxf(maximo.x, punto.x)
		maximo.y = maxf(maximo.y, punto.y)

	var centro: Vector2 = (minimo + maximo) * 0.5

	var ancho: float = maxf(
		maximo.x - minimo.x + margen_suelo * 2.0,
		20.0
	)

	var largo: float = maxf(
		maximo.y - minimo.y + margen_suelo * 2.0,
		20.0
	)

	# Plano nativo de Godot: orientado hacia arriba.
	var plano := PlaneMesh.new()
	plano.size = Vector2(ancho, largo)

	var suelo := MeshInstance3D.new()
	suelo.name = "SueloContinuo"

	suelo.mesh = plano
	suelo.position = _p3(centro, altura_suelo)
	suelo.material_override = _material_del_suelo()

	suelo.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)

	_capa("Environment").add_child(suelo)

	# Crear un cuerpo estatico para caminar.
	if generar_colisiones and colision_suelo_continuo:
		if not Engine.is_editor_hint():
			var cuerpo := StaticBody3D.new()
			cuerpo.name = "ColisionSueloContinuo"

			cuerpo.collision_layer = 1
			cuerpo.collision_mask = 1

			cuerpo.position = _p3(
				centro,
				altura_suelo - 0.10
			)

			var colision := CollisionShape3D.new()

			var caja := BoxShape3D.new()
			caja.size = Vector3(
				ancho,
				0.20,
				largo
			)

			colision.shape = caja
			cuerpo.add_child(colision)

			_capa("Environment").add_child(cuerpo)

	print(
		"Ciudad: suelo continuo creado: ",
		ancho, " x ", largo
	)


# ============================================================
# MAR
# ============================================================

func _crear_agua(feature: Dictionary) -> void:
	var poligonos: Array = feature.get(
		"coordinates", []
	)

	var indice := 0

	for raw in poligonos:
		if not (raw is Array) or raw.is_empty():
			continue

		var poligono := _leer_anillo(raw[0])

		_agregar_malla(
			"Environment",
			"Sea_%03d" % indice,
			_malla_plana(poligono, -0.12),
			Color(0.09, 0.32, 0.48),
			false,
			material_agua
		)

		indice += 1


# ============================================================
# CAMINOS Y MUELLES
# ============================================================

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
			-direccion.y,
			direccion.x
		).normalized() * ancho * 0.5

		var v1 := _p3(a + lateral, altura)
		var v2 := _p3(a - lateral, altura)
		var v3 := _p3(b - lateral, altura)
		var v4 := _p3(b + lateral, altura)

		_triangulo_suelo(st, v1, v2, v3)
		_triangulo_suelo(st, v1, v3, v4)

		segmentos += 1

	if segmentos == 0:
		return null

	return st.commit()


# ============================================================
# CAMINOS
# ============================================================

func _crear_caminos(feature: Dictionary) -> void:
	var geometries: Array = feature.get(
		"geometries", []
	)

	var indice := 0

	for g in geometries:
		if g.get("type", "") != "LineString":
			continue

		var puntos := _leer_anillo(
			g.get("coordinates", [])
		)

		var ancho: float = (
			float(g.get("width", 8.0)) * escala
		)

		_agregar_malla(
			"Environment",
			"Road_%03d" % indice,
			_malla_camino(puntos, ancho, -0.16),
			Color(0.42, 0.33, 0.24),
			false,
			material_camino
		)

		indice += 1


# ============================================================
# CAMPOS
# ============================================================

func _crear_campos(feature: Dictionary) -> void:
	var poligonos: Array = feature.get(
		"coordinates", []
	)

	var indice := 0

	for raw in poligonos:
		if not (raw is Array) or raw.is_empty():
			continue

		var poligono := _leer_anillo(raw[0])

		_agregar_malla(
			"Environment",
			"Field_%03d" % indice,
			_malla_plana(poligono, -0.15),
			Color(0.39, 0.37, 0.20),
			false,
			material_campo
		)

		indice += 1


# ============================================================
# HABITACION: COMPROBAR EDIFICIOS CERCANOS
# ============================================================

func _interfiere_habitacion(
	poligono: PackedVector2Array
) -> bool:
	var mundo := PackedVector2Array()

	for p in poligono:
		mundo.append(Vector2(p.x, -p.y))

	if Geometry2D.is_point_in_polygon(
		centro_habitacion_xz,
		mundo
	):
		return true

	for p in mundo:
		if p.distance_to(
			centro_habitacion_xz
		) < radio_libre_habitacion:
			return true

	return false


# ============================================================
# EDIFICIOS DEL JSON
# ============================================================

func _crear_edificios(feature: Dictionary) -> void:
	var poligonos: Array = feature.get(
		"coordinates", []
	)

	var indice := 0
	var construidos := 0

	for raw in poligonos:
		if not (raw is Array) or raw.is_empty():
			indice += 1
			continue

		var poligono := _leer_anillo(raw[0])

		var altura: float = (
			6.0 + float(indice % 5) * 2.0
		)

		var despejar := _interfiere_habitacion(
			poligono
		)

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

			if despejar:
				instancia.visible = false

		indice += 1

	print(
		"Ciudad: edificios construidos: ",
		construidos
	)


# ============================================================
# MURALLAS
# ============================================================

func _crear_murallas(feature: Dictionary) -> void:
	var geometries: Array = feature.get(
		"geometries", []
	)

	var indice := 0

	for g in geometries:
		if g.get("type", "") != "Polygon":
			continue

		var anillos: Array = g.get(
			"coordinates", []
		)

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


# ============================================================
# CASTILLO
# ============================================================

func _crear_castillo(feature: Dictionary) -> void:
	var geometries: Array = feature.get(
		"geometries", []
	)

	for g in geometries:
		if str(
			g.get("name", "")
		).to_lower() != "castle":
			continue

		var anillos: Array = g.get(
			"coordinates", []
		)

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


# ============================================================
# MUELLES
# ============================================================

func _crear_muelles(feature: Dictionary) -> void:
	var geometries: Array = feature.get(
		"geometries", []
	)

	var indice := 0

	for g in geometries:
		if g.get("type", "") != "LineString":
			continue

		var puntos := _leer_anillo(
			g.get("coordinates", [])
		)

		var ancho: float = (
			float(g.get("width", 3.0)) * escala
		)

		_agregar_malla(
			"Docks",
			"Dock_%03d" % indice,
			_malla_camino(puntos, ancho, 0.08),
			Color(0.34, 0.22, 0.13)
		)

		indice += 1
