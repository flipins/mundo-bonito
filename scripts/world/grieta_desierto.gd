@tool
extends Node3D
## Grieta del desierto: aquí empieza el juego (escenas 1 a 4 del storyboard).
##
## El jugador despierta al fondo de una grieta cerrada, la recorre en línea (sin poder salirse,
## porque las paredes la encierran), llega a una cámara donde está la espada clavada sobre una
## roca, y sigue hasta unas escaleras que suben a la zona plana del desierto.
##
## Cómo funciona:
##  - La forma sale de los marcadores (Marker3D) del nodo "Camino". Muévelos en el editor y el
##    terreno se vuelve a tallar solo, unos instantes después de soltarlos:
##      * El primero es el inicio de la grieta (un fondo cerrado, donde empieza el jugador).
##      * El que se llama "Camara..." es el centro de la cámara de la espada, más ancha.
##      * Los dos últimos son las escaleras: la base (misma altura que el piso) y la cima, cuya
##        altura se ajusta sola al nivel del terreno para que la salida quede pareja.
##    La altura (Y) de los demás marcadores es la altura del piso en ese punto.
##  - El terreno (dunas.gd) le pregunta a la grieta cuánto bajar en cada punto. Si no hay una
##    grieta en la escena, el terreno es el de siempre.
##  - Las escaleras se dibujan como escalones; el personaje camina sobre una rampa invisible que
##    pasa justo por encima de ellos, así sube sin trabarse en cada escalón.
##  - La zona de historia final (junto a la espada) y las demás se colocan solas sobre el camino
##    (ver zona_historia.gd).

## Se emite cuando el jugador recoge la espada.
signal espada_recogida

const GRUPO := &"grieta_desierto"
const GRUPO_TERRENO := &"terreno_dunas"
const RUTA_RECOGIBLE := "res://scripts/objects/recogible.gd"
## Tamaño de las celdas del índice que acelera las consultas del terreno, en metros.
const CELDA: float = 8.0
# Colores por vértice del terreno (sRGB): arena en el piso, roca con vetas en las paredes.
const COLOR_ARENA := Color(0.85, 0.7, 0.47)
const COLOR_ROCA_A := Color(0.50, 0.33, 0.24)
const COLOR_ROCA_B := Color(0.64, 0.44, 0.31)

@export_group("Forma de la grieta")
## Ancho del piso de la grieta, en metros.
@export_range(3.0, 30.0, 0.5) var ancho: float = 8.0
## Cuánto cambia el ancho a lo largo del camino (0 = siempre igual, 0.5 = varía hasta un 50 %).
@export_range(0.0, 0.8, 0.05) var variacion_ancho: float = 0.25
## Ancho de las escaleras, en metros.
@export_range(2.0, 20.0, 0.5) var ancho_escaleras: float = 6.0
## Qué tan inclinadas son las paredes: distancia horizontal entre el piso y el borde de arriba.
## Menos metros = paredes más verticales.
@export_range(1.0, 15.0, 0.5) var ancho_pared: float = 4.0
## Radio de la cámara de la espada (el ensanchamiento al final), en metros.
@export_range(4.0, 30.0, 0.5) var radio_camara: float = 11.0
## Qué tan irregulares son los bordes de las paredes, en metros.
@export_range(0.0, 4.0, 0.1) var irregularidad: float = 1.2
## Cambia este número para otra irregularidad.
@export var semilla: int = 3
## Suavizado de las curvas: puntos por tramo entre marcadores (1 = tramos rectos).
@export_range(1, 12, 1) var pasos_curva: int = 6

@export_group("Escaleras")
## Altura de cada escalón, en metros.
@export_range(0.1, 0.5, 0.01) var altura_escalon: float = 0.2
## Material de los escalones y de la roca de la espada. Vacío = piedra lisa.
@export var material_escaleras: Material

@export_group("Espada")
## Crea la espada sobre una roca en el centro de la cámara.
@export var crear_espada: bool = true
## Modelo de la espada.
@export_file("*.glb", "*.gltf", "*.tscn") var archivo_espada: String = "res://assets/models/espada/暗影古剑.glb"
## Largo de la espada completa (hoja y empuñadura), en metros.
@export_range(0.5, 3.0, 0.05) var largo_espada: float = 1.5
## Cuánto de la hoja queda clavada en la roca, en metros.
@export_range(0.0, 1.0, 0.05) var hundimiento: float = 0.45
## Inclinación de la espada, en grados.
@export_range(-30.0, 30.0, 1.0) var inclinacion_espada: float = 8.0
## Acero negro en todas las piezas, como en el fondo del menú. Apágalo para ver las texturas del modelo.
@export var acero_negro: bool = true
## Una luz cálida junto a la espada, para que se note en la penumbra de la grieta.
@export var luz_espada: bool = true
## Identificador interno de la espada en el inventario.
@export var id_espada: StringName = &"espada"
## Nombre que ve el jugador.
@export var nombre_espada: String = "Espada"
## Aviso que aparece al mirarla.
@export var texto_prompt_espada: String = "Tomar la espada"
## Mensaje que aparece al recogerla.
@export var mensaje_espada: String = "Recogiste: Espada"

@export_group("Jugador")
## Al empezar el juego, coloca al jugador al inicio de la grieta mirando hacia el camino.
@export var mover_jugador_al_inicio: bool = true
## Cuántos metros adelante del fondo cerrado aparece el jugador.
@export_range(0.0, 20.0, 0.5) var distancia_inicio: float = 5.0

@export_group("Editor")
## En el editor, vuelve a tallar el terreno cuando mueves los marcadores o cambias valores.
## Desactívalo si el editor se pone lento mientras ajustas la grieta.
@export var actualizar_en_editor: bool = true

# Camino ya suavizado, en el espacio local del terreno (x, z), con su altura de piso, la mitad
# del ancho y la distancia acumulada en cada punto.
var _pl := PackedVector2Array()
var _ply := PackedFloat32Array()
var _plw := PackedFloat32Array()
var _plt := PackedFloat32Array()
var _indice: Dictionary = {}
var _caja := Rect2()
var _hay_camara: bool = false
var _camara_xz := Vector2.ZERO
var _camara_y: float = 0.0
var _i_camara: int = 0
var _y_cima: float = 0.0
var _preparado: bool = false
var _terreno: Node3D = null
var _ruido: FastNoiseLite
var _generado: Node3D = null
var _material_piedra_cache: Material = null
var _reloj_editor: float = 0.0
var _firma_vista: int = 0
var _firma_aplicada: int = 0


func _ready() -> void:
	add_to_group(GRUPO)
	_configurar_ruido()
	set_process(Engine.is_editor_hint())
	# Un instante después, cuando el terreno y el resto de la escena ya están listos.
	_iniciar.call_deferred()


func _exit_tree() -> void:
	# En el editor, si borras la grieta el terreno vuelve a su forma normal.
	if Engine.is_editor_hint() and is_inside_tree():
		for terreno in get_tree().get_nodes_in_group(GRUPO_TERRENO):
			terreno.call_deferred(&"regenerar_ahora")


func _process(delta: float) -> void:
	# Solo en el editor: espera a que dejes de mover los marcadores y vuelve a tallar.
	if not actualizar_en_editor:
		return
	_reloj_editor += delta
	if _reloj_editor < 0.5:
		return
	_reloj_editor = 0.0
	var firma: int = _firma()
	if firma != _firma_vista:
		_firma_vista = firma
		return
	if firma != _firma_aplicada:
		_firma_aplicada = firma
		_regenerar_todo()


func _iniciar() -> void:
	if not is_inside_tree():
		return
	_asegurar_preparado()
	_reconstruir()
	if Engine.is_editor_hint():
		_firma_vista = _firma()
		_firma_aplicada = _firma_vista
		# Si el terreno ya estaba generado sin esta grieta, se vuelve a tallar.
		for terreno in get_tree().get_nodes_in_group(GRUPO_TERRENO):
			if terreno.has_method(&"usa_esta_grieta") and not terreno.usa_esta_grieta(self):
				terreno.regenerar_ahora()
	else:
		_colocar_jugador()


func _regenerar_todo() -> void:
	if not is_inside_tree():
		return
	for terreno in get_tree().get_nodes_in_group(GRUPO_TERRENO):
		terreno.regenerar_ahora()
	# Las escaleras y la espada se vuelven a poner cuando el terreno ya se talló.
	_reconstruir.call_deferred()


# Resume todo lo que cambia la forma de la grieta, para saber si hay que volver a tallar.
func _firma() -> int:
	var partes: Array = [ancho, variacion_ancho, ancho_escaleras, ancho_pared, radio_camara,
			irregularidad, semilla, pasos_curva, altura_escalon, largo_espada, hundimiento,
			inclinacion_espada, crear_espada]
	for marca in _marcadores():
		partes.append(marca.global_position)
	return str(partes).hash()


# --- Marcadores --------------------------------------------------------------------------------

func _marcadores() -> Array[Node3D]:
	var lista: Array[Node3D] = []
	var camino := get_node_or_null("Camino")
	if camino == null:
		return lista
	for hijo in camino.get_children():
		if hijo is Node3D:
			lista.append(hijo as Node3D)
	return lista


# Índice del marcador que se llama "Camara...", o -1 si no hay.
func _indice_camara(marcas: Array[Node3D]) -> int:
	for i in range(marcas.size()):
		if String(marcas[i].name).to_lower().begins_with("camara"):
			return i
	return -1


func _xz(punto: Vector3) -> Vector2:
	return Vector2(punto.x, punto.z)


## Posición en el mundo de un marcador del camino por su nombre, o Vector3.INF si no existe.
func punto_de_marcador(nombre: String) -> Vector3:
	for marca in _marcadores():
		if String(marca.name) == nombre:
			return marca.global_position
	return Vector3.INF


## Punto del camino en el mundo. La fracción va de 0 (el inicio) a 1 (la cámara de la espada).
## Sigue la curva real de la grieta, no los tramos rectos entre marcadores.
func punto_en_camino(fraccion: float) -> Vector3:
	if not _asegurar_preparado():
		return Vector3.INF
	return _punto_por_distancia(clampf(fraccion, 0.0, 1.0) * _plt[_i_camara])


# Punto en el mundo a cierta distancia (en metros) del inicio, siguiendo el camino.
func _punto_por_distancia(distancia: float) -> Vector3:
	if not _asegurar_preparado():
		return Vector3.INF
	var n: int = _pl.size()
	var d: float = clampf(distancia, 0.0, _plt[n - 1])
	for i in range(n - 1):
		if d <= _plt[i + 1] or i == n - 2:
			var largo: float = _plt[i + 1] - _plt[i]
			var u: float = 0.0
			if largo > 0.0001:
				u = clampf((d - _plt[i]) / largo, 0.0, 1.0)
			var p: Vector2 = _pl[i].lerp(_pl[i + 1], u)
			return _terreno.to_global(Vector3(p.x, lerpf(_ply[i], _ply[i + 1], u), p.y))
	return Vector3.INF


# --- Forma de la grieta (la usa el terreno) ----------------------------------------------------

func _configurar_ruido() -> void:
	_ruido = FastNoiseLite.new()
	_ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ruido.fractal_type = FastNoiseLite.FRACTAL_NONE
	_ruido.frequency = 1.0
	_ruido.seed = semilla


func _asegurar_preparado() -> bool:
	if _preparado and is_instance_valid(_terreno):
		return true
	if not is_inside_tree():
		return false
	var terreno := get_tree().get_first_node_in_group(GRUPO_TERRENO) as Node3D
	if terreno == null:
		return false
	preparar(terreno)
	return _preparado


## Calcula el camino de la grieta en el espacio del terreno. La llama el terreno antes de tallar.
func preparar(terreno: Node3D) -> void:
	_preparado = false
	_terreno = terreno
	if terreno == null or not terreno.is_inside_tree():
		return
	var marcas: Array[Node3D] = _marcadores()
	var n: int = marcas.size()
	if n < 3:
		push_warning("GrietaDesierto: el nodo 'Camino' necesita al menos 3 marcadores (inicio, base de las escaleras y cima).")
		return
	_configurar_ruido()

	# Posiciones de los marcadores en el espacio del terreno.
	var locales: Array[Vector3] = []
	for marca in marcas:
		locales.append(terreno.to_local(marca.global_position))

	# La cima de las escaleras queda justo al nivel del terreno, para que la salida sea pareja.
	var cima: Vector3 = locales[n - 1]
	if terreno.has_method(&"altura_base"):
		cima.y = terreno.altura_base(cima.x, cima.z)
	locales[n - 1] = cima
	_y_cima = cima.y

	# Hasta qué marcador se suavizan las curvas (la cámara; o la base de las escaleras si no hay).
	var ic: int = _indice_camara(marcas)
	_hay_camara = ic >= 0 and ic <= n - 2
	var ultimo: int = ic if _hay_camara else n - 2
	var pasos: int = maxi(pasos_curva, 1)

	var puntos := PackedVector2Array()
	var alturas := PackedFloat32Array()
	for k in range(ultimo):
		var p0: Vector2 = _xz(locales[maxi(k - 1, 0)])
		var p1: Vector2 = _xz(locales[k])
		var p2: Vector2 = _xz(locales[k + 1])
		var p3: Vector2 = _xz(locales[mini(k + 2, ultimo)])
		for s in range(pasos):
			var t: float = float(s) / float(pasos)
			puntos.append(p1.cubic_interpolate(p2, p0, p3, t))
			alturas.append(lerpf(locales[k].y, locales[k + 1].y, t))
	_i_camara = puntos.size()
	# Del último marcador suavizado hasta la cima, en tramos rectos (las escaleras son rectas).
	for k in range(ultimo, n):
		puntos.append(_xz(locales[k]))
		alturas.append(locales[k].y)

	var mitad: float = ancho * 0.5
	var mitad_escaleras: float = ancho_escaleras * 0.5
	var anchos := PackedFloat32Array()
	var acumulado := PackedFloat32Array()
	acumulado.resize(puntos.size())
	var recorrido: float = 0.0
	for i in range(puntos.size()):
		anchos.append(mitad_escaleras if i >= puntos.size() - 2 else mitad)
		if i > 0:
			recorrido += puntos[i].distance_to(puntos[i - 1])
		acumulado[i] = recorrido

	_pl = puntos
	_ply = alturas
	_plw = anchos
	_plt = acumulado
	_camara_xz = _xz(locales[ultimo])
	_camara_y = locales[ultimo].y

	# Hasta dónde llega la influencia de la grieta alrededor de su camino.
	var margen: float = maxf(mitad * (1.0 + variacion_ancho), mitad_escaleras)
	if _hay_camara:
		margen = maxf(margen, radio_camara)
	margen += ancho_pared + irregularidad * 1.5 + 1.0

	var minimo := Vector2(INF, INF)
	var maximo := Vector2(-INF, -INF)
	for p in _pl:
		minimo = minimo.min(p)
		maximo = maximo.max(p)
	if _hay_camara:
		minimo = minimo.min(_camara_xz - Vector2(radio_camara, radio_camara))
		maximo = maximo.max(_camara_xz + Vector2(radio_camara, radio_camara))
	_caja = Rect2(minimo - Vector2(margen, margen), (maximo - minimo) + Vector2(margen, margen) * 2.0)

	# Índice por celdas: cada celda guarda qué tramos del camino le quedan cerca.
	_indice.clear()
	for i in range(_pl.size() - 1):
		var a: Vector2 = _pl[i]
		var b: Vector2 = _pl[i + 1]
		var desde: Vector2 = a.min(b) - Vector2(margen, margen)
		var hasta: Vector2 = a.max(b) + Vector2(margen, margen)
		for cx in range(floori(desde.x / CELDA), floori(hasta.x / CELDA) + 1):
			for cz in range(floori(desde.y / CELDA), floori(hasta.y / CELDA) + 1):
				var celda := Vector2i(cx, cz)
				var lista: PackedInt32Array = _indice.get(celda, PackedInt32Array())
				lista.append(i)
				_indice[celda] = lista

	_preparado = true


# Mide un punto respecto de la grieta. Devuelve (distancia con signo al borde del piso,
# altura del piso, 1 si el punto está junto a las escaleras). Negativo = dentro del piso.
func _medir(x: float, z: float) -> Vector3:
	var p := Vector2(x, z)
	var mejor: float = 1.0e9
	var piso: float = 0.0
	var escalera: float = 0.0
	var celda := Vector2i(floori(x / CELDA), floori(z / CELDA))
	if _indice.has(celda):
		var ultimo_tramo: int = _pl.size() - 2
		var lista: PackedInt32Array = _indice[celda]
		for i in lista:
			var a: Vector2 = _pl[i]
			var ab: Vector2 = _pl[i + 1] - a
			var largo2: float = ab.length_squared()
			var u: float = 0.0
			if largo2 > 0.0001:
				u = clampf((p - a).dot(ab) / largo2, 0.0, 1.0)
			var mitad: float = lerpf(_plw[i], _plw[i + 1], u)
			var es_escalera: bool = i == ultimo_tramo
			if not es_escalera:
				# El ancho cambia suavemente a lo largo del camino.
				var recorrido: float = lerpf(_plt[i], _plt[i + 1], u)
				mitad *= 1.0 + variacion_ancho * _ruido.get_noise_1d(recorrido * 0.04)
			var sd: float = p.distance_to(a + ab * u) - mitad
			if sd < mejor:
				mejor = sd
				piso = lerpf(_ply[i], _ply[i + 1], u)
				escalera = 1.0 if es_escalera else 0.0
	if _hay_camara:
		var sdc: float = p.distance_to(_camara_xz) - radio_camara
		if sdc < mejor:
			mejor = sdc
			piso = _camara_y
			escalera = 0.0
	return Vector3(mejor, piso, escalera)


## Altura del terreno en un punto (espacio local del terreno) una vez tallada la grieta.
## "base" es la altura que tendría el terreno sin grieta.
func altura_con_grieta(x: float, z: float, base: float) -> float:
	if not _preparado or not _caja.has_point(Vector2(x, z)):
		return base
	var medida: Vector3 = _medir(x, z)
	var sd: float = medida.x
	if sd > ancho_pared + irregularidad * 1.5:
		return base
	if medida.z < 0.5:
		# Los bordes de la grieta no son rectos (en las escaleras sí, para que calcen los escalones).
		sd += _ruido.get_noise_2d(x * 0.2, z * 0.2) * irregularidad
	var piso: float = minf(medida.y, base)
	if sd <= 0.0:
		return piso
	var s: float = clampf(sd / ancho_pared, 0.0, 1.0)
	return lerpf(piso, base, s * s * (3.0 - 2.0 * s))


## Color de un vértice del terreno: arena en el piso y roca con vetas en las paredes.
func color_vertice(x: float, z: float, altura: float, base: float, normal_y: float) -> Color:
	var profundidad: float = base - altura
	if profundidad < 0.02:
		return COLOR_ARENA
	var pendiente: float = 1.0 - normal_y
	var roca: float = smoothstep(0.03, 0.30, pendiente) * smoothstep(0.02, 0.6, profundidad)
	var vetas: float = 0.5 + 0.5 * sin(altura * 1.9 + _ruido.get_noise_2d(x * 0.08, z * 0.08) * 4.0)
	var color_roca: Color = COLOR_ROCA_A.lerp(COLOR_ROCA_B, vetas)
	# El piso se oscurece un poco con la profundidad, como si le llegara menos luz.
	var oscuro: float = 1.0 - 0.18 * smoothstep(0.5, 5.0, profundidad)
	var piso := Color(COLOR_ARENA.r * oscuro, COLOR_ARENA.g * oscuro, COLOR_ARENA.b * oscuro, 1.0)
	return piso.lerp(color_roca, roca)


# --- Escaleras y espada ------------------------------------------------------------------------

func _reconstruir() -> void:
	if not is_inside_tree():
		return
	if _generado != null and is_instance_valid(_generado):
		remove_child(_generado)
		_generado.queue_free()
	_generado = null
	_asegurar_preparado()
	var marcas: Array[Node3D] = _marcadores()
	if marcas.size() < 3:
		return
	_generado = Node3D.new()
	_generado.name = "Generado"
	add_child(_generado)
	_construir_escaleras(marcas)
	if crear_espada:
		_construir_espada(marcas)


func _material_piedra() -> Material:
	if material_escaleras != null:
		return material_escaleras
	if _material_piedra_cache == null:
		var piedra := StandardMaterial3D.new()
		piedra.albedo_color = Color(0.52, 0.43, 0.35)
		piedra.roughness = 1.0
		_material_piedra_cache = piedra
	return _material_piedra_cache


func _construir_escaleras(marcas: Array[Node3D]) -> void:
	var n: int = marcas.size()
	var base: Vector3 = marcas[n - 2].global_position
	var cima: Vector3 = marcas[n - 1].global_position
	# La cima se corrige a la altura real del terreno (igual que al tallar).
	if _preparado and is_instance_valid(_terreno):
		var local: Vector3 = _terreno.to_local(cima)
		cima = _terreno.to_global(Vector3(local.x, _y_cima, local.z))
	var plano := Vector3(cima.x - base.x, 0.0, cima.z - base.z)
	var largo: float = plano.length()
	var alto: float = cima.y - base.y
	if largo < 1.0 or alto < 0.3:
		return
	var dir: Vector3 = plano / largo
	var cantidad: int = maxi(1, roundi(alto / altura_escalon))
	var subida: float = alto / float(cantidad)
	var huella: float = largo / float(cantidad)
	var ancho_total: float = ancho_escaleras + 0.8
	var giro: Basis = Basis.looking_at(dir, Vector3.UP)

	# Los escalones: cajas de piedra, cada una más alta que la anterior.
	var forma_escalon := BoxMesh.new()
	forma_escalon.size = Vector3(ancho_total, subida + 0.5, huella + 0.02)
	forma_escalon.material = _material_piedra()
	var escaleras := Node3D.new()
	escaleras.name = "Escaleras"
	_generado.add_child(escaleras)
	for i in range(cantidad):
		var escalon := MeshInstance3D.new()
		escalon.mesh = forma_escalon
		escaleras.add_child(escalon)
		var centro: Vector3 = base + dir * ((float(i) + 0.5) * huella)
		centro.y = base.y + float(i + 1) * subida - (subida + 0.5) * 0.5
		escalon.global_transform = Transform3D(giro, centro)

	if Engine.is_editor_hint():
		return

	# La colisión: una rampa que pasa por la mitad de los escalones (a lo más 10 cm de diferencia)
	# y arranca a ras del piso, y una losa plana para salir al terreno sin escalón al final.
	var alfa: float = atan2(alto, largo)
	var subiendo := Vector3(dir.x * cos(alfa), sin(alfa), dir.z * cos(alfa))
	var normal := Vector3(-dir.x * sin(alfa), cos(alfa), -dir.z * sin(alfa))
	var eje_x: Vector3 = normal.cross(subiendo)
	var largo_rampa: float = sqrt(largo * largo + alto * alto)
	var inicio: Vector3 = base - dir * (huella * 0.5)

	var cuerpo := StaticBody3D.new()
	cuerpo.name = "ColisionEscaleras"
	_generado.add_child(cuerpo)
	var rampa := CollisionShape3D.new()
	var caja_rampa := BoxShape3D.new()
	caja_rampa.size = Vector3(ancho_total, 0.6, largo_rampa)
	rampa.shape = caja_rampa
	cuerpo.add_child(rampa)
	rampa.global_transform = Transform3D(Basis(eje_x, normal, subiendo), inicio + subiendo * (largo_rampa * 0.5) - normal * 0.3)

	var largo_losa: float = huella * 0.5 + 0.6
	var losa := CollisionShape3D.new()
	var caja_losa := BoxShape3D.new()
	caja_losa.size = Vector3(ancho_total, 0.6, largo_losa)
	losa.shape = caja_losa
	cuerpo.add_child(losa)
	var centro_losa: Vector3 = base + dir * (largo - huella * 0.5 + largo_losa * 0.5)
	centro_losa.y = cima.y - 0.3
	losa.global_transform = Transform3D(giro, centro_losa)


func _construir_espada(marcas: Array[Node3D]) -> void:
	var ic: int = _indice_camara(marcas)
	if ic < 0:
		ic = marcas.size() - 2
	var centro: Vector3 = marcas[ic].global_position
	var altura_roca: float = 0.55

	# La roca donde está clavada.
	var forma_roca := CylinderMesh.new()
	forma_roca.top_radius = 0.8
	forma_roca.bottom_radius = 1.1
	forma_roca.height = altura_roca
	forma_roca.radial_segments = 14
	forma_roca.rings = 1
	forma_roca.material = _material_piedra()
	var roca := MeshInstance3D.new()
	roca.name = "RocaDeLaEspada"
	roca.mesh = forma_roca
	_generado.add_child(roca)
	roca.global_position = centro + Vector3(0.0, altura_roca * 0.5, 0.0)
	if not Engine.is_editor_hint():
		var cuerpo_roca := StaticBody3D.new()
		var colision_roca := CollisionShape3D.new()
		var cilindro := CylinderShape3D.new()
		cilindro.radius = 1.0
		cilindro.height = altura_roca
		colision_roca.shape = cilindro
		cuerpo_roca.add_child(colision_roca)
		roca.add_child(cuerpo_roca)

	# El objeto que se recoge: usa el mismo script que los demás objetos recogibles.
	var raiz: Node3D
	if Engine.is_editor_hint():
		raiz = Node3D.new()
	else:
		var recogible := StaticBody3D.new()
		recogible.set_script(load(RUTA_RECOGIBLE))
		recogible.set("id_objeto", id_espada)
		recogible.set("nombre_objeto", nombre_espada)
		recogible.set("texto_prompt", texto_prompt_espada)
		recogible.set("mensaje", mensaje_espada)
		recogible.connect(&"interactuado", _al_recoger_espada)
		raiz = recogible
	raiz.name = "Espada"
	_generado.add_child(raiz)
	raiz.global_position = centro + Vector3(0.0, altura_roca, 0.0)

	# El modelo, de cabeza: la punta hacia la roca y el pomo arriba.
	var pivote := Node3D.new()
	pivote.name = "Pivote"
	pivote.rotation_degrees = Vector3(inclinacion_espada, 0.0, 0.0)
	raiz.add_child(pivote)
	var modelo: Node3D = _crear_modelo_espada()
	var medida: AABB = _aabb_de(modelo)
	var k: float = largo_espada / maxf(medida.size.y, 0.001)
	var c: Vector3 = medida.get_center()
	modelo.scale = Vector3.ONE * k
	modelo.rotation = Vector3(0.0, 0.0, PI)
	modelo.position = Vector3(c.x * k, medida.end.y * k - hundimiento, -c.z * k)
	pivote.add_child(modelo)

	if not Engine.is_editor_hint():
		# Una caja un poco más ancha que la hoja, para que sea fácil apuntarle.
		var visible_largo: float = maxf(largo_espada - hundimiento, 0.3)
		var colision := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = Vector3(0.7, visible_largo + 0.2, 0.7)
		colision.shape = caja
		colision.position = Vector3(0.0, visible_largo * 0.5, 0.0)
		raiz.add_child(colision)

	if luz_espada:
		var luz := OmniLight3D.new()
		luz.light_color = Color(1.0, 0.82, 0.5)
		luz.light_energy = 1.8
		luz.omni_range = 8.0
		luz.position = Vector3(0.0, largo_espada * 0.7, 0.5)
		raiz.add_child(luz)


func _crear_modelo_espada() -> Node3D:
	if archivo_espada != "" and ResourceLoader.exists(archivo_espada):
		var escena := load(archivo_espada) as PackedScene
		if escena != null:
			var modelo := escena.instantiate() as Node3D
			if modelo != null:
				# Igual que en el fondo del menú: se quitan los "Cube" sueltos del modelo.
				for nodo in modelo.find_children("Cube*", "", true, false):
					nodo.get_parent().remove_child(nodo)
					nodo.free()
				if acero_negro:
					var acero := StandardMaterial3D.new()
					acero.albedo_color = Color(0.07, 0.07, 0.085)
					acero.metallic = 0.9
					acero.roughness = 0.35
					for pieza in modelo.find_children("*", "MeshInstance3D", true, false):
						(pieza as MeshInstance3D).material_override = acero
				return modelo
	push_warning("GrietaDesierto: no se encontró la espada '%s'; se usa una espada de relleno." % archivo_espada)
	var relleno := Node3D.new()
	var hoja := BoxMesh.new()
	hoja.size = Vector3(0.1, 1.5, 0.03)
	var acero_relleno := StandardMaterial3D.new()
	acero_relleno.albedo_color = Color(0.5, 0.5, 0.55)
	acero_relleno.metallic = 0.9
	acero_relleno.roughness = 0.35
	hoja.material = acero_relleno
	var malla := MeshInstance3D.new()
	malla.mesh = hoja
	relleno.add_child(malla)
	return relleno


# Caja que envuelve todas las piezas del modelo, en el espacio del propio modelo.
func _aabb_de(raiz: Node3D) -> AABB:
	var total := AABB()
	var primero: bool = true
	for nodo in raiz.find_children("*", "MeshInstance3D", true, false):
		var pieza := nodo as MeshInstance3D
		if pieza.mesh == null:
			continue
		var relativa := Transform3D.IDENTITY
		var actual: Node = pieza
		while actual != null and actual != raiz:
			relativa = (actual as Node3D).transform * relativa
			actual = actual.get_parent()
		var caja: AABB = relativa * pieza.mesh.get_aabb()
		if primero:
			total = caja
			primero = false
		else:
			total = total.merge(caja)
	return total


func _al_recoger_espada(_quien: Node) -> void:
	espada_recogida.emit()


# --- Jugador -----------------------------------------------------------------------------------

func _colocar_jugador() -> void:
	if not mover_jugador_al_inicio:
		return
	var jugador: Node = null
	if get_parent() != null:
		jugador = get_parent().get_node_or_null("jugador")
	if jugador == null and get_tree().current_scene != null:
		jugador = get_tree().current_scene.find_child("jugador", true, false)
	if jugador == null or not jugador.has_method(&"teletransportar"):
		push_warning("GrietaDesierto: no se encontró al jugador (o su script no tiene 'teletransportar'); no se mueve.")
		return
	var aqui: Vector3 = _punto_por_distancia(distancia_inicio)
	var adelante: Vector3 = _punto_por_distancia(distancia_inicio + 3.0)
	if not aqui.is_finite() or not adelante.is_finite():
		return
	var dir := Vector3(adelante.x - aqui.x, 0.0, adelante.z - aqui.z)
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	jugador.teletransportar(aqui + Vector3(0.0, 0.3, 0.0), atan2(-dir.x, -dir.z))
