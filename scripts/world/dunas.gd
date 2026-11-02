@tool
extends StaticBody3D
## Terreno de dunas generado con ruido, con colisión incluida.
## Se ve también en el editor, así puedes colocar objetos sobre él.
## Al cambiar cualquier valor del Inspector el terreno se regenera solo.
## El centro (donde aparece el jugador) es una zona plana a altura y = 0.
##
## Si en la escena hay una "GrietaDesierto" (ver grieta_desierto.gd), el terreno se talla
## con la forma de la grieta: ella le dice a cada punto cuánto bajar. Sin grieta, todo
## funciona igual que antes.

const GRUPO_TERRENO := &"terreno_dunas"
const GRUPO_GRIETA := &"grieta_desierto"
# Color de la arena cuando se pintan colores por vértice (el mismo de la arena lisa).
const COLOR_ARENA := Color(0.85, 0.7, 0.47)
# Texturas de arena: las mismas que usa la pantalla de título.
const RUTA_ARENA_COLOR := "res://assets/texturas/arena/Ground093A_1K-JPG_Color.jpg"
const RUTA_ARENA_NORMAL := "res://assets/texturas/arena/Ground093A_1K-JPG_NormalGL.jpg"
const RUTA_ARENA_ROUGH := "res://assets/texturas/arena/Ground093A_1K-JPG_Roughness.jpg"

# Texturas ya preparadas (con mipmaps), compartidas por todos los terrenos.
static var _texturas_cache: Dictionary = {}

@export_group("Tamaño")
## Lado del terreno cuadrado, en metros.
@export_range(50.0, 1000.0, 10.0) var tamano: float = 400.0:
	set(valor):
		tamano = valor
		_regenerar_pronto()
## Celdas por lado. Más celdas = dunas más suaves y paredes de la grieta más finas, pero más pesado.
@export_range(20, 600, 10) var celdas: int = 400:
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
## Material del terreno. Si lo dejas vacío se usa la arena con texturas (o, si apagas
## "Usar Texturas Arena", un color liso). Con grieta, las paredes de roca se pintan solas.
@export var material_arena: Material:
	set(valor):
		material_arena = valor
		_regenerar_pronto()
## Pone las texturas de arena de la pantalla de título al terreno cuando no hay material propio.
@export var usar_texturas_arena: bool = true:
	set(valor):
		usar_texturas_arena = valor
		_regenerar_pronto()
## Cuántas veces se repite la textura por metro. 0.5 = una repetición cada 2 metros
## (más alto = grano más fino; más bajo = grano más grande).
@export_range(0.05, 3.0, 0.05) var escala_textura: float = 0.5:
	set(valor):
		escala_textura = valor
		_regenerar_pronto()

var _ruido: FastNoiseLite
var _malla_nodo: MeshInstance3D
var _colision_nodo: CollisionShape3D
var _pendiente: bool = false
var _grieta: Node = null


func _ready() -> void:
	add_to_group(GRUPO_TERRENO)
	# Se genera un instante después de que todos los nodos estén listos: así la grieta
	# (si hay una en la escena) ya se registró y el terreno sale tallado de una sola vez.
	_generar.call_deferred()


func _regenerar_pronto() -> void:
	# Al abrir la escena los valores se aplican antes de que el nodo esté listo;
	# en ese caso _ready() ya se encarga de generar.
	if not is_node_ready() or _pendiente:
		return
	_pendiente = true
	_generar.call_deferred()


## Vuelve a generar el terreno (la grieta lo llama cuando cambia).
func regenerar_ahora() -> void:
	_regenerar_pronto()


## Dice si el terreno que hay ahora ya se talló con esta grieta.
func usa_esta_grieta(grieta: Node) -> bool:
	return _grieta == grieta


## Altura de las dunas en un punto, sin tallar la grieta (espacio local del terreno).
func altura_base(x: float, z: float) -> float:
	if _ruido == null:
		_configurar_ruido()
	return _altura_dunas(x, z)


func _generar() -> void:
	_pendiente = false
	if not is_inside_tree():
		return
	_asegurar_nodos()
	_configurar_ruido()

	# Una grieta es opcional: si existe, se prepara con la posición actual del terreno.
	_grieta = get_tree().get_first_node_in_group(GRUPO_GRIETA)
	if _grieta != null and not _grieta.has_method(&"altura_con_grieta"):
		_grieta = null
	if _grieta != null:
		_grieta.preparar(self)

	var n: int = celdas + 1
	var paso: float = tamano / float(celdas)
	var origen: float = -tamano * 0.5

	# 1) Altura de cada vértice de la cuadrícula.
	var alturas := PackedFloat32Array()
	alturas.resize(n * n)
	var bases := PackedFloat32Array()
	if _grieta != null:
		bases.resize(n * n)
	for i in range(n):
		for j in range(n):
			var x: float = origen + float(j) * paso
			var z: float = origen + float(i) * paso
			var base: float = _altura_dunas(x, z)
			if _grieta != null:
				bases[i * n + j] = base
				alturas[i * n + j] = _grieta.altura_con_grieta(x, z, base)
			else:
				alturas[i * n + j] = base

	# 2) Vértices, normales y coordenadas de textura.
	# Con texturas, el color del vértice solo "tiñe" la textura (blanco = arena sin cambios).
	var con_textura: bool = _usa_textura()
	var vertices := PackedVector3Array()
	var normales := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colores := PackedColorArray()
	vertices.resize(n * n)
	normales.resize(n * n)
	uvs.resize(n * n)
	if _grieta != null:
		colores.resize(n * n)
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
			if _grieta != null:
				# Roca en las paredes de la grieta, arena en el resto.
				var color: Color = _grieta.color_vertice(x, z, alturas[idx], bases[idx], normales[idx].y)
				colores[idx] = _como_tinte(color) if con_textura else color

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
	if _grieta != null:
		arrays[Mesh.ARRAY_COLOR] = colores
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


# Altura de las dunas, sin grieta.
func _altura_dunas(x: float, z: float) -> float:
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


# ¿Se va a usar la arena con texturas? (solo si no hay material propio y las texturas existen)
func _usa_textura() -> bool:
	return material_arena == null and usar_texturas_arena and ResourceLoader.exists(RUTA_ARENA_COLOR)


# Convierte un color de arena/roca en un tinte para la textura: la arena lisa pasa a blanco,
# la roca y el fondo oscuro de la grieta quedan más oscuros que la arena, en la misma proporción.
func _como_tinte(color: Color) -> Color:
	return Color(
			minf(color.r / COLOR_ARENA.r, 1.0),
			minf(color.g / COLOR_ARENA.g, 1.0),
			minf(color.b / COLOR_ARENA.b, 1.0),
			1.0)


# Arena con las texturas de la pantalla de título: color, relieve y brillo, repetidas sobre
# el mundo (triplanar) para que no se estiren en las paredes de la grieta.
func _material_con_texturas() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = _textura(RUTA_ARENA_COLOR, false)
	material.albedo_color = Color.WHITE
	material.roughness = 0.95
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * escala_textura
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if ResourceLoader.exists(RUTA_ARENA_NORMAL):
		material.normal_enabled = true
		material.normal_texture = _textura(RUTA_ARENA_NORMAL, true)
		material.normal_scale = 1.0
	if ResourceLoader.exists(RUTA_ARENA_ROUGH):
		material.roughness_texture = _textura(RUTA_ARENA_ROUGH, false)
	if _grieta != null:
		# El color de cada vértice oscurece la textura en las paredes de roca.
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
	return material


# Carga una textura y, si viene sin mipmaps, se los genera: sin ellos la arena lejana
# "brilla" y se ve con ruido al caminar. Se guarda para no repetir el trabajo.
func _textura(ruta: String, es_normal: bool) -> Texture2D:
	if _texturas_cache.has(ruta):
		return _texturas_cache[ruta]
	var original := load(ruta) as Texture2D
	var resultado: Texture2D = original
	if original != null:
		var imagen: Image = original.get_image()
		if imagen != null and not imagen.is_empty() and not imagen.is_compressed() and not imagen.has_mipmaps():
			imagen.generate_mipmaps(es_normal)
			resultado = ImageTexture.create_from_image(imagen)
	_texturas_cache[ruta] = resultado
	return resultado


func _obtener_material() -> Material:
	if material_arena != null:
		return material_arena
	if _usa_textura():
		return _material_con_texturas()
	var arena := StandardMaterial3D.new()
	arena.roughness = 1.0
	if _grieta != null:
		# Con grieta, el color viene de cada vértice (arena y roca).
		arena.albedo_color = Color.WHITE
		arena.vertex_color_use_as_albedo = true
		arena.vertex_color_is_srgb = true
	else:
		arena.albedo_color = COLOR_ARENA
	return arena
