@tool
extends Node3D

# Ciudad costera con valle occidental y bahía al este.

@export_group("Ciudad")
@export_range(0, 50, 1) var cantidad_casas: int = 36
@export var semilla: int = 2026
@export var generar_colisiones: bool = true
@export var generar_casas: bool = true
@export var generar_decoracion: bool = true

@export_group("Oceano V3")
@export var cielo_costero: bool = true
@export var ancho_oceano_v25: float = 1700.0
@export var largo_oceano_v25: float = 1700.0
@export var centro_oceano_v25: float = 650.0
@export var nivel_mar_v25: float = -3.5

@export_group("Llegada cinematica")
@export_range(90.0, 500.0, 5.0) var longitud_camino_llegada: float = 310.0
@export_range(140.0, 300.0, 5.0) var semiancho_valle_v25: float = 190.0
@export_range(5.0, 16.0, 1.0) var paso_malla_v25: float = 5.0
@export_range(12.0, 65.0, 1.0) var altura_montanas_v25: float = 38.0
@export_range(0.0, 6.0, 0.25) var ondulacion_arena_v25: float = 2.0
@export_range(0.0, 650.0, 10.0) var fondo_escenico: float = 200.0
@export var generar_montanas_v25: bool = true
@export_range(0.0, 1.0, 0.05) var estratos_montanas: float = 0.5

@export_group("Materiales")
@export var material_arena: Material

@export_group("Luz y ambiente")
@export var ajustar_luz_y_ambiente: bool = true
@export_range(-180.0, 180.0, 1.0) var azimut_sol: float = 75.0
@export_range(5.0, 60.0, 1.0) var elevacion_sol: float = 22.0
@export_range(0.5, 3.0, 0.05) var energia_sol: float = 1.6
@export var activar_niebla: bool = true
@export_range(0.0, 0.01, 0.0001) var densidad_niebla: float = 0.0012
@export_range(0.0, 1.0, 0.05) var perspectiva_aerea: float = 0.6

@export_group("Texturas de roca (opcional)")
@export var textura_roca_albedo: Texture2D
@export var textura_roca_normal: Texture2D
@export_range(0.01, 0.3, 0.005) var escala_textura_roca: float = 0.07

@export_group("Texturas de suelo (opcional)")
@export var textura_suelo_a_albedo: Texture2D
@export var textura_suelo_a_normal: Texture2D
@export_range(0.02, 0.5, 0.01) var escala_suelo_a: float = 0.15
@export var textura_suelo_b_albedo: Texture2D
@export var textura_suelo_b_normal: Texture2D
@export_range(0.02, 0.5, 0.01) var escala_suelo_b: float = 0.10
@export_range(0.0, 1.0, 0.05) var cobertura_suelo_base: float = 0.8

@export_group("Texturas automaticas")
@export var cargar_texturas_automaticamente: bool = true
@export_dir var carpeta_roca: String = "res://assets/texturas/roca montañas"
@export_dir var carpeta_suelo_a: String = "res://assets/texturas/arena linda"
@export_dir var carpeta_suelo_b: String = "res://assets/texturas/mas arena"

@export_group("Rocas en las sierras")
@export var generar_rocas_sierras: bool = true
@export_range(0.1, 1.0, 0.05) var densidad_rocas: float = 0.6
@export_range(0.5, 2.5, 0.1) var tamano_rocas: float = 1.0
@export_range(200, 4000, 100) var maximo_rocas: int = 3000

@export_group("Cordillera lejana")
@export var generar_cordillera: bool = true
@export_range(1, 4, 1) var capas_cordillera: int = 3
@export_range(40.0, 300.0, 5.0) var altura_cordillera: float = 110.0

@export_group("Castillo")
@export_range(15.0, 45.0, 1.0) var altura_castillo: float = 25.0

@export_group("Castillo de montaña")
@export var generar_castillo_montana: bool = true
@export_range(-400.0, -100.0, 5.0) var x_castillo_montana: float = -200.0
@export_range(-1.0, 1.0, 2.0) var lado_castillo_montana: float = -1.0  # -1 norte, 1 sur
@export_range(16.0, 80.0, 1.0) var radio_meseta: float = 44.0

@export_group("Generacion")
@export_tool_button("Construir puerto V3.4")
var boton_generar = generar_ciudad


const ESCENA_MUELLE: PackedScene = preload("res://scenes/city/muelle.tscn")
const RUTA_ARENA := "res://assets/texturas/arena/terreno_arena.tres"
const RUTA_SHADER_MURALLA := "res://scripts/city/muralla_piedra.gdshader"
const EXTENSIONES_IMAGEN := ["jpg", "jpeg", "png", "webp", "tga", "exr"]

const CAPAS := [
	"Buildings", "Castle", "Walls", "Docks", "Environment", "Market", "Props"
]

const CENTRO_CASTILLO := Vector2(-95, -63)
const CENTRO_PLAZA := Vector2(-8, 8)

const CONTORNO := [
	Vector2(-145, -190),
	Vector2(-60, -128),
	Vector2(18, -124),
	Vector2(82, -108),
	Vector2(110, -84),
	Vector2(100, -58),
	Vector2(84, -30),
	Vector2(77, 3),
	Vector2(80, 28),
	Vector2(91, 55),
	Vector2(112, 78),
	Vector2(118, 108),
	Vector2(65, 130),
	Vector2(20, 138),
	Vector2(-90, 140),
	Vector2(-145, 190)
]

var _rng := RandomNumberGenerator.new()
var _ruido_grande := FastNoiseLite.new()
var _ruido_medio := FastNoiseLite.new()
var _ruido_detalle := FastNoiseLite.new()
var _ruido_erosion := FastNoiseLite.new()
var _tierra := PackedVector2Array()

var _arena: Material
var _terreno: Material
var _cache_suelo: Dictionary = {}
var _piedra: Material
var _muro: Material
var _piedra_oscura: Material
var _roca: Material
var _teja: Material
var _madera: Material
var _camino: Material
var _agua: Material
var _tela_roja: Material
var _tela_ocre: Material
var _tela_azul: Material

var _meseta_xz := Vector2.ZERO
var _meseta_y := 0.0
var _meseta_lista := false


# GENERACIÓN DE LA CIUDAD

func _ready() -> void:
	if not Engine.is_editor_hint():
		generar_ciudad()


func _capa(nombre: String) -> Node3D:
	return get_node_or_null("GeneratedCity/" + nombre) as Node3D


func generar_ciudad() -> void:
	if not is_node_ready():
		return

	var raiz := get_node_or_null("GeneratedCity") as Node3D
	if raiz == null:
		push_error("Falta GeneratedCity.")
		return

	for nombre in CAPAS:
		if _capa(nombre) == null:
			var carpeta := Node3D.new()
			carpeta.name = nombre
			raiz.add_child(carpeta)

	for nombre in CAPAS:
		var carpeta := _capa(nombre)
		for hijo in carpeta.get_children():
			carpeta.remove_child(hijo)
			hijo.free()

	_rng.seed = semilla
	_meseta_lista = false
	_tierra = PackedVector2Array(CONTORNO)

	_configurar_ruido()
	_preparar_materiales()

	print("Mundo Bonito: generando V3...")

	_crear_terreno()
	_crear_cordillera_lejana()
	_crear_colina_castillo()
	_crear_caminos()
	_crear_murallas()
	_crear_castillo()
	_crear_plaza()
	_crear_puerto()

	if generar_casas:
		_crear_barrio()

	if generar_decoracion:
		_decorar_rocas()

	_esparcir_rocas_sierras()
	_ajustar_luz_y_ambiente()

	print("Mundo Bonito: V3.4 terminada.")


func _configurar_ruido() -> void:
	_ruido_grande.seed = semilla
	_ruido_grande.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ruido_grande.frequency = 0.008

	_ruido_medio.seed = semilla + 437
	_ruido_medio.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ruido_medio.frequency = 0.025

	_ruido_detalle.seed = semilla + 891
	_ruido_detalle.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ruido_detalle.frequency = 0.055

	_ruido_erosion.seed = semilla + 1313
	_ruido_erosion.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ruido_erosion.frequency = 1.0  # las escalas se controlan al llamar a _cresta()


# MATERIALES

func _mat(color: Color, rugosidad: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rugosidad
	m.metallic = 0.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# CARGA AUTOMÁTICA DE TEXTURAS

# Busca en una carpeta el primer archivo cuyo nombre contenga alguna de las
# claves (en orden de prioridad). Funciona también en el juego exportado,
# donde los archivos aparecen como "nombre.jpg.import".
func _buscar_textura(
	carpeta: String, claves: Array, excluir: Array = []
) -> Texture2D:
	if carpeta.is_empty() or not DirAccess.dir_exists_absolute(carpeta):
		return null

	var nombres: Array[String] = []
	for archivo in DirAccess.get_files_at(carpeta):
		var nombre := archivo.trim_suffix(".import")
		if nombre.get_extension().to_lower() in EXTENSIONES_IMAGEN \
				and not nombres.has(nombre):
			nombres.append(nombre)

	for clave: String in claves:
		for nombre in nombres:
			var minuscula := nombre.to_lower()
			if not minuscula.contains(clave):
				continue

			var descartado := false
			for malo: String in excluir:
				if minuscula.contains(malo):
					descartado = true
					break
			if descartado:
				continue

			var recurso := load(carpeta.path_join(nombre))
			if recurso is Texture2D:
				return recurso as Texture2D
	return null


func _buscar_color(carpeta: String) -> Texture2D:
	return _buscar_textura(
		carpeta, ["color", "albedo", "basecolor", "diffuse"]
	)


# El shader espera normal map estilo OpenGL (NormalGL), no DirectX.
func _buscar_normal(carpeta: String) -> Texture2D:
	return _buscar_textura(
		carpeta, ["normalgl", "normal_gl", "normal"], ["normaldx", "normal_dx"]
	)


func _cargar_texturas_automaticas() -> void:
	if not cargar_texturas_automaticamente:
		return

	if textura_roca_albedo == null:
		textura_roca_albedo = _buscar_color(carpeta_roca)
	if textura_roca_normal == null:
		textura_roca_normal = _buscar_normal(carpeta_roca)

	if textura_suelo_a_albedo == null:
		textura_suelo_a_albedo = _buscar_color(carpeta_suelo_a)
	if textura_suelo_a_normal == null:
		textura_suelo_a_normal = _buscar_normal(carpeta_suelo_a)

	if textura_suelo_b_albedo == null:
		textura_suelo_b_albedo = _buscar_color(carpeta_suelo_b)
	if textura_suelo_b_normal == null:
		textura_suelo_b_normal = _buscar_normal(carpeta_suelo_b)

	print(
		"Texturas auto -> roca: ", textura_roca_albedo != null,
		"/", textura_roca_normal != null,
		" | suelo A: ", textura_suelo_a_albedo != null,
		"/", textura_suelo_a_normal != null,
		" | suelo B: ", textura_suelo_b_albedo != null,
		"/", textura_suelo_b_normal != null
	)


func _preparar_materiales() -> void:
	if material_arena != null:
		_arena = material_arena
	elif ResourceLoader.exists(RUTA_ARENA):
		_arena = load(RUTA_ARENA) as Material
	else:
		_arena = _mat(Color(0.76, 0.64, 0.46))

	_cargar_texturas_automaticas()
	_terreno = _crear_material_terreno()

	_piedra = _mat(Color(0.72, 0.62, 0.47))

	# Piedra con ladrillos para las murallas (si falta el shader, usa piedra lisa).
	if ResourceLoader.exists(RUTA_SHADER_MURALLA):
		var piedra_muro := ShaderMaterial.new()
		piedra_muro.shader = load(RUTA_SHADER_MURALLA)
		_muro = piedra_muro
	else:
		_muro = _piedra

	_piedra_oscura = _mat(Color(0.54, 0.47, 0.37))
	_roca = _mat(Color(0.49, 0.39, 0.29))
	_teja = _mat(Color(0.47, 0.29, 0.20))
	_madera = _mat(Color(0.32, 0.21, 0.13))
	_camino = _mat(Color(0.64, 0.54, 0.40))

	var agua_costera := ShaderMaterial.new()
	agua_costera.shader = preload("agua_costera.gdshader")
	agua_costera.set_shader_parameter(
		"tamano", Vector2(ancho_oceano_v25, largo_oceano_v25)
	)
	agua_costera.set_shader_parameter("centro_x", centro_oceano_v25)
	_agua = agua_costera

	_tela_roja = _mat(Color(0.63, 0.26, 0.18))
	_tela_ocre = _mat(Color(0.76, 0.56, 0.28))
	_tela_azul = _mat(Color(0.24, 0.40, 0.48))


# BLOQUES Y COLISIONES

func _caja(
	padre: Node3D,
	nombre: String,
	posicion: Vector3,
	tamano: Vector3,
	material: Material,
	colision: bool = true
) -> MeshInstance3D:
	var nodo := MeshInstance3D.new()
	nodo.name = nombre
	nodo.position = posicion

	var malla := BoxMesh.new()
	malla.size = tamano
	nodo.mesh = malla
	nodo.material_override = material
	padre.add_child(nodo)

	if colision and generar_colisiones and not Engine.is_editor_hint():
		var cuerpo := StaticBody3D.new()
		cuerpo.collision_layer = 1

		var forma := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = tamano
		forma.shape = caja
		cuerpo.add_child(forma)
		nodo.add_child(cuerpo)

	return nodo


func _torre(
	padre: Node3D,
	nombre: String,
	posicion: Vector3,
	radio: float,
	altura: float,
	material: Material
) -> void:
	var nodo := MeshInstance3D.new()
	nodo.name = nombre
	nodo.position = posicion

	var malla := CylinderMesh.new()
	malla.top_radius = radio
	malla.bottom_radius = radio * 1.08
	malla.height = altura
	nodo.mesh = malla
	nodo.material_override = material
	padre.add_child(nodo)

	if generar_colisiones and not Engine.is_editor_hint():
		var cuerpo := StaticBody3D.new()
		cuerpo.collision_layer = 1

		var forma := CollisionShape3D.new()
		var cilindro := CylinderShape3D.new()
		cilindro.radius = radio * 1.08
		cilindro.height = altura
		forma.shape = cilindro
		cuerpo.add_child(forma)
		nodo.add_child(cuerpo)


func _bloque_entre(
	padre: Node3D,
	nombre: String,
	inicio: Vector3,
	fin: Vector3,
	ancho: float,
	grosor: float,
	material: Material,
	colision: bool = true
) -> void:
	var direccion := fin - inicio
	if direccion.length() < 0.01:
		return

	var medio := (inicio + fin) * 0.5
	var bloque := _caja(
		padre, nombre, medio,
		Vector3(ancho, grosor, direccion.length()),
		material, colision
	)
	bloque.look_at(bloque.global_position - direccion, Vector3.UP)


func _segmento(
	padre: Node3D,
	nombre: String,
	inicio: Vector2,
	fin: Vector2,
	ancho: float,
	altura: float,
	material: Material,
	base_y: float = 0.0,
	colision: bool = true
) -> void:
	_bloque_entre(
		padre, nombre,
		Vector3(inicio.x, base_y + altura * 0.5, inicio.y),
		Vector3(fin.x, base_y + altura * 0.5, fin.y),
		ancho, altura, material, colision
	)


# GEOMETRÍA

func _vertice(st: SurfaceTool, punto: Vector3) -> void:
	st.set_uv(Vector2(punto.x, punto.z) * 0.12)
	st.add_vertex(punto)


func _triangulo(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	_vertice(st, a)
	_vertice(st, b)
	_vertice(st, c)


func _triangulo_suelo(
	st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, es_desierto: bool
) -> void:
	if (b - a).cross(c - a).y > 0.0:
		var temporal := b
		b = c
		c = temporal

	for p in [a, b, c]:
		var normal := Vector3.UP
		var color := Color.WHITE
		if es_desierto:
			var datos: Array = _datos_suelo(p.x, p.y, p.z)
			normal = datos[0]
			color = datos[1]

		st.set_normal(normal)
		st.set_color(color)
		st.set_uv(Vector2(p.x, p.z) * 0.12)
		st.add_vertex(p)


func _malla_plana(poligono: PackedVector2Array, altura: float) -> ArrayMesh:
	var indices := Geometry2D.triangulate_polygon(poligono)
	if indices.is_empty():
		push_error("Error triangulando la peninsula.")
		return null

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(0, indices.size(), 3):
		var a2: Vector2 = poligono[indices[i]]
		var b2: Vector2 = poligono[indices[i + 1]]
		var c2: Vector2 = poligono[indices[i + 2]]
		_triangulo_suelo(
			st,
			Vector3(a2.x, altura, a2.y),
			Vector3(b2.x, altura, b2.y),
			Vector3(c2.x, altura, c2.y),
			false
		)

	return st.commit()


func _agregar_malla(
	padre: Node3D,
	nombre: String,
	malla: ArrayMesh,
	material: Material,
	colision: bool = false
) -> void:
	if malla == null:
		return

	var nodo := MeshInstance3D.new()
	nodo.name = nombre
	nodo.mesh = malla
	nodo.material_override = material
	padre.add_child(nodo)

	if colision and generar_colisiones and not Engine.is_editor_hint():
		var concava := malla.create_trimesh_shape()
		if concava != null:
			concava.backface_collision = true

			var cuerpo := StaticBody3D.new()
			cuerpo.collision_layer = 1
			var forma := CollisionShape3D.new()
			forma.shape = concava
			cuerpo.add_child(forma)
			nodo.add_child(cuerpo)


# COSTA Y SIERRAS

func _costa(z: float) -> float:
	for i in range(4, 11):
		var a: Vector2 = CONTORNO[i]
		var b: Vector2 = CONTORNO[i + 1]
		if z >= a.y and z <= b.y:
			return lerpf(a.x, b.x, inverse_lerp(a.y, b.y, z))

	var extremo: Vector2 = CONTORNO[4] if z < 0 else CONTORNO[11]
	var distancia := absf(z - extremo.y)
	return extremo.x + 25.0 * sin(distancia * 0.012) + 0.045 * distancia


func _eje_sierra(x: float, lado: float) -> float:
	var fase := lado * 2.3
	var valle := semiancho_valle_v25 * 0.57
	var urbano := lerpf(valle, 195.0, smoothstep(-240.0, -145.0, x))
	return lado * (
		urbano + 10.0 * sin(x * 0.021 + fase) + 5.0 * sin(x * 0.047 - fase)
	)


# Ruido de crestas afiladas: 1 - |ruido|, al cuadrado para estrechar las aristas.
func _cresta(x: float, y: float, octavas: int = 4) -> float:
	var suma := 0.0
	var amplitud := 0.5
	var px := x
	var py := y
	for i in range(octavas):
		var n := 1.0 - absf(_ruido_erosion.get_noise_2d(px, py))
		suma += amplitud * n * n
		px = px * 2.07 + 11.3
		py = py * 2.07 + 4.7
		amplitud *= 0.5
	return suma


# Altura original del terreno (sin la meseta del castillo de montaña).
func _altura_base(x: float, z: float) -> float:
	var orilla := _costa(z) - x
	if orilla < 0.0:
		return maxf(nivel_mar_v25 - 8.0, orilla * 0.65)

	var ruido := _ruido_grande.get_noise_2d(x, z)
	var detalle := _ruido_medio.get_noise_2d(x, z)
	var exterior := maxf(-146.0 - x, absf(z) - 124.0)
	var dunas := ondulacion_arena_v25 * (ruido + detalle * 0.42)
	dunas *= smoothstep(0.0, 32.0, exterior) * smoothstep(10.0, 36.0, absf(z - 8.0))

	var monte := 0.0
	if generar_montanas_v25:
		var lado := signf(z)
		var d := lado * (z - _eje_sierra(x, lado))
		var base := smoothstep(-49.0, -9.0, d) * (1.0 - smoothstep(5.0, 52.0, d))
		var cima := 1.0 - smoothstep(0.0, 24.0, absf(d + 4.0 * detalle))
		var agujas := pow(0.5 + 0.5 * sin(x * 0.039 + lado * 2.0 + ruido * 2.2), 2.0)
		var segunda := 1.0 - smoothstep(0.0, 39.0, absf(d - 47.0 - 8.0 * ruido))

		# Masa general (forma original).
		var masa := altura_montanas_v25 * (
			base * (1.45 + detalle * 0.28)
			+ cima * (0.45 + agujas)
			+ segunda * (1.25 + ruido)
		)

		# Compresión suave: redondea las cimas y evita paredes casi verticales.
		var tope := altura_montanas_v25 * 1.8
		masa = tope * (1.0 - exp(-masa / tope))

		# Erosión moderada. Solo 2 octavas: más finas que ~4 celdas de malla
		# producen escalones (aliasing). El detalle fino lo pone el shader.
		var altura_rel := clampf(masa / tope, 0.0, 1.0)
		if altura_rel > 0.06:
			var dw := d + 14.0 * _ruido_detalle.get_noise_2d(x + 300.0, z)
			var xw := x + 10.0 * _ruido_medio.get_noise_2d(x, z + 300.0)
			var barrancos := _cresta(xw * 0.028, dw * 0.0085, 2) / 0.75
			var fino := _cresta(xw * 0.035, dw * 0.020, 2) / 0.75
			var talud := smoothstep(0.06, 0.40, altura_rel)
			masa *= lerpf(1.0, 0.62 + 0.55 * barrancos, talud)
			masa += altura_montanas_v25 * 0.07 * fino * talud

			# Estratos: la roca sube en tramos con repisas casi planas.
			# El ruido desplaza cada banda para que no sean todas iguales.
			if estratos_montanas > 0.0:
				var alto_banda := altura_montanas_v25 * 0.14
				var q := (masa + 3.0 * detalle + 2.0 * ruido) / alto_banda
				var entero := floorf(q)
				var repisa := smoothstep(0.45, 0.95, q - entero)
				var escalonada := (entero + repisa) * alto_banda - 3.0 * detalle - 2.0 * ruido
				var aplicar := estratos_montanas * smoothstep(0.12, 0.30, altura_rel)
				masa = lerpf(masa, maxf(escalonada, 0.0), aplicar)

		monte = masa * smoothstep(32.0, 55.0, absf(z - 8.0))

	return (monte + dunas) * smoothstep(0.0, 32.0, orilla)


# Calcula dónde y a qué altura queda la meseta plana del castillo de montaña.
func _preparar_meseta() -> void:
	var lado := lado_castillo_montana
	_meseta_xz = Vector2(
		x_castillo_montana, _eje_sierra(x_castillo_montana, lado) + lado * 8.0
	)
	var suma := 0.0
	for dir: Vector2 in DIRECCIONES_AO:
		suma += _altura_base(
			_meseta_xz.x + dir.x * radio_meseta * 0.6,
			_meseta_xz.y + dir.y * radio_meseta * 0.6
		)
	_meseta_y = maxf(
		suma / 8.0, _altura_base(_meseta_xz.x, _meseta_xz.y) * 0.85
	)
	_meseta_lista = true


# Altura final del terreno: la base, con la meseta aplanada para el castillo.
func _altura_desierto(x: float, z: float) -> float:
	var h := _altura_base(x, z)
	if not generar_castillo_montana or not generar_montanas_v25:
		return h
	if not _meseta_lista:
		_preparar_meseta()

	var d := Vector2(x, z).distance_to(_meseta_xz)
	var w := 1.0 - smoothstep(radio_meseta, radio_meseta * 1.85, d)
	return lerpf(h, _meseta_y, w)


func _limites_sierras(oeste: float) -> void:
	if Engine.is_editor_hint() or not generar_colisiones or not generar_montanas_v25:
		return

	var cuerpo := StaticBody3D.new()
	cuerpo.name = "LimitesSierras"
	cuerpo.collision_layer = 1
	_capa("Environment").add_child(cuerpo)

	for lado: float in [-1.0, 1.0]:
		var x := oeste
		while x < 160.0:
			var fin := minf(x + 12.0, 160.0)

			# Sin barrera invisible en el castillo de montaña: así se puede entrar.
			if generar_castillo_montana \
					and signf(lado) == signf(lado_castillo_montana) \
					and absf(x + 6.0 - x_castillo_montana) < radio_meseta + 6.0:
				x = fin
				continue

			var a := Vector3(x, 0.0, _eje_sierra(x, lado) - lado * 12.0)
			var b := Vector3(fin, 0.0, _eje_sierra(fin, lado) - lado * 12.0)
			var caja := BoxShape3D.new()
			caja.size = Vector3(
				2.0, altura_montanas_v25 * 8.0 + 140.0, a.distance_to(b) + 1.0
			)
			var forma := CollisionShape3D.new()
			forma.shape = caja
			forma.position = (a + b) * 0.5
			forma.rotation.y = atan2(b.x - a.x, b.z - a.z)
			cuerpo.add_child(forma)
			x = fin


func _normal_desierto(x: float, z: float) -> Vector3:
	var muestra := maxf(1.5, paso_malla_v25 * 0.5)
	var dx := (
		_altura_desierto(x + muestra, z) - _altura_desierto(x - muestra, z)
	) / (muestra * 2.0)
	var dz := (
		_altura_desierto(x, z + muestra) - _altura_desierto(x, z - muestra)
	) / (muestra * 2.0)

	return Vector3(-dx, 1.0, -dz).normalized()


func _crear_desierto_dunas() -> void:
	_cache_suelo.clear()
	var filas := PackedFloat32Array()
	var columnas := PackedFloat32Array()
	var alcance := maxf(semiancho_valle_v25 * 1.7, 330.0)
	var fondo := 145.0 + longitud_camino_llegada + fondo_escenico
	_limites_sierras(-fondo)

	var nz := ceili(2.0 * alcance / paso_malla_v25)
	for i in range(nz + 1):
		filas.append(lerpf(-alcance, alcance, float(i) / nz))

	for i in range(4, 12):
		var punto: Vector2 = CONTORNO[i]
		if not filas.has(punto.y):
			filas.append(punto.y)
	filas.sort()

	columnas.append(-1.0)
	columnas.append(0.0)
	var nx := ceili((fondo + 140.0) / paso_malla_v25)
	for i in range(1, nx + 1):
		columnas.append(float(i) / nx)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for j in range(filas.size() - 1):
		var z0 := filas[j]
		var z1 := filas[j + 1]
		var costa0 := _costa(z0)
		var costa1 := _costa(z1)

		for i in range(columnas.size() - 1):
			var a := _fila_llegada(costa0, -fondo, columnas[i], z0)
			var b := _fila_llegada(costa0, -fondo, columnas[i + 1], z0)
			var c := _fila_llegada(costa1, -fondo, columnas[i + 1], z1)
			var d := _fila_llegada(costa1, -fondo, columnas[i], z1)
			_triangulo_suelo(st, a, b, c, true)
			_triangulo_suelo(st, a, c, d, true)

	_agregar_malla(_capa("Environment"), "CostaYValle", st.commit(), _terreno, true)
	_cache_suelo.clear()


func _fila_llegada(costa: float, oeste: float, t: float, z: float) -> Vector3:
	var x := lerpf(costa, oeste, t) if t >= 0.0 else costa + maxf(40.0, -nivel_mar_v25 * 2.0 + 20.0)
	return Vector3(x, _altura_desierto(x, z), z)


# TERRENO, MATERIAL DE LAS MONTAÑAS Y MAR

func _crear_terreno() -> void:
	var entorno := _capa("Environment")

	_crear_desierto_dunas()

	var mar_mesh := PlaneMesh.new()
	mar_mesh.subdivide_width = 159
	mar_mesh.subdivide_depth = 159
	mar_mesh.size = Vector2(ancho_oceano_v25, largo_oceano_v25)

	var mar := MeshInstance3D.new()
	mar.name = "Oceano"
	mar.mesh = mar_mesh
	mar.position = Vector3(centro_oceano_v25, nivel_mar_v25, 0.0)
	mar.material_override = _agua
	mar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	entorno.add_child(mar)

	if cielo_costero:
		_preparar_cielo_costero()


# DATOS DE VÉRTICE DEL TERRENO (normal + oclusión + curvatura)

const DIRECCIONES_AO := [
	Vector2(1.0, 0.0), Vector2(0.7071, 0.7071),
	Vector2(0.0, 1.0), Vector2(-0.7071, 0.7071),
	Vector2(-1.0, 0.0), Vector2(-0.7071, -0.7071),
	Vector2(0.0, -1.0), Vector2(0.7071, -0.7071)
]


# Cada vértice se comparte entre ~6 triángulos: se calcula una sola vez.
func _datos_suelo(x: float, y: float, z: float) -> Array:
	var clave := Vector2(x, z)
	if _cache_suelo.has(clave):
		return _cache_suelo[clave]

	var datos := [_normal_desierto(x, z), _color_suelo(x, z, y)]
	_cache_suelo[clave] = datos
	return datos


# Canal R = oclusión ambiental falsa (1 = abierto, 0 = muy tapado).
# Canal G = curvatura (0.5 plano, > 0.5 cresta, < 0.5 barranco).
func _color_suelo(x: float, z: float, h0: float) -> Color:
	var oclusion := 0.0
	var suma_cerca := 0.0

	for dir: Vector2 in DIRECCIONES_AO:
		var hc := _altura_desierto(x + dir.x * 10.0, z + dir.y * 10.0)
		var hl := _altura_desierto(x + dir.x * 30.0, z + dir.y * 30.0)
		suma_cerca += hc
		oclusion += (
			0.6 * clampf((hc - h0) / 10.0, 0.0, 1.5)
			+ 0.4 * clampf((hl - h0) / 30.0, 0.0, 1.5)
		)

	oclusion /= 8.0 * 1.5
	var ao := 1.0 - clampf(oclusion * 1.6, 0.0, 0.9)
	var curvatura := clampf(0.5 + (h0 - suma_cerca / 8.0) / 8.0, 0.0, 1.0)
	return Color(ao, curvatura, 0.0, 1.0)


# Un solo material para arena + roca. Toma la textura de tu material de arena.
func _crear_material_terreno() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://scripts/city/terreno_sierras.gdshader")

	var estandar := _arena as StandardMaterial3D
	if estandar != null:
		m.set_shader_parameter("color_arena", estandar.albedo_color)
		m.set_shader_parameter(
			"escala_uv_arena", Vector2(estandar.uv1_scale.x, estandar.uv1_scale.y)
		)
		if estandar.albedo_texture != null:
			m.set_shader_parameter("textura_arena", estandar.albedo_texture)
			m.set_shader_parameter("usar_textura_arena", true)

	m.set_shader_parameter("escala_suelo_a", escala_suelo_a)
	m.set_shader_parameter("escala_suelo_b", escala_suelo_b)
	m.set_shader_parameter("cobertura_suelo_base", cobertura_suelo_base)
	if textura_suelo_a_albedo != null:
		m.set_shader_parameter("textura_suelo_a", textura_suelo_a_albedo)
		m.set_shader_parameter("usar_suelo_a", true)
	if textura_suelo_a_normal != null:
		m.set_shader_parameter("normal_suelo_a", textura_suelo_a_normal)
		m.set_shader_parameter("usar_normal_suelo_a", true)
	if textura_suelo_b_albedo != null:
		m.set_shader_parameter("textura_suelo_b", textura_suelo_b_albedo)
		m.set_shader_parameter("usar_suelo_b", true)
	if textura_suelo_b_normal != null:
		m.set_shader_parameter("normal_suelo_b", textura_suelo_b_normal)
		m.set_shader_parameter("usar_normal_suelo_b", true)

	m.set_shader_parameter("escala_textura_roca", escala_textura_roca)
	if textura_roca_albedo != null:
		m.set_shader_parameter("textura_roca", textura_roca_albedo)
		m.set_shader_parameter("usar_textura_roca", true)
	if textura_roca_normal != null:
		m.set_shader_parameter("normal_roca", textura_roca_normal)
		m.set_shader_parameter("usar_normal_roca", true)
	return m


# ROCAS Y PEÑASCOS EN LAS SIERRAS (MultiMesh)

func _esparcir_rocas_sierras() -> void:
	if not generar_rocas_sierras or not generar_montanas_v25:
		return

	var padre := _capa("Props")
	var material := _material_rocas()
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla + 7

	var variantes := 3
	var transformaciones: Array = []
	var colores: Array = []
	for v in range(variantes):
		transformaciones.append([])
		colores.append([])

	var fondo := 145.0 + longitud_camino_llegada + fondo_escenico
	var alcance := maxf(semiancho_valle_v25 * 1.7, 330.0)
	var paso := 5.0
	var nx := int((fondo + 110.0) / paso)
	var nz := int(2.0 * alcance / paso)
	var total := 0

	for i in range(nx):
		for j in range(nz):
			if total >= maximo_rocas:
				break

			var px := -fondo + (float(i) + azar.randf()) * paso
			var pz := -alcance + (float(j) + azar.randf()) * paso

			if px > _costa(pz) - 12.0:
				continue
			if px < -140.0 and absf(pz - 8.0) < 12.0:
				continue

			var h := _altura_desierto(px, pz)
			if h < 1.5:
				continue

			# Más rocas en laderas medias y al pie de la montaña (escombros).
			var normal := _normal_desierto(px, pz)
			var angulo := rad_to_deg(acos(clampf(normal.y, -1.0, 1.0)))
			var prob := smoothstep(8.0, 22.0, angulo) * (1.0 - smoothstep(55.0, 70.0, angulo))
			prob *= smoothstep(1.5, 6.0, h)
			prob *= 0.35 + 0.65 * (1.0 - smoothstep(10.0, 45.0, h))
			prob *= densidad_rocas * 0.35
			if azar.randf() > prob:
				continue

			# Muchas piedras pequeñas y pocos peñascos grandes.
			var tamano := lerpf(0.7, 4.5, pow(azar.randf(), 3.0)) * tamano_rocas
			var escala := Vector3(
				tamano * azar.randf_range(0.8, 1.3),
				tamano * azar.randf_range(0.6, 1.0),
				tamano * azar.randf_range(0.8, 1.3)
			)
			var eje := Vector3.UP.slerp(normal, 0.35)
			var base := Basis(Quaternion(Vector3.UP, eje))
			base = base * Basis(Vector3.UP, azar.randf() * TAU)
			base = base * Basis.from_scale(escala)

			# Se apoya en el punto más bajo de su huella y queda medio enterrada,
			# así no flota en las pendientes.
			var radio_roca := maxf(escala.x, escala.z)
			var suelo_min := h
			for dir: Vector2 in DIRECCIONES_AO:
				suelo_min = minf(
					suelo_min,
					_altura_desierto(px + dir.x * radio_roca, pz + dir.y * radio_roca)
				)
			var posicion := Vector3(px, suelo_min + 0.1 * escala.y, pz)

			var mezcla := clampf(h / 40.0 + azar.randf_range(-0.2, 0.2), 0.0, 1.0)
			var tinte := Color(0.80, 0.58, 0.40).lerp(Color(0.60, 0.32, 0.20), mezcla)
			var brillo := azar.randf_range(0.9, 1.2)
			tinte = Color(tinte.r * brillo, tinte.g * brillo, tinte.b * brillo)
			if textura_roca_albedo != null:
				# La textura oscurece al multiplicar; se compensa aclarando el tinte.
				tinte = tinte.lerp(Color.WHITE, 0.3)
				tinte = Color(tinte.r * 1.25, tinte.g * 1.25, tinte.b * 1.25)

			var variante := azar.randi() % variantes
			transformaciones[variante].append(Transform3D(base, posicion))
			colores[variante].append(tinte)
			total += 1

	for v in range(variantes):
		var lista: Array = transformaciones[v]
		if lista.is_empty():
			continue

		var multimalla := MultiMesh.new()
		multimalla.transform_format = MultiMesh.TRANSFORM_3D
		multimalla.use_colors = true
		multimalla.mesh = _malla_roca(semilla + 100 + v)
		multimalla.instance_count = lista.size()
		for k in range(lista.size()):
			multimalla.set_instance_transform(k, lista[k])
			multimalla.set_instance_color(k, colores[v][k])

		var nodo := MultiMeshInstance3D.new()
		nodo.name = "RocasSierra_%d" % v
		nodo.multimesh = multimalla
		nodo.material_override = material
		padre.add_child(nodo)

	print("Rocas en las sierras: ", total)


func _material_rocas() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color.WHITE
	m.roughness = 0.95
	if textura_roca_albedo != null:
		m.albedo_texture = textura_roca_albedo
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * escala_textura_roca
	if textura_roca_normal != null:
		m.normal_enabled = true
		m.normal_texture = textura_roca_normal
	return m


# Peñasco low-poly: esfera achatada con radios irregulares, caras planas.
func _malla_roca(semilla_roca: int) -> ArrayMesh:
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla_roca

	var anillos := 7
	var segmentos := 11
	var achatado := azar.randf_range(0.6, 0.9)
	var radio_polo_alto := azar.randf_range(0.75, 0.95)
	var radio_polo_bajo := azar.randf_range(0.75, 0.95)
	var fase_a := azar.randf() * TAU
	var fase_b := azar.randf() * TAU
	var rejilla: Array = []

	for i in range(anillos + 1):
		var fila: Array = []
		var phi := PI * float(i) / float(anillos)
		for j in range(segmentos):
			var theta := TAU * float(j) / float(segmentos)
			# Forma general ondulada + irregularidad por vértice.
			var radio := (
				1.0
				+ 0.16 * sin(theta * 2.0 + fase_a + phi * 1.5)
				+ 0.10 * sin(theta * 3.0 + fase_b - phi * 2.0)
				+ azar.randf_range(-0.12, 0.12)
			)
			if i == 0:
				radio = radio_polo_alto
			elif i == anillos:
				radio = radio_polo_bajo
			fila.append(Vector3(
				sin(phi) * cos(theta),
				cos(phi) * achatado,
				sin(phi) * sin(theta)
			) * radio)
		rejilla.append(fila)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(anillos):
		for j in range(segmentos):
			var k := (j + 1) % segmentos
			var a: Vector3 = rejilla[i][j]
			var b: Vector3 = rejilla[i][k]
			var c: Vector3 = rejilla[i + 1][k]
			var d: Vector3 = rejilla[i + 1][j]
			_cara_roca(st, a, b, c)
			_cara_roca(st, a, c, d)

	# Normales suavizadas: la roca se ve redondeada y natural, no facetada.
	st.generate_normals()
	return st.commit()


func _cara_roca(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var cruz := (b - a).cross(c - a)
	if cruz.length_squared() < 0.000001:
		return

	# Godot dibuja de frente las caras en sentido horario vistas desde fuera,
	# o sea, el producto cruz debe apuntar hacia dentro.
	if cruz.dot((a + b + c) / 3.0) > 0.0:
		var tmp := b
		b = c
		c = tmp

	for p in [a, b, c]:
		st.add_vertex(p)


# CORDILLERA LEJANA (capas de siluetas detrás de las sierras)

func _tono(color: Color, factor: float) -> Color:
	return Color(color.r * factor, color.g * factor, color.b * factor, 1.0)


func _vertice_color(st: SurfaceTool, punto: Vector3, color: Color) -> void:
	st.set_color(color)
	st.add_vertex(punto)


# Arcos de montañas sin colisión que rodean el valle por el oeste, norte y sur.
# Cada capa es más alta y más clara que la anterior; la niebla hace el resto.
func _crear_cordillera_lejana() -> void:
	if not generar_cordillera or not generar_montanas_v25:
		return

	var padre := _capa("Environment")
	var fondo := 145.0 + longitud_camino_llegada + fondo_escenico
	var alcance := maxf(semiancho_valle_v25 * 1.7, 330.0)
	var centro := Vector2(-200.0, 0.0)
	var haze := Color(0.80, 0.68, 0.56)
	var color_roca := Color(0.58, 0.31, 0.20)
	var muestras := 220

	# Perfil de cada cresta: base, falda, cima, falda, base.
	var perfil: Array[float] = [-0.5, -0.25, 0.0, 0.25, 0.5]
	var relativa: Array[float] = [0.0, 0.45, 1.0, 0.45, 0.0]
	var tonos: Array[float] = [0.72, 0.95, 1.15, 0.95, 0.72]

	for capa in range(capas_cordillera):
		var k := float(capa)
		var semi_x := fondo + 240.0 * k
		var semi_z := alcance + 130.0 + 190.0 * k
		var profundidad := 240.0 + 70.0 * k
		var theta_min := acos(clampf((60.0 - centro.x) / semi_x, 0.0, 0.95))
		var theta_max := TAU - theta_min
		var base_color := color_roca.lerp(haze, 0.30 + 0.22 * k)

		var rejilla: Array = []
		for i in range(muestras + 1):
			var t := float(i) / float(muestras)
			var theta := lerpf(theta_min, theta_max, t)
			var c := cos(theta)
			var s := sin(theta)
			var punto := centro + Vector2(c * semi_x, s * semi_z)
			var hacia_fuera := Vector2(c / semi_x, s / semi_z).normalized()

			var cresta_n := _cresta(float(i) * 0.05 + k * 13.0, k * 3.7 + 0.5, 4) / 0.875
			var altura := altura_cordillera * (1.0 + 0.3 * k) * (0.4 + 0.8 * cresta_n)
			altura *= smoothstep(0.0, 0.1, t) * (1.0 - smoothstep(0.9, 1.0, t))

			var fila: Array = []
			for r in range(5):
				var p2: Vector2 = punto + hacia_fuera * perfil[r] * profundidad
				var y := -12.0
				if r > 0 and r < 4:
					y = altura * relativa[r]
				fila.append(Vector3(p2.x, y, p2.y))
			rejilla.append(fila)

		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(muestras):
			for r in range(4):
				var a: Vector3 = rejilla[i][r]
				var b: Vector3 = rejilla[i + 1][r]
				var c2: Vector3 = rejilla[i + 1][r + 1]
				var d: Vector3 = rejilla[i][r + 1]
				var col_abajo := _tono(base_color, tonos[r])
				var col_arriba := _tono(base_color, tonos[r + 1])

				_vertice_color(st, a, col_abajo)
				_vertice_color(st, b, col_abajo)
				_vertice_color(st, c2, col_arriba)
				_vertice_color(st, a, col_abajo)
				_vertice_color(st, c2, col_arriba)
				_vertice_color(st, d, col_arriba)

		st.generate_normals()

		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 1.0
		material.cull_mode = BaseMaterial3D.CULL_DISABLED

		var nodo := MeshInstance3D.new()
		nodo.name = "Cordillera_%d" % capa
		nodo.mesh = st.commit()
		nodo.material_override = material
		nodo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		padre.add_child(nodo)


# LUZ Y AMBIENTE

func _ajustar_luz_y_ambiente() -> void:
	if not ajustar_luz_y_ambiente:
		return

	var escena := get_parent()
	if escena == null:
		return

	# Sol bajo y lateral: sombras largas que revelan barrancos y crestas.
	var luces := escena.find_children("*", "DirectionalLight3D", true, false)
	if not luces.is_empty():
		var sol := luces[0] as DirectionalLight3D
		sol.rotation_degrees = Vector3(-elevacion_sol, azimut_sol, 0.0)
		sol.light_color = Color(1.0, 0.86, 0.68)
		sol.light_energy = energia_sol
		sol.shadow_enabled = true
		sol.directional_shadow_max_distance = 900.0
		sol.directional_shadow_blend_splits = true

	var mundo := escena.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if mundo != null and mundo.environment != null:
		var amb := mundo.environment
		amb.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		amb.ssao_enabled = true
		amb.ssao_radius = 6.0
		amb.ssao_intensity = 2.0
		amb.glow_enabled = true
		amb.glow_intensity = 0.35
		amb.glow_hdr_threshold = 1.1
		amb.adjustment_enabled = true
		amb.adjustment_contrast = 1.08
		amb.adjustment_saturation = 1.1

		# Niebla de calima: aclara y enfría lo lejano, da profundidad a las sierras.
		amb.fog_enabled = activar_niebla
		if activar_niebla:
			amb.fog_light_color = Color(0.86, 0.80, 0.70)
			amb.fog_light_energy = 1.0
			amb.fog_sun_scatter = 0.2
			amb.fog_density = densidad_niebla
			amb.fog_aerial_perspective = perspectiva_aerea
			amb.fog_sky_affect = 0.25


func _preparar_cielo_costero() -> void:
	var mundo := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if mundo == null:
		return

	var anterior := mundo.environment
	if anterior != null and anterior.background_mode == Environment.BG_SKY:
		return

	var ambiente := Environment.new()
	if anterior != null:
		ambiente = anterior.duplicate() as Environment

	var colores := ProceduralSkyMaterial.new()
	colores.sky_top_color = Color("#6996b6")
	colores.sky_horizon_color = Color("#edd7b5")
	colores.ground_horizon_color = colores.sky_horizon_color
	colores.ground_bottom_color = Color("#927757")

	var cielo := Sky.new()
	cielo.sky_material = colores
	ambiente.sky = cielo
	ambiente.background_mode = Environment.BG_SKY
	mundo.environment = ambiente


# COLINA DEL CASTILLO

func _crear_colina_castillo() -> void:
	var padre := _capa("Castle")
	var radios := [42.0, 36.0, 29.0, 24.0, 21.0]
	var alturas := [
		0.0, altura_castillo * 0.18, altura_castillo * 0.62,
		altura_castillo * 0.93, altura_castillo
	]
	var lados := 40
	var anillos: Array[PackedVector3Array] = []

	for nivel in range(radios.size()):
		var anillo := PackedVector3Array()

		for i in range(lados):
			var angulo := (float(i) / float(lados)) * TAU
			var irregularidad := (
				1.0 + sin(angulo * 3.0 + 0.4) * 0.055 + sin(angulo * 7.0) * 0.035
			)
			var radio: float = radios[nivel]
			if nivel < radios.size() - 1:
				radio *= irregularidad

			var y: float = alturas[nivel]
			if nivel > 0 and nivel < 4:
				y += sin(angulo * 5.0 + float(nivel))

			anillo.append(Vector3(
				CENTRO_CASTILLO.x + cos(angulo) * radio,
				y,
				CENTRO_CASTILLO.y + sin(angulo) * radio
			))
		anillos.append(anillo)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for nivel in range(anillos.size() - 1):
		var exterior: PackedVector3Array = anillos[nivel]
		var interior: PackedVector3Array = anillos[nivel + 1]
		for i in range(lados):
			var siguiente := (i + 1) % lados
			var a: Vector3 = exterior[i]
			var b: Vector3 = exterior[siguiente]
			var c: Vector3 = interior[siguiente]
			var d: Vector3 = interior[i]
			_triangulo(st, a, b, c)
			_triangulo(st, a, c, d)

	var borde: PackedVector3Array = anillos[anillos.size() - 1]
	var centro := Vector3(CENTRO_CASTILLO.x, altura_castillo, CENTRO_CASTILLO.y)

	for i in range(lados):
		var siguiente := (i + 1) % lados
		_triangulo(st, centro, borde[i], borde[siguiente])

	st.generate_normals()
	_agregar_malla(padre, "MontanaDelCastillo", st.commit(), _roca, true)


# CAMINOS Y RAMPA

func _crear_caminos() -> void:
	var entorno := _capa("Environment")

	_segmento(
		entorno, "CaminoDelDesierto",
		Vector2(-145.0 - longitud_camino_llegada, 8), Vector2(-145, 8),
		10.0, 0.15, _camino, -0.08, false
	)
	_segmento(
		entorno, "AvenidaPrincipal", Vector2(-145, 8), CENTRO_PLAZA,
		9.0, 0.15, _camino, -0.08, false
	)
	_segmento(
		entorno, "CaminoAlPuerto", CENTRO_PLAZA, Vector2(72, 28),
		7.0, 0.15, _camino, -0.08, false
	)

	var puntos := [
		Vector3(-45, 0.3, -10),
		Vector3(-39, altura_castillo * 0.24, -42),
		Vector3(-35, altura_castillo * 0.52, -78),
		Vector3(-62, altura_castillo * 0.80, -94),
		Vector3(-73, altura_castillo + 0.3, -63)
	]
	for i in range(puntos.size() - 1):
		_bloque_entre(
			entorno, "RampaCastillo_%02d" % i,
			puntos[i], puntos[i + 1], 6.0, 0.65, _piedra, true
		)


# MURALLAS Y CASTILLO
# El generador de ciudad ampliada redefine _crear_murallas().

func _crear_murallas() -> void:
	var padre := _capa("Walls")
	var tramos := [
		[Vector2(-146, -100), Vector2(-146, -5)],
		[Vector2(-146, 21), Vector2(-146, 100)],
		[Vector2(-146, -100), Vector2(-60, -115)],
		[Vector2(-146, 100), Vector2(48, 108)],
		[Vector2(48, 108), Vector2(82, 91)]
	]

	var altura_muro := 9.0
	var grosor := 3.5
	var almenas: Array[Transform3D] = []
	var torres: Array[Dictionary] = []

	# Torres de la puerta primero, para que las demás las respeten.
	var puerta: Array[Vector2] = [Vector2(-146.0, -9.5), Vector2(-146.0, 25.5)]
	for p in puerta:
		torres.append({"pos": p, "yaw": 0.0, "lado": 9.0, "alto": 16.0})

	for i in range(tramos.size()):
		var a: Vector2 = tramos[i][0]
		var b: Vector2 = tramos[i][1]
		var yaw := atan2(b.x - a.x, b.y - a.y)

		# Zócalo más ancho en la base y muro con cimiento enterrado.
		_segmento(
			padre, "ZocaloMuralla_%02d" % i, a, b,
			grosor + 1.2, 3.0, _muro, -1.0, false
		)
		_segmento(
			padre, "Muralla_%02d" % i, a, b,
			grosor, altura_muro + 3.0, _muro, -3.0
		)

		# Almenas en ambos bordes del adarve.
		_agregar_almenas(almenas, a, b, altura_muro + 0.8, grosor * 0.5 - 0.5, 2.8)
		_agregar_almenas(almenas, a, b, altura_muro + 0.8, -(grosor * 0.5 - 0.5), 2.8)

		# Una torre cada ~42 m, sin pisar las de la puerta ni las ya puestas.
		var n := maxi(1, ceili(a.distance_to(b) / 42.0))
		for k in range(n + 1):
			var punto := a.lerp(b, float(k) / float(n))
			var libre := true
			for t in torres:
				var otra: Vector2 = t["pos"]
				if punto.distance_to(otra) < 14.0:
					libre = false
					break
			if libre:
				torres.append({"pos": punto, "yaw": yaw, "lado": 7.0, "alto": 14.0})

	for i in range(torres.size()):
		var t: Dictionary = torres[i]
		var pos: Vector2 = t["pos"]
		var lado: float = t["lado"]
		var alto: float = t["alto"]
		var yaw: float = t["yaw"]

		var torre := _caja(
			padre, "TorreMuralla_%02d" % i,
			Vector3(pos.x, (alto - 3.0) * 0.5, pos.y),
			Vector3(lado, alto + 3.0, lado), _muro
		)
		torre.rotation.y = yaw

		# Almenas en los cuatro bordes de la terraza de la torre.
		var h := lado * 0.5 - 0.5
		var esquinas: Array[Vector2] = []
		for signo in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			esquinas.append(pos + _girar(Vector2(signo.x * h, signo.y * h), yaw))
		for j in range(4):
			_agregar_almenas(almenas, esquinas[j], esquinas[(j + 1) % 4], alto + 0.8, 0.0, 2.4)

	# Dintel de la puerta entre las dos torres, con almenas.
	_segmento(
		padre, "DintelPuerta", Vector2(-146, -5), Vector2(-146, 21),
		4.0, 3.0, _muro, 10.0
	)
	_agregar_almenas(almenas, Vector2(-146, -5), Vector2(-146, 21), 13.8, 1.5, 2.8)
	_agregar_almenas(almenas, Vector2(-146, -5), Vector2(-146, 21), 13.8, -1.5, 2.8)

	_crear_almenas(padre, almenas)


func _girar(v: Vector2, yaw: float) -> Vector2:
	return Vector2(
		v.x * cos(yaw) + v.y * sin(yaw),
		-v.x * sin(yaw) + v.y * cos(yaw)
	)


# Coloca almenas repartidas a lo largo de a -> b, desplazadas hacia un lado.
func _agregar_almenas(
	lista: Array[Transform3D],
	a: Vector2,
	b: Vector2,
	y: float,
	desplazamiento: float,
	paso: float
) -> void:
	var d := b - a
	var largo := d.length()
	if largo < 1.0:
		return

	var u := d / largo
	var perpendicular := Vector2(-u.y, u.x)
	var yaw := atan2(u.x, u.y)
	var cantidad := maxi(1, int(largo / paso))

	for k in range(cantidad):
		var t := (float(k) + 0.5) / float(cantidad)
		var p := a + u * largo * t + perpendicular * desplazamiento
		lista.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y, p.y)))


# Todas las almenas en un solo MultiMesh (una sola llamada de dibujo).
func _crear_almenas(padre: Node3D, lista: Array[Transform3D]) -> void:
	if lista.is_empty():
		return

	var malla := BoxMesh.new()
	malla.size = Vector3(1.6, 2.6, 2.2)

	var multimalla := MultiMesh.new()
	multimalla.transform_format = MultiMesh.TRANSFORM_3D
	multimalla.mesh = malla
	multimalla.instance_count = lista.size()
	for i in range(lista.size()):
		multimalla.set_instance_transform(i, lista[i])

	var nodo := MultiMeshInstance3D.new()
	nodo.name = "Almenas"
	nodo.multimesh = multimalla
	nodo.material_override = _muro
	padre.add_child(nodo)


func _crear_castillo() -> void:
	var padre := _capa("Castle")
	var cx := CENTRO_CASTILLO.x
	var cz := CENTRO_CASTILLO.y
	var y := altura_castillo

	_caja(padre, "PatioSuperior", Vector3(cx, y + 0.3, cz), Vector3(32, 0.6, 26), _piedra)
	_caja(padre, "FortalezaPrincipal", Vector3(cx - 5, y + 10.5, cz), Vector3(15, 20, 13), _piedra)
	_caja(padre, "TorreDelHomenaje", Vector3(cx - 5, y + 24, cz), Vector3(9, 11, 9), _piedra_oscura)

	for dx in [-16.0, 16.0]:
		for dz in [-13.0, 13.0]:
			_torre(padre, "TorreEsquina", Vector3(cx + dx, y + 7, cz + dz), 3.5, 14.0, _piedra)

	var a := Vector2(cx - 16, cz - 13)
	var b := Vector2(cx + 16, cz - 13)
	var c := Vector2(cx + 16, cz + 13)
	var d := Vector2(cx - 16, cz + 13)

	_segmento(padre, "MuroNorte", a, b, 2.5, 8.0, _piedra, y)
	_segmento(padre, "MuroSur", d, c, 2.5, 8.0, _piedra, y)
	_segmento(padre, "MuroOeste", a, d, 2.5, 8.0, _piedra, y)
	_segmento(padre, "MuroEsteNorte", b, Vector2(cx + 16, cz - 5), 2.5, 8.0, _piedra, y)
	_segmento(padre, "MuroEsteSur", Vector2(cx + 16, cz + 5), c, 2.5, 8.0, _piedra, y)

	for i in range(9):
		var px := cx - 15 + float(i) * 3.7
		_caja(
			padre, "Almena_%02d" % i, Vector3(px, y + 8.8, cz - 13),
			Vector3(1.8, 1.6, 2.7), _piedra, false
		)


# PLAZA DE MERCADERES

func _crear_plaza() -> void:
	var padre := _capa("Market")

	_caja(
		padre, "SueloPlaza", Vector3(CENTRO_PLAZA.x, 0.05, CENTRO_PLAZA.y),
		Vector3(48, 0.12, 38), _piedra, false
	)
	_torre(padre, "MonumentoPlaza", Vector3(-8, 1.5, 8), 1.3, 3.0, _piedra_oscura)

	var puestos := [
		Vector2(-27, -7), Vector2(-14, -7), Vector2(0, -7), Vector2(13, -7),
		Vector2(-27, 23), Vector2(-14, 23), Vector2(0, 23), Vector2(13, 23)
	]

	for i in range(puestos.size()):
		var p: Vector2 = puestos[i]
		var tela: Material = _tela_roja
		if i % 3 == 1:
			tela = _tela_ocre
		elif i % 3 == 2:
			tela = _tela_azul

		_caja(
			padre, "Mostrador_%02d" % i, Vector3(p.x, 0.65, p.y),
			Vector3(4.2, 1.3, 2.8), _madera, false
		)
		_caja(
			padre, "Toldo_%02d" % i, Vector3(p.x, 3.1, p.y),
			Vector3(5.2, 0.15, 3.9), tela, false
		)

		for dx in [-2.3, 2.3]:
			for dz in [-1.7, 1.7]:
				_caja(
					padre, "PosteMercado", Vector3(p.x + dx, 1.55, p.y + dz),
					Vector3(0.14, 3.1, 0.14), _madera, false
				)


# PUERTO, PASEO COSTERO Y ROMPEOLAS

func _punto_curva(a: Vector2, control: Vector2, b: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * u * u + control * 2.0 * u * t + b * t * t


func _extremo_paseo(lado: float) -> float:
	var z := 0.0
	for paso in range(300):
		var siguiente := z + lado
		var x := _costa(siguiente) + 5.0
		if absf(siguiente) + 20.0 >= absf(_eje_sierra(x, lado)):
			break
		z = siguiente
	return z


func _cara_puerto(
	st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3
) -> void:
	st.set_smooth_group(-1)
	_triangulo(st, a, b, c)
	_triangulo(st, a, c, d)


func _ala_puerto(
	padre: Node3D,
	material: Material,
	lado: float,
	borde: Vector3,
	semiancho: float,
	piso: float
) -> void:
	var sur := lado > 0.0
	var nombre := "Sur" if sur else "Norte"
	var extremo := _extremo_paseo(lado)
	var tramos := maxi(1, ceili(absf(extremo - borde.z) / 8.0))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var anterior := borde
	var ancho_anterior := semiancho
	var amarres := [roundi(tramos * 0.35), roundi(tramos * 0.74)]

	for i in range(1, tramos + 1):
		var z := lerpf(borde.z, extremo, float(i) / tramos)
		var mezcla := smoothstep(0.0, 24.0, absf(z - borde.z))
		var centro := Vector3(lerpf(borde.x, _costa(z) + 5.0, mezcla), piso, z)
		var ancho := lerpf(semiancho, 5.5, mezcla)

		var a := anterior - Vector3.RIGHT * ancho_anterior
		var b := anterior + Vector3.RIGHT * ancho_anterior
		var c := centro + Vector3.RIGHT * ancho
		var d := centro - Vector3.RIGHT * ancho

		if not sur:
			var tmp := a
			a = b
			b = tmp
			tmp = c
			c = d
			d = tmp

		var espesor := Vector3.DOWN * 0.48
		_cara_puerto(st, a, b, c, d)
		_cara_puerto(st, b, b + espesor, c + espesor, c)
		_cara_puerto(st, d, d + espesor, a + espesor, a)

		if i == tramos:
			_cara_puerto(st, c, c + espesor, d + espesor, d)

		if i % 3 == 0:
			_caja(
				padre, "Pilote" + nombre + str(i),
				centro + Vector3(ancho - 0.7, -5.0, 0),
				Vector3(0.8, 10.0, 0.8), _madera, false
			)

		if amarres.has(i):
			var raiz := Vector2(centro.x + ancho - 1.0, z)
			var largo := 36.0 if i == amarres[0] else 48.0
			_segmento(
				padre, "Embarcadero" + nombre + str(i),
				raiz, raiz + Vector2(largo, 0), 6.5, 0.5, material, piso - 0.52
			)

		anterior = centro
		ancho_anterior = ancho

	st.generate_normals()
	st.generate_tangents()
	_agregar_malla(padre, "Paseo" + nombre, st.commit(), material, true)

	var inicio := Vector2(anterior.x, extremo)
	var boca := Vector2(244.0, 6.0 + lado * 36.0)
	var control := Vector2(boca.x + 22.0, extremo)
	var previo := inicio

	for i in range(1, 25):
		var punto := _punto_curva(inicio, control, boca, float(i) / 24.0)
		var junta := (punto - previo).normalized() * 0.35
		_segmento(
			padre, "Rompeolas" + nombre + str(i),
			previo - junta, punto + junta, 7.0, 11.0, _piedra, piso - 11.02
		)
		previo = punto

	var pie := Vector3(boca.x, piso, boca.y)
	_torre(padre, "BaseFaro" + nombre, pie + Vector3.DOWN * 5.45, 8.0, 11.0, _piedra_oscura)
	_torre(padre, "Faro" + nombre, pie + Vector3.UP * 8.0, 3.7, 16.0, _piedra)
	_torre(padre, "Cornisa" + nombre, pie + Vector3.UP * 16.0, 4.35, 0.7, _piedra_oscura)
	_torre(padre, "Linterna" + nombre, pie + Vector3.UP * 17.7, 2.3, 3.0, _tela_ocre)
	_torre(padre, "TechoFaro" + nombre, pie + Vector3.UP * 19.4, 3.15, 0.6, _piedra_oscura)


func _crear_puerto() -> void:
	var padre := _capa("Docks")
	var muelle := ESCENA_MUELLE.instantiate() as Node3D
	muelle.position = Vector3(72, 0, 28)

	if not generar_colisiones:
		for forma in muelle.find_children("*", "CollisionShape3D", true, false):
			(forma as CollisionShape3D).disabled = true

	padre.add_child(muelle)

	var cubierta := muelle.get_node("Paseo/Cubierta") as MeshInstance3D
	var caja := cubierta.mesh as BoxMesh
	var material := cubierta.get_active_material(0)
	var centro := padre.to_local(cubierta.global_position)
	var piso := centro.y + caja.size.y * 0.5

	for lado: float in [-1.0, 1.0]:
		var borde := Vector3(centro.x, piso, centro.z + lado * caja.size.z * 0.5)
		_ala_puerto(padre, material, lado, borde, caja.size.x * 0.5, piso)

	for i in range(3):
		var z := -51.0 + float(i) * 16.0
		_caja(
			padre, "BodegaPuerto_%d" % i, Vector3(57, 3.5, z),
			Vector3(10, 7, 11), _madera
		)

	_crear_barco(padre, 0, Vector2(151, 9))
	_crear_barco(padre, 1, Vector2(153, 37))
	_crear_barco(padre, 2, Vector2(155, -34))


func _crear_barco(padre: Node3D, numero: int, posicion: Vector2) -> void:
	var x := posicion.x
	var z := posicion.y

	_caja(
		padre, "CascoBarco_%d" % numero, Vector3(x, -2.0, z),
		Vector3(4.0, 1.5, 11.0), _madera, false
	)
	_caja(
		padre, "Mastil_%d" % numero, Vector3(x, 2.0, z),
		Vector3(0.25, 8.0, 0.25), _madera, false
	)
	_caja(
		padre, "Vela_%d" % numero, Vector3(x, 2.7, z),
		Vector3(4.2, 4.2, 0.12), _tela_ocre, false
	)


# TECHOS Y CASAS

func _crear_techo(
	padre: Node3D,
	nombre: String,
	posicion: Vector3,
	ancho: float,
	largo: float,
	elevacion: float
) -> void:
	var w := ancho * 0.5 + 0.4
	var d := largo * 0.5 + 0.4
	var lf := Vector3(-w, 0, -d)
	var lb := Vector3(-w, 0, d)
	var rf := Vector3(w, 0, -d)
	var rb := Vector3(w, 0, d)
	var cf := Vector3(0, elevacion, -d)
	var cb := Vector3(0, elevacion, d)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_triangulo(st, lf, lb, cb)
	_triangulo(st, lf, cb, cf)
	_triangulo(st, rf, cf, cb)
	_triangulo(st, rf, cb, rb)
	_triangulo(st, lf, cf, rf)
	_triangulo(st, lb, rb, cb)
	st.generate_normals()

	var techo := MeshInstance3D.new()
	techo.name = nombre
	techo.mesh = st.commit()
	techo.position = posicion
	techo.material_override = _teja
	padre.add_child(techo)


func _crear_casa(numero: int, posicion: Vector2) -> void:
	var barrio := _capa("Buildings")
	var casa := Node3D.new()
	casa.name = "Casa_%03d" % numero
	casa.position = Vector3(posicion.x, 0, posicion.y)
	casa.rotation.y = float(_rng.randi_range(-1, 1)) * 0.12
	barrio.add_child(casa)

	var ancho := _rng.randf_range(9.0, 11.5)
	var largo := _rng.randf_range(9.0, 12.0)
	var alto := _rng.randf_range(5.5, 8.0)

	_caja(
		casa, "Cuerpo", Vector3(0, alto * 0.5, 0),
		Vector3(ancho, alto, largo), _piedra
	)
	_crear_techo(
		casa, "Tejado", Vector3(0, alto, 0),
		ancho, largo, _rng.randf_range(2.0, 3.2)
	)
	_caja(
		casa, "Puerta", Vector3(0, 1.4, largo * 0.5 + 0.09),
		Vector3(1.7, 2.8, 0.14), _madera, false
	)

	for dx in [-ancho * 0.27, ancho * 0.27]:
		_caja(
			casa, "Ventana", Vector3(dx, alto * 0.58, largo * 0.5 + 0.10),
			Vector3(1.1, 1.2, 0.12), _piedra_oscura, false
		)


# DISTRIBUCIÓN RESIDENCIAL DE LA BASE

func _distancia_segmento(p: Vector2, a: Vector2, b: Vector2) -> float:
	var d := b - a
	if d.length_squared() < 0.001:
		return p.distance_to(a)

	var t := clampf((p - a).dot(d) / d.length_squared(), 0.0, 1.0)
	return p.distance_to(a + d * t)


func _habitacion_xz() -> Vector2:
	var habitacion := get_parent().get_node_or_null("RecoveryRoom") as Node3D
	if habitacion != null:
		return Vector2(habitacion.position.x, habitacion.position.z)
	return Vector2(-43, 36)


func _lote_valido(p: Vector2) -> bool:
	for dx in [-7.0, 7.0]:
		for dz in [-7.0, 7.0]:
			if not Geometry2D.is_point_in_polygon(p + Vector2(dx, dz), _tierra):
				return false

	if p.distance_to(CENTRO_CASTILLO) < 47.0:
		return false

	if absf(p.x - CENTRO_PLAZA.x) < 34.0 and absf(p.y - CENTRO_PLAZA.y) < 29.0:
		return false

	if p.distance_to(_habitacion_xz()) < 21.0:
		return false

	if p.x < -25.0 and absf(p.y - 8.0) < 13.0:
		return false

	if _distancia_segmento(p, CENTRO_PLAZA, Vector2(72, 28)) < 12.0:
		return false

	var rampa := [
		Vector2(-45, -10), Vector2(-39, -42), Vector2(-35, -78),
		Vector2(-62, -94), Vector2(-73, -63)
	]

	for i in range(rampa.size() - 1):
		if _distancia_segmento(p, rampa[i], rampa[i + 1]) < 12.0:
			return false

	return true


func _crear_barrio() -> void:
	var lotes: Array[Vector2] = []

	for ix in range(13):
		for iz in range(12):
			var p := Vector2(
				-116.0 + float(ix) * 16.0,
				-96.0 + float(iz) * 18.0
			)
			if _lote_valido(p):
				lotes.append(p)

	for i in range(lotes.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var temporal := lotes[i]
		lotes[i] = lotes[j]
		lotes[j] = temporal

	var cantidad := mini(cantidad_casas, lotes.size())
	for i in range(cantidad):
		_crear_casa(i, lotes[i])

	print("Casas generadas: ", cantidad)


# ROCAS DECORATIVAS

func _decorar_rocas() -> void:
	var padre := _capa("Props")

	for i in range(42):
		var angulo := _rng.randf() * TAU
		var radio := _rng.randf_range(34.0, 48.0)
		var x := CENTRO_CASTILLO.x + cos(angulo) * radio
		var z := CENTRO_CASTILLO.y + sin(angulo) * radio

		var roca := MeshInstance3D.new()
		roca.name = "Roca_%02d" % i

		var malla := SphereMesh.new()
		malla.radius = 1.0
		malla.height = 2.0
		malla.radial_segments = 7
		malla.rings = 4

		roca.mesh = malla
		roca.position = Vector3(x, 0.4, z)
		roca.scale = Vector3(
			_rng.randf_range(2.0, 4.0),
			_rng.randf_range(1.0, 3.0),
			_rng.randf_range(2.0, 4.0)
		)
		roca.rotation.y = _rng.randf() * TAU
		roca.material_override = _roca
		padre.add_child(roca)
