@tool
extends StaticBody3D
## Terreno de dunas generado con ruido, con colisión incluida.
## Se ve también en el editor, así puedes colocar objetos sobre él.
## Al cambiar cualquier valor del Inspector el terreno se regenera solo.
## El centro (donde aparece el jugador) es una zona plana a altura y = 0.
##
## VALLE: con "Usar Valle" activo, el terreno forma un valle que avanza hacia -Z:
## el inicio queda en y = 0, baja suavemente a una hondonada, vuelve a subir al fondo,
## y a los lados hay paredes de arena que sirven de límite natural. El valle se ensancha
## en el centro y cada lado tiene su propio contorno, para que no se vea lineal.
## También coloca las ruinas del inicio (ver ruinas_inicio.gd).
##
## ARENA DE COMBATE: con "Con Arena" activo, el final del valle se aplana en una meseta, el
## valle se estrecha alrededor de un claro plano y una pared de dunas lo cierra por el fondo.
## Así hay un lugar para pelear y no se puede salir del mapa.
##
## Si en la escena hay una "GrietaDesierto" (ver grieta_desierto.gd), el terreno se talla
## con la forma de la grieta: ella le dice a cada punto cuánto bajar. Sin grieta, todo
## funciona igual que antes.

const GRUPO_TERRENO := &"terreno_dunas"
const GRUPO_GRIETA := &"grieta_desierto"
# Script que construye las ruinas del inicio (si no existe, simplemente no se crean).
const RUTA_RUINAS := "res://scripts/world/ruinas_inicio.gd"
# Script que construye sendero, postes, costillas, rocas, hierba y polvo.
const RUTA_PROPS := "res://scripts/world/props_recorrido.gd"
# Color de la arena cuando se pintan colores por vértice (el mismo de la arena lisa).
const COLOR_ARENA := Color(0.85, 0.7, 0.47)
# Texturas de arena: las mismas que usa la pantalla de título.
const RUTA_ARENA_COLOR := "res://assets/texturas/arena/Ground093A_1K-JPG_Color.jpg"
const RUTA_ARENA_NORMAL := "res://assets/texturas/arena/Ground093A_1K-JPG_NormalGL.jpg"
const RUTA_ARENA_ROUGH := "res://assets/texturas/arena/Ground093A_1K-JPG_Roughness.jpg"
# Metros que ocupa la subida de la pared que cierra el fondo (menos = más empinada).
const ANCHO_CIERRE := 16.0

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

@export_group("Valle")
## Activa la forma de valle (hondonada central y paredes laterales). Apagado = dunas libres como antes.
@export var usar_valle: bool = true:
	set(valor):
		usar_valle = valor
		_regenerar_pronto()
## Mitad del ancho del valle en sus extremos, en metros. Desde ahí empiezan las paredes.
@export_range(10.0, 80.0, 1.0) var semiancho_valle: float = 55.0:
	set(valor):
		semiancho_valle = valor
		_regenerar_pronto()
## Altura de las paredes laterales, en metros.
@export_range(2.0, 60.0, 0.5) var altura_pared: float = 18.0:
	set(valor):
		altura_pared = valor
		_regenerar_pronto()
## Metros que ocupa la subida de cada pared. Más = pendiente más suave y abierta.
@export_range(4.0, 60.0, 0.5) var ancho_pared: float = 24.0:
	set(valor):
		ancho_pared = valor
		_regenerar_pronto()
## Cuánto serpentea el centro del valle a lo largo del recorrido, en metros (0 = recto).
@export_range(0.0, 15.0, 0.5) var meandro: float = 6.0:
	set(valor):
		meandro = valor
		_regenerar_pronto()
## Cuánto baja la hondonada central respecto al punto de inicio, en metros.
@export_range(0.0, 20.0, 0.5) var profundidad_hondonada: float = 5.0:
	set(valor):
		profundidad_hondonada = valor
		_regenerar_pronto()
## Altura del muro de dunas que cierra el valle detrás del inicio (0 = sin muro, 1 = normal, 2 = el doble).
@export_range(0.0, 2.0, 0.1) var muro_trasero: float = 1.0:
	set(valor):
		muro_trasero = valor
		_regenerar_pronto()
## Cuánto vuelve a subir el terreno desde la hondonada hasta el fondo del valle, en metros.
@export_range(0.0, 20.0, 0.5) var subida_fondo: float = 4.0:
	set(valor):
		subida_fondo = valor
		_regenerar_pronto()
## Distancia desde el inicio (hacia -Z) hasta el punto más hondo.
@export_range(10.0, 150.0, 1.0) var distancia_hondonada: float = 40.0:
	set(valor):
		distancia_hondonada = valor
		_regenerar_pronto()
## Distancia desde el inicio (hacia -Z) hasta el fondo del valle, donde el terreno ya sube.
@export_range(20.0, 190.0, 1.0) var distancia_fondo: float = 80.0:
	set(valor):
		distancia_fondo = valor
		_regenerar_pronto()

## Cuánto se ensancha el valle en su zona central (la hondonada), en metros por lado.
@export_range(0.0, 60.0, 1.0) var ensanche_central: float = 20.0:
	set(valor):
		ensanche_central = valor
		_regenerar_pronto()
## Cuánto se ondula el borde de cada pared a lo largo del recorrido, en metros.
@export_range(0.0, 30.0, 1.0) var variacion_borde: float = 12.0:
	set(valor):
		variacion_borde = valor
		_regenerar_pronto()

@export_group("Arena de combate")
## Crea un claro plano para pelear al final del valle: aplana la subida, estrecha el valle
## alrededor del claro y cierra el fondo con una pared de dunas. Solo funciona con "Usar Valle".
@export var con_arena: bool = true:
	set(valor):
		con_arena = valor
		_regenerar_pronto()
## Distancia desde el inicio (hacia -Z) hasta el centro del claro plano.
## Debe quedar unos 12 m más allá de AVANCE_CADAVER en props_recorrido.gd.
@export_range(40.0, 190.0, 1.0) var distancia_arena: float = 124.0:
	set(valor):
		distancia_arena = valor
		_regenerar_pronto()
## Radio de la zona totalmente plana, en metros.
@export_range(8.0, 60.0, 1.0) var radio_arena: float = 20.0:
	set(valor):
		radio_arena = valor
		_regenerar_pronto()
## Metros que tarda el terreno en pasar del claro plano a las dunas que lo rodean.
@export_range(4.0, 60.0, 1.0) var transicion_arena: float = 16.0:
	set(valor):
		transicion_arena = valor
		_regenerar_pronto()
## Altura de la pared de dunas que cierra el fondo detrás del claro, en metros.
@export_range(5.0, 60.0, 1.0) var altura_cierre: float = 20.0:
	set(valor):
		altura_cierre = valor
		_regenerar_pronto()

@export_group("Ruinas")
## Crea las ruinas del inicio (plataforma, columnas, dintel, telas y escombros).
@export var con_ruinas: bool = true:
	set(valor):
		con_ruinas = valor
		_regenerar_pronto()
## Posición (X, Z) del centro de la plataforma, en el espacio del terreno. Debe quedar dentro de la zona plana.
@export var posicion_ruinas: Vector2 = Vector2(-6.0, -4.0):
	set(valor):
		posicion_ruinas = valor
		_regenerar_pronto()

## Crea el sendero de lajas, postes con telas, costillas óseas, rocas, hierba seca y polvo.
@export var con_props: bool = true:
	set(valor):
		con_props = valor
		_regenerar_pronto()

@export_group("Aspecto")
## Tinte cálido que se multiplica con la textura de arena (blanco = sin cambio).
@export var tinte_arena: Color = Color(1.0, 0.86, 0.66):
	set(valor):
		tinte_arena = valor
		_regenerar_pronto()
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
# Puntos (avance, altura) del perfil del valle y su pendiente en cada punto.
var _perfil_puntos: Array[Vector2] = []
var _perfil_pendientes: PackedFloat32Array = PackedFloat32Array()
# Altura a la que queda el claro plano de la arena de combate.
var _altura_arena: float = 0.0


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


## Altura del terreno en un punto, sin tallar la grieta (espacio local del terreno).
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

	_generar_ruinas()
	_generar_props()


# Altura final del terreno: el terreno original (dunas + valle) con el claro de combate encima.
func _altura_dunas(x: float, z: float) -> float:
	var h: float = _altura_original(x, z)
	if usar_valle and con_arena:
		h = _aplicar_arena(x, z, h)
	return h


# Centro del claro plano de la arena de combate, en el espacio del terreno.
func _centro_arena() -> Vector2:
	return Vector2(centro_valle(distancia_arena), -distancia_arena)


# Aplana el terreno alrededor del centro de la arena y lo mezcla poco a poco con las dunas.
func _aplicar_arena(x: float, z: float, h: float) -> float:
	var d: float = Vector2(x, z).distance_to(_centro_arena())
	var t: float = smoothstep(radio_arena, radio_arena + transicion_arena, d)
	if t >= 1.0:
		return h
	# Ondulaciones muy suaves para que la arena plana no se vea como un cristal.
	var ondas: float = _ruido.get_noise_2d(x / 5.0 + 40.0, z / 3.0 - 40.0) * rugosidad * 0.5
	return lerpf(_altura_arena + ondas, h, t)


# Pared de dunas que cierra el fondo del valle detrás de la arena.
func _cierre(avance: float) -> float:
	if not con_arena:
		return 0.0
	var inicio: float = distancia_arena + radio_arena + transicion_arena * 0.5
	return smoothstep(inicio, inicio + ANCHO_CIERRE, avance) * altura_cierre


# Altura del terreno sin la arena: dunas de ruido + (si está activo) la forma del valle.
func _altura_original(x: float, z: float) -> float:
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

	if not usar_valle:
		return (cresta * amplitud + ondas) * plano

	# --- Valle ---
	# "avance" = metros recorridos desde el inicio hacia -Z.
	var avance: float = -z
	# El centro del valle serpentea suavemente para que el recorrido no sea una línea recta.
	var centro_x: float = centro_valle(avance)
	var lado: float = 1.0 if x >= centro_x else -1.0
	var dx: float = absf(x - centro_x)
	var borde: float = borde_valle(avance, lado)
	# 0 = fondo del valle, 1 = pared completa.
	var pared: float = smoothstep(borde, borde + ancho_pared, dx)
	# La altura de la pared también varía a lo largo del recorrido (60 % a 100 %).
	var variacion_altura: float = 0.8 + 0.2 * _ruido.get_noise_2d(avance / 60.0 + 1300.0, 55.0 * lado)
	# En el suelo del valle las dunas son suaves (60 %); en las paredes llegan al 100 %.
	var dunas: float = (cresta * amplitud + ondas) * plano * lerpf(0.6, 1.0, pared)
	# Más allá de la pared el terreno sigue subiendo, así no se ve el borde del mapa.
	var exterior: float = maxf(dx - borde - ancho_pared, 0.0) * 0.5
	return dunas + _perfil_valle(avance) + pared * altura_pared * variacion_altura + exterior + _cierre(avance)


## X del centro del valle a una distancia "avance" del inicio (hacia -Z), en espacio local del terreno.
func centro_valle(avance: float) -> float:
	return meandro * sin(avance * 0.05)


## Distancia desde el centro del valle hasta donde empieza la pared (lado = -1 izquierda, 1 derecha).
func borde_valle(avance: float, lado: float) -> float:
	if _ruido == null:
		_configurar_ruido()
	# El valle se ensancha en el centro (forma de óvalo) y cada lado tiene su propio contorno.
	var ensanche: float = ensanche_central * sin(PI * clampf(avance / maxf(distancia_fondo, 1.0), 0.0, 1.0))
	var ondula: float = _ruido.get_noise_2d(avance / 70.0 + 500.0, 77.0 * lado) * variacion_borde \
			+ _ruido.get_noise_2d(avance / 25.0 + 900.0, 31.0 * lado) * variacion_borde * 0.4
	var borde: float = semiancho_valle + ensanche + ondula
	if usar_valle and con_arena:
		# Antes de la arena el valle se va estrechando, para que las paredes de arena rodeen el claro.
		var cierra: float = smoothstep(distancia_arena - radio_arena - transicion_arena - 25.0, distancia_arena - radio_arena, avance)
		var meta: float = radio_arena + transicion_arena * 0.5 + 6.0 + ondula * 0.3
		borde = lerpf(borde, minf(borde, meta), cierra)
	return borde


# Calcula los puntos del perfil del valle (altura según el avance) y sus pendientes.
func _preparar_valle() -> void:
	var fondo: float = maxf(distancia_fondo, distancia_hondonada + 5.0)
	var h_hondonada: float = -profundidad_hondonada
	var h_fondo: float = h_hondonada + subida_fondo
	_perfil_puntos = [
		# Muro trasero: detrás del inicio el terreno sube rápido (hasta ≈50° en el tramo medio).
		Vector2(-200.0, 70.0 * muro_trasero),
		Vector2(-80.0, 50.0 * muro_trasero),
		Vector2(-50.0, 36.0 * muro_trasero),
		Vector2(-36.0, 24.0 * muro_trasero),
		Vector2(-27.0, 13.0 * muro_trasero),
		Vector2(-19.0, 5.0 * muro_trasero),
		Vector2(-12.0, 1.6 * muro_trasero),
		Vector2(-6.0, 0.2 * muro_trasero),
		Vector2(0.0, 0.0),
		Vector2(distancia_hondonada * 0.3, h_hondonada * 0.15),
		Vector2(distancia_hondonada, h_hondonada),
		Vector2(fondo, h_fondo),
		Vector2(fondo + 30.0, h_fondo + 7.0),
		Vector2(fondo + 70.0, h_fondo + 16.0),
		Vector2(fondo + 130.0, h_fondo + 40.0),
	]
	if con_arena:
		# La subida del fondo se cambia por una meseta casi plana que cruza la arena de combate.
		# Después de la meseta el terreno vuelve a subir (y _cierre() le suma la pared del fondo).
		_perfil_puntos.resize(_perfil_puntos.size() - 3)
		var h_meseta: float = h_fondo + 1.0
		var inicio_meseta: float = fondo + 20.0
		var fin_meseta: float = maxf(distancia_arena + radio_arena + transicion_arena * 0.5, inicio_meseta + 10.0)
		_perfil_puntos.append(Vector2(inicio_meseta, h_meseta))
		_perfil_puntos.append(Vector2(fin_meseta, h_meseta))
		_perfil_puntos.append(Vector2(fin_meseta + 40.0, h_meseta + 10.0))
		_perfil_puntos.append(Vector2(fin_meseta + 90.0, h_meseta + 30.0))
	var cantidad: int = _perfil_puntos.size()
	_perfil_pendientes.resize(cantidad)
	for i in range(cantidad):
		var a: int = maxi(i - 1, 0)
		var b: int = mini(i + 1, cantidad - 1)
		_perfil_pendientes[i] = (_perfil_puntos[b].y - _perfil_puntos[a].y) / (_perfil_puntos[b].x - _perfil_puntos[a].x)


# Altura del perfil del valle en un punto del recorrido (interpolación suave entre puntos).
func _perfil_valle(avance: float) -> float:
	var cantidad: int = _perfil_puntos.size()
	if cantidad < 2:
		return 0.0
	if avance <= _perfil_puntos[0].x:
		return _perfil_puntos[0].y
	if avance >= _perfil_puntos[cantidad - 1].x:
		return _perfil_puntos[cantidad - 1].y
	var i: int = 0
	while i < cantidad - 2 and avance > _perfil_puntos[i + 1].x:
		i += 1
	var p0: Vector2 = _perfil_puntos[i]
	var p1: Vector2 = _perfil_puntos[i + 1]
	var largo: float = p1.x - p0.x
	var t: float = (avance - p0.x) / largo
	var t2: float = t * t
	var t3: float = t2 * t
	return (2.0 * t3 - 3.0 * t2 + 1.0) * p0.y \
			+ (t3 - 2.0 * t2 + t) * largo * _perfil_pendientes[i] \
			+ (-2.0 * t3 + 3.0 * t2) * p1.y \
			+ (t3 - t2) * largo * _perfil_pendientes[i + 1]


# Crea (o vuelve a crear) las ruinas del inicio sobre el terreno.
func _generar_ruinas() -> void:
	var viejo: Node = get_node_or_null("RuinasGeneradas")
	if viejo != null:
		remove_child(viejo)
		viejo.free()
	if not con_ruinas or not ResourceLoader.exists(RUTA_RUINAS):
		return
	var ruinas := Node3D.new()
	ruinas.name = "RuinasGeneradas"
	ruinas.set_script(load(RUTA_RUINAS))
	add_child(ruinas)
	ruinas.call("construir", self, posicion_ruinas)


# Crea (o vuelve a crear) los props del recorrido: sendero, postes, costillas, rocas, hierba y polvo.
func _generar_props() -> void:
	var viejo: Node = get_node_or_null("PropsGenerados")
	if viejo != null:
		remove_child(viejo)
		viejo.free()
	if not con_props or not ResourceLoader.exists(RUTA_PROPS):
		return
	var props := Node3D.new()
	props.name = "PropsGenerados"
	props.set_script(load(RUTA_PROPS))
	add_child(props)
	props.call("construir", self)


func _configurar_ruido() -> void:
	_ruido = FastNoiseLite.new()
	_ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ruido.fractal_type = FastNoiseLite.FRACTAL_NONE
	_ruido.frequency = 1.0
	_ruido.seed = semilla
	_preparar_valle()
	# El claro de combate queda a la altura que tendría el terreno en su centro.
	var centro: Vector2 = _centro_arena()
	_altura_arena = _altura_original(centro.x, centro.y)


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
# el mundo (triplanar) para que no se estiren en las paredes empinadas.
func _material_con_texturas() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = _textura(RUTA_ARENA_COLOR, false)
	material.albedo_color = tinte_arena
	material.roughness = 0.85
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
