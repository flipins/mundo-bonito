@tool
extends "res://scripts/city/coastal_town_original.gd"

const TexturasCiudad := preload("res://scripts/city/ciudad_texturas.gd")

var _adobe_ciudad: Material
var _adobe_claro_ciudad: Material
var _hierro_ciudad: Material
var _llama_ciudad: Material
var _barro_ciudad: Material
var _agua_fuente_ciudad: Material


# Primero se preparan los materiales originales, incluidos terreno, mar y murallas.
func _preparar_materiales() -> void:
	super._preparar_materiales()

	_piedra = TexturasCiudad.piedra(Color(0.80, 0.68, 0.50))
	_piedra_oscura = TexturasCiudad.piedra(Color(0.60, 0.51, 0.40))
	_teja = TexturasCiudad.teja(Color(0.62, 0.34, 0.22))
	_madera = TexturasCiudad.madera(Color(0.42, 0.28, 0.17))
	_adobe_ciudad = TexturasCiudad.adobe(Color(0.82, 0.69, 0.50))
	_adobe_claro_ciudad = TexturasCiudad.adobe(Color(0.90, 0.78, 0.60))
	_camino = TexturasCiudad.empedrado(
		Color(0.60, 0.55, 0.47),
		Color(0.78, 0.66, 0.46)
	)

	_hierro_ciudad = _mat(Color(0.08, 0.07, 0.06), 0.82)
	_barro_ciudad = _mat(Color(0.66, 0.32, 0.19))
	_agua_fuente_ciudad = _mat(Color(0.18, 0.48, 0.55), 0.15)

	var llama := StandardMaterial3D.new()
	llama.albedo_color = Color(1.0, 0.55, 0.15)
	llama.emission_enabled = true
	llama.emission = Color(1.0, 0.45, 0.10)
	llama.emission_energy_multiplier = 2.5
	_llama_ciudad = llama


# MURALLAS Y PUERTA

func _crear_murallas() -> void:
	super._crear_murallas()

	var padre := _capa("Walls")
	var x := _entrada_x()
	var centro := 8.0
	var suelo := _altura_desierto(x, centro)
	var radio := 7.0
	var arranque := 7.0
	var tramos := 8
	var alto_losa := radio / float(tramos)

	for lado: float in [-1.0, 1.0]:
		# Las caras interiores de las torres están a 10.5 m del eje.
		var borde := centro + lado * 10.6
		var inicio_arco := centro + lado * radio

		_segmento(
			padre, "PilarArco",
			Vector2(x, borde), Vector2(x, inicio_arco),
			6.0, arranque, _piedra, suelo
		)

		for k in range(tramos):
			var y := (float(k) + 0.5) * alto_losa
			var abertura := sqrt(maxf(0.0, radio * radio - y * y))
			_segmento(
				padre, "DovelaArco",
				Vector2(x, borde), Vector2(x, centro + lado * abertura),
				6.0, alto_losa, _piedra, suelo + arranque + k * alto_losa
			)

		_antorcha_ciudad(
			padre, Vector3(x - 3.3, suelo + 4.0, centro + lado * 8.6)
		)

	# El rastrillo queda levantado por encima del paso del jugador.
	for i in range(-4, 5):
		var z := float(i) * 1.5
		var tope := suelo + arranque + sqrt(radio * radio - z * z)
		_caja(
			padre, "BarraRastrillo",
			Vector3(x - 1.8, tope - 1.7, centro + z),
			Vector3(0.18, 3.4, 0.18), _hierro_ciudad, false
		)

	_caja(
		padre, "TravesanoRastrillo", Vector3(x - 1.8, suelo + 10.8, centro),
		Vector3(0.24, 0.22, 12.4), _hierro_ciudad, false
	)


func _antorcha_ciudad(padre: Node3D, pos: Vector3) -> void:
	_caja(padre, "SoporteAntorcha", pos, Vector3(0.18, 1.1, 0.18), _madera, false)
	_caja(
		padre, "LlamaAntorcha", pos + Vector3.UP * 0.75,
		Vector3(0.30, 0.45, 0.30), _llama_ciudad, false
	)

	var luz := OmniLight3D.new()
	luz.name = "LuzAntorcha"
	luz.position = pos + Vector3.UP * 0.9
	luz.light_color = Color(1.0, 0.62, 0.28)
	luz.light_energy = 1.4
	luz.omni_range = 11.0
	luz.shadow_enabled = false
	padre.add_child(luz)


# CASAS
# El generador original elige los lotes, sitúa cada casa sobre el terreno
# y crea el cimiento a partir de la pieza llamada "Cuerpo".

const VILLA := "res://assets/medieval_village/Export/"
const MERCADO := "res://assets/fantasy_props/export/"
const CAMPAMENTO := "res://AnimpicStudio/POLY - Medieval Camp/Prefabs/"
# Ancho y largo en paneles de dos metros, seguidos del número de plantas.
const CASAS := [Vector3i(2, 3, 2), Vector3i(3, 3, 2), Vector3i(4, 4, 1),
	Vector3i(3, 4, 1), Vector3i(2, 2, 3), Vector3i(3, 5, 2)]
var _modelos_villa: Dictionary = {}
var _lotes_malla: Dictionary = {}


# Terrazas a ambos lados de la avenida. Las transiciones se integran en la
# malla del valle y en la colisión que el terreno genera a partir de ella.
func _altura_desierto(x: float, z: float) -> float:
	var base := super._altura_desierto(x, z)
	var distancia := absf(z - CENTRO_PLAZA.y)
	if distancia < 9 or distancia > 145 or x > -55 or x < _entrada_x() + 12:
		return base
	var borde := smoothstep(_entrada_x() + 12, _entrada_x() + 58, x)
	borde *= 1.0 - smoothstep(-121, -55, x)
	borde *= 1.0 - smoothstep(110, 145, distancia)
	if z < 8:
		borde *= smoothstep(54, 86, Vector2(x, z).distance_to(CENTRO_CASTILLO))
	borde *= smoothstep(15, 36, Vector2(x, z).distance_to(_centro_cuarto))
	var primera := 4.0 * smoothstep(9, 33, distancia)
	var segunda := 5.5 * smoothstep(62, 90, distancia)
	return base + borde * (primera + segunda)


# Cada calle lateral nace en la avenida. Se reservan los solares por pares,
# con la puerta mirando hacia la calle que sirve a esa fila.
func _entrada_x() -> float:
	# La puerta y los dos muros laterales comparten este arranque.
	return -145.0 - longitud_camino_llegada * 0.23


func _paseo_costero(z: float) -> Vector2:
	return Vector2(_costa(z) - 3.0, z)


func _barrio_pescadores(suelo: SurfaceTool, primero: int) -> int:
	var cantidad := 0
	for z: float in [-69,-58,-47,-36,-25,-14,-3,46,57,68,79,90,101]:
		if primero + cantidad >= cantidad_casas:
			break
		var solar := Vector2(_costa(z) - 12.0, z)
		# Mantener una franja libre alrededor de las bodegas del puerto.
		if absf(solar.x - 57) < 11 and z > -62 and z < -8:
			continue
		_giro_calle = -PI * 0.5
		var numero := primero + cantidad
		_crear_casa(numero, solar)
		var tipo: Vector3i = CASAS[numero % CASAS.size()]
		var umbral := solar + Vector2(tipo.y, 1 if tipo.x % 2 == 0 else 0)
		_pavimentar(suelo, umbral, _paseo_costero(umbral.y), 2.0, 0.12)
		cantidad += 1
	# El camino acompaña la orilla y cruza la rampa de madera en z = 28.
	var previo := _paseo_costero(-72)
	for z in range(-70, 105, 2):
		var punto := _paseo_costero(z)
		_pavimentar(suelo, previo, punto, 4.0, 0.10)
		previo = punto
	_pavimentar(suelo, Vector2(72,28), _paseo_costero(28), 4.4, 0.12)
	return cantidad


func _trazar_barrios() -> void:
	if cantidad_casas <= 0:
		return
	var calles: Dictionary = {}
	var solares: Array[Vector2] = []
	var cruces: Array[float] = []
	var x := CENTRO_PLAZA.x + 78.0
	while x > _entrada_x() + 23:
		cruces.append(x)
		x -= 26
	for calle_x in cruces:
		for sentido: int in [-1, 1]:
			if calle_x > 39 and sentido < 0:
				continue
			for distancia: int in [18, 29, 40, 51, 62, 73, 84, 95, 106, 117, 128]:
				var z := CENTRO_PLAZA.y + sentido * distancia
				var cruce := Vector2(calle_x, z)
				var inicio := Vector2(calle_x, CENTRO_PLAZA.y)
				if _distancia_segmento(CENTRO_CASTILLO, inicio, cruce) < 48.0:
					break
				if _distancia_segmento(_habitacion_xz(), inicio, cruce) < 10.0:
					break
				for lado: int in [-1, 1]:
					var solar := cruce + Vector2(6.8 * lado, 0)
					if solar.x < _costa(z) - 24 and _lote_valido(solar) and not (absf(solar.x - CENTRO_PLAZA.x) < 32 and absf(solar.y - CENTRO_PLAZA.y) < 33):
						solares.append(solar)
						calles[solar] = cruce
	# Selección reproducible para repartir las casas entre calles y niveles.
	for i in range(solares.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := solares[i]
		solares[i] = solares[j]
		solares[j] = tmp
	var suelo := SurfaceTool.new()
	suelo.begin(Mesh.PRIMITIVE_TRIANGLES)
	var extremos: Dictionary = {}
	# Dos frentes continuos cierran la plaza; los huecos centrales son entradas.
	var portales := 0
	for frente: int in [-1, 1]:
		for dx: float in [-20.0, -9.5, 9.5, 20.0]:
			if portales >= cantidad_casas:
				break
			_giro_calle = 0.0 if frente > 0 else PI
			var parcela := CENTRO_PLAZA + Vector2(dx, frente * 24)
			_crear_casa(portales, parcela)
			_pavimentar(suelo, CENTRO_PLAZA + Vector2(dx, frente * 18),
				parcela - Vector2(0, frente * 2), 3.0, 0.13)
			portales += 1
	var costeras := _barrio_pescadores(suelo, portales)
	portales += costeras
	var cantidad := mini(cantidad_casas - portales, solares.size())
	var molinos: Array[Vector2] = []
	for n in cantidad:
		var solar := solares[n]
		var cruce: Vector2 = calles[solar]
		var direccion := signf(cruce.x - solar.x)
		_giro_calle = atan2(-direccion, 0.0)
		var numero := n + portales
		_crear_casa(numero, solar)
		var tipo: Vector3i = CASAS[numero % CASAS.size()]
		if generar_decoracion and solar.x < -100 and absf(solar.y - 8) > 50 and molinos.size() < 2:
			if molinos.is_empty() or molinos[0].distance_to(solar) > 65:
				_molino(_capa("Buildings").get_node("Casa_%03d" % numero), tipo)
				molinos.append(solar)
		var desfase := 1.0 if tipo.x % 2 == 0 else 0.0
		var umbral := solar + Vector2(direccion * tipo.y, direccion * desfase)
		var acceso := Vector2(cruce.x, umbral.y)
		_pavimentar(suelo, acceso, umbral, 1.8, 0.12)
		var clave := Vector2(cruce.x, signf(acceso.y - CENTRO_PLAZA.y))
		var alcance := absf(acceso.y - CENTRO_PLAZA.y) + 1.5
		extremos[clave] = maxf(extremos.get(clave, 0.0), alcance)
	var borde_este := CENTRO_PLAZA.x
	for clave: Vector2 in extremos:
		borde_este = maxf(borde_este, clave.x)
		var inicio := Vector2(clave.x, CENTRO_PLAZA.y)
		_pavimentar(suelo, inicio, inicio + Vector2(0, clave.y * float(extremos[clave])), 4.6, 0.10)
	_pavimentar(suelo, Vector2(_entrada_x(), CENTRO_PLAZA.y), CENTRO_PLAZA, 8.0, 0.14)
	if borde_este > CENTRO_PLAZA.x:
		_pavimentar(suelo, CENTRO_PLAZA + Vector2(10, 0), Vector2(borde_este, CENTRO_PLAZA.y), 5.0, 0.13)
	_pavimentar(suelo, Vector2(borde_este, CENTRO_PLAZA.y), _paseo_costero(CENTRO_PLAZA.y), 4.0, 0.13)
	print("Casas frente al muelle: ", costeras)
	_agregar_malla(_capa("Environment"), "CallesDelBarrio", suelo.commit(), _camino, false)
	print("Barrios conectados: %d casas, %d calles laterales." % [cantidad + portales, extremos.size()])


var _giro_calle := 0.0
var _centro_cuarto := Vector2(-120, 70)


func _pavimentar(st: SurfaceTool, a: Vector2, b: Vector2, ancho: float, alza: float) -> void:
	var avance := a.direction_to(b)
	var lateral := Vector2(-avance.y, avance.x) * ancho * 0.5
	var pasos := maxi(1, ceili(a.distance_to(b) / 2.0))
	for i in pasos:
		var p := a.lerp(b, float(i) / pasos)
		var q := a.lerp(b, float(i + 1) / pasos)
		for v: Vector2 in [p - lateral, q - lateral, q + lateral,
				p - lateral, q + lateral, p + lateral]:
			st.set_normal(Vector3.UP)
			st.set_uv(v * 0.35)
			st.add_vertex(Vector3(v.x, _altura_desierto(v.x, v.y) + alza, v.y))


func _crear_barrio() -> void:
	_lotes_malla.clear()
	_trazar_barrios()
	var edificios := _capa("Buildings")
	for sector: Vector2i in _lotes_malla:
		var grupo := Node3D.new()
		edificios.add_child(grupo)
		grupo.position = Vector3(sector.x * 48, 0, sector.y * 48)
		for malla: Mesh in _lotes_malla[sector]:
			var posiciones: Array = _lotes_malla[sector][malla]
			var lote := MultiMesh.new()
			lote.transform_format = MultiMesh.TRANSFORM_3D
			lote.mesh = malla
			lote.instance_count = posiciones.size()
			for i in posiciones.size():
				var t: Transform3D = posiciones[i]
				t.origin -= grupo.position
				lote.set_instance_transform(i, t)
			var dibujo := MultiMeshInstance3D.new()
			dibujo.multimesh = lote
			grupo.add_child(dibujo)
	print("Ciudad modular: ", _modelos_villa.size(), " modelos del pack medieval en el barrio.")
	_lotes_malla.clear()


func _pieza_modular(casa: Node3D, modelo: String, punto: Vector3, giro := 0.0) -> void:
	if not _modelos_villa.has(modelo):
		var escena := load(VILLA + modelo + ".gltf") as PackedScene
		if escena == null:
			return
		var raiz := escena.instantiate() as Node3D
		var partes: Array = []
		_leer_mallas_villa(raiz, Transform3D.IDENTITY, partes)
		raiz.free()
		_modelos_villa[modelo] = partes
	var sector := Vector2i(floori(casa.position.x / 48), floori(casa.position.z / 48))
	if not _lotes_malla.has(sector):
		_lotes_malla[sector] = {}
	var t := casa.transform * Transform3D(Basis(Vector3.UP, giro), punto)
	for parte: Array in _modelos_villa[modelo]:
		var malla: Mesh = parte[0]
		if not _lotes_malla[sector].has(malla):
			_lotes_malla[sector][malla] = []
		_lotes_malla[sector][malla].append(t * parte[1])


func _leer_mallas_villa(nodo: Node3D, padre: Transform3D, partes: Array) -> void:
	var t := padre * nodo.transform
	if nodo is MeshInstance3D and nodo.mesh != null:
		partes.append([nodo.mesh, t])
	for hijo in nodo.get_children():
		if hijo is Node3D:
			_leer_mallas_villa(hijo, t, partes)


func _crear_casa(numero: int, posicion: Vector2) -> void:
	var casa := Node3D.new()
	casa.name = "Casa_%03d" % numero
	_capa("Buildings").add_child(casa)
	casa.position = Vector3(posicion.x, _altura_desierto(posicion.x, posicion.y), posicion.y)
	casa.rotation.y = _giro_calle
	var tipo: Vector3i = CASAS[numero % CASAS.size()]
	var pie := posicion + Vector2(-sin(_giro_calle), -cos(_giro_calle)) * tipo.y
	casa.position.y = _altura_desierto(pie.x, pie.y) + 0.10
	var alto := 3.0 * tipo.z
	var cuerpo := _caja(casa, "Cuerpo", Vector3.UP * alto * 0.5,
		Vector3(tipo.x * 2, alto, tipo.y * 2), _piedra)
	cuerpo.visible = false
	_caja(casa, "Cimiento", Vector3.DOWN * 0.85,
		Vector3(tipo.x * 2, 1.7, tipo.y * 2), _piedra_oscura, false)
	var forma := "Round" if numero % 2 == 0 else "Flat"
	var puerta: int = [1, 2, 4, 8][numero % 4]
	var marco := "Brick" if numero % 3 == 0 else "WoodDark"
	for piso in tipo.z:
		var material := "UnevenBrick" if piso == 0 and numero % 3 != 0 else "Plaster"
		for lado in 4:
			var giro := lado * PI / 2.0
			var paneles := tipo.x if lado % 2 == 0 else tipo.y
			var fondo := tipo.y if lado % 2 == 0 else tipo.x
			for i in paneles:
				var punto := Vector3(2 * i + 1 - paneles, piso * 3, -fondo).rotated(Vector3.UP, giro)
				var base := "Wall_" + material + "_"
				if lado == 0 and piso == 0 and i == floori(paneles * 0.5):
					_pieza_modular(casa, base + "Door_" + forma, punto, giro)
					_pieza_modular(casa, "DoorFrame_%s_%s" % [forma, marco], punto, giro)
					_pieza_modular(casa, "Door_%d_%s" % [puerta, forma],
						punto + Vector3(-0.51, 0, -0.05).rotated(Vector3.UP, giro), giro)
				elif (i + lado + piso) % 2 == 0:
					_pieza_modular(casa, base + "Window_Wide_" + forma, punto, giro)
					_pieza_modular(casa, "Window_Wide_" + forma + "1", punto, giro)
					if generar_decoracion and lado == 0:
						_pieza_modular(casa, "WindowShutters_Wide_" + forma + "_Open", punto, giro)
				else:
					if piso > 0 and material == "Plaster":
						_pieza_modular(casa, "Wall_Plaster_WoodGrid", punto, giro)
					else:
						_pieza_modular(casa, base + "Straight", punto, giro)
	if generar_decoracion and numero % 5 == 0:
		_pieza_modular(casa, "Prop_Vine2", Vector3(-tipo.x + 0.4,0,-tipo.y-0.18))
	var hastial := "Roof_Front_Brick%d" % (tipo.x * 2)
	_pieza_modular(casa, hastial, Vector3(0, alto, -tipo.y))
	_pieza_modular(casa, hastial, Vector3(0, alto, tipo.y), PI)
	_pieza_modular(casa, "Roof_RoundTiles_%dx%d" % [tipo.x * 2, tipo.y * 2], Vector3.UP * alto)


func _azotea_ciudad(casa: Node3D, ancho: float, largo: float, alto: float) -> void:
	var borde := 0.32
	var y := alto + 0.36

	for lado: float in [-1.0, 1.0]:
		_caja(
			casa, "ParapetoFrontal", Vector3(0, y, lado * (largo - borde) * 0.5),
			Vector3(ancho, 0.72, borde), _adobe_claro_ciudad
		)
		_caja(
			casa, "ParapetoLateral", Vector3(lado * (ancho - borde) * 0.5, y, 0),
			Vector3(borde, 0.72, largo - borde * 2.0), _adobe_claro_ciudad
		)


func _entramado_ciudad(casa: Node3D, ancho: float, largo: float, alto: float) -> void:
	for lado: float in [-1.0, 1.0]:
		var z := lado * (largo * 0.5 + 0.06)
		for x: float in [-ancho * 0.46, 0.0, ancho * 0.46]:
			_caja(
				casa, "VigaVertical", Vector3(x, alto * 0.5, z),
				Vector3(0.22, alto, 0.18), _madera, false
			)
		for y: float in [alto * 0.48, alto - 0.18]:
			_caja(
				casa, "VigaHorizontal", Vector3(0, y, z),
				Vector3(ancho, 0.23, 0.20), _madera, false
			)


func _fachada_ciudad(casa: Node3D, ancho: float, largo: float, alto: float) -> void:
	var frente := largo * 0.5

	_caja(
		casa, "MarcoPuerta", Vector3(0, 1.55, frente + 0.11),
		Vector3(2.05, 3.10, 0.22), _piedra_oscura, false
	)
	_caja(
		casa, "PuertaMadera", Vector3(0, 1.43, frente + 0.24),
		Vector3(1.62, 2.86, 0.14), _madera, false
	)

	for lado: float in [-1.0, 1.0]:
		var x := lado * ancho * 0.29
		var y := alto * 0.56
		_caja(
			casa, "Ventana", Vector3(x, y, frente + 0.12),
			Vector3(1.25, 1.45, 0.15), _hierro_ciudad, false
		)
		_caja(
			casa, "Alfeizar", Vector3(x, y - 0.77, frente + 0.24),
			Vector3(1.60, 0.16, 0.50), _piedra_oscura, false
		)
		_caja(
			casa, "Parteluz", Vector3(x, y, frente + 0.22),
			Vector3(0.11, 1.45, 0.12), _madera, false
		)


func _decoracion_casa_ciudad(
	casa: Node3D, ancho: float, largo: float, numero: int
) -> void:
	var lado := 1.0 if numero % 2 == 0 else -1.0
	var pos := Vector3(lado * ancho * 0.34, 0, largo * 0.5 + 1.1)

	match numero % 3:
		0:
			_caja(
				casa, "Cajon", pos + Vector3.UP * 0.48,
				Vector3(1.18, 0.96, 0.90), _madera, false
			)
		1:
			_vasija_ciudad(casa, pos)
		2:
			_barril_ciudad(casa, pos)


func _cilindro_ciudad(
	padre: Node3D, nombre: String, pos: Vector3,
	radio_arriba: float, radio_abajo: float, alto: float,
	material: Material
) -> void:
	var malla := CylinderMesh.new()
	malla.radial_segments = 12
	malla.rings = 1
	malla.top_radius = radio_arriba
	malla.bottom_radius = radio_abajo
	malla.height = alto

	var pieza := MeshInstance3D.new()
	pieza.name = nombre
	pieza.mesh = malla
	pieza.material_override = material
	pieza.position = pos
	padre.add_child(pieza)


func _vasija_ciudad(padre: Node3D, pos: Vector3) -> void:
	_cilindro_ciudad(
		padre, "VasijaBase", pos + Vector3.UP * 0.28,
		0.48, 0.26, 0.56, _barro_ciudad
	)
	_cilindro_ciudad(
		padre, "VasijaCuello", pos + Vector3.UP * 0.72,
		0.20, 0.48, 0.32, _barro_ciudad
	)


func _barril_ciudad(padre: Node3D, pos: Vector3) -> void:
	_cilindro_ciudad(
		padre, "Barril", pos + Vector3.UP * 0.60,
		0.48, 0.48, 1.20, _madera
	)
	for y: float in [0.25, 0.94]:
		_cilindro_ciudad(
			padre, "AroBarril", pos + Vector3.UP * y,
			0.50, 0.50, 0.09, _hierro_ciudad
		)


# PLAZA Y MERCADO

func _crear_plaza() -> void:
	var padre := _capa("Market")
	var centro := Vector3(CENTRO_PLAZA.x, 0.0, CENTRO_PLAZA.y)

	_caja(
		padre, "SueloPlaza", centro + Vector3.UP * 0.05,
		Vector3(48, 0.12, 38), _camino, false
	)

	_torre(padre, "FuenteBase", centro + Vector3.UP * 0.40, 3.3, 0.8, _piedra)
	_cilindro_ciudad(
		padre, "AguaFuente", centro + Vector3.UP * 0.82,
		2.8, 2.8, 0.10, _agua_fuente_ciudad
	)
	_torre(padre, "FuentePilar", centro + Vector3.UP * 1.8, 0.48, 2.1, _piedra_oscura)
	_cilindro_ciudad(
		padre, "FuenteCuenco", centro + Vector3.UP * 2.95,
		1.28, 0.45, 0.40, _piedra
	)

	_ornamentar_plaza(padre, centro)
	var indice := 0
	for fila: float in [-1.0, 1.0]:
		for desplazamiento_x: float in [-18.0, -6.0, 6.0, 18.0]:
			var pos := centro + Vector3(desplazamiento_x, 0, fila * 13.0)
			_puesto_ciudad(padre, pos, fila, indice)
			indice += 1


func _molino(casa: Node3D, tipo: Vector3i) -> void:
	var buje := Node3D.new()
	buje.name = "Aspas"
	buje.position = Vector3(0, tipo.z * 3.0 + 1.8, -tipo.y - 1.1)
	buje.rotation.z = 0.35
	casa.add_child(buje)
	for i in 4:
		var brazo := Node3D.new()
		brazo.rotation.z = i * PI / 2
		buje.add_child(brazo)
		_caja(brazo, "Mastil", Vector3(0, 2.35, 0), Vector3(0.15, 4.7, 0.19), _madera, false)
		_caja(brazo, "Vela", Vector3(0.44, 3.05, -0.02), Vector3(0.86, 3.1, 0.10), _adobe_claro_ciudad, false)


func _ornamentar_plaza(padre: Node3D, centro: Vector3) -> void:
	_cilindro_ciudad(padre, "AguaSuperior", centro + Vector3.UP * 3.15, 1.14, 1.14, 0.065, _agua_fuente_ciudad)
	# Ocho chorros trazan arcos desde la copa hasta el estanque.
	var chorros := SurfaceTool.new()
	chorros.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 8:
		var radial := Vector3(cos(i*TAU/8),0,sin(i*TAU/8))
		var lateral := radial.cross(Vector3.UP)
		for j in 12:
			var a := j / 12.0
			var b := (j+1) / 12.0
			var inicio := centro + radial * (1.10 + 1.35*a) + Vector3.UP*(3.15 + 0.85*a - 3.15*a*a)
			var fin := centro + radial * (1.10 + 1.35*b) + Vector3.UP*(3.15 + 0.85*b - 3.15*b*b)
			var eje := (fin-inicio).normalized().cross(lateral)
			for k in 5:
				var n := lateral*cos(TAU*k/5) + eje*sin(TAU*k/5)
				var m := lateral*cos(TAU*(k+1)/5) + eje*sin(TAU*(k+1)/5)
				for v: Vector3 in [inicio+n*0.065, fin+n*0.065, fin+m*0.065, inicio+n*0.065, fin+m*0.065, inicio+m*0.065]:
					chorros.set_normal((n+m).normalized())
					chorros.add_vertex(v)
	_agregar_malla(padre, "ChorrosFuente", chorros.commit(), _mat(Color("#8ad6e1")), false)
	# Los adoquines forman anillos concéntricos con juntas alternadas.
	var piedra := StandardMaterial3D.new()
	piedra.vertex_color_use_as_albedo = true
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for fila in 12:
		var r := 3.3 + fila * 0.60
		var pasos := ceili(TAU * r / 1.25)
		for i in pasos:
			var a := TAU * (i + 0.5 * (fila % 2)) / pasos
			var b := a + TAU / pasos - 0.004
			var u := Vector3(cos(a), 0, sin(a))
			var v := Vector3(cos(b), 0, sin(b))
			var tono := Color("#e6c689") if fila < 10 else Color("#aebbb9")
			for esquina: Vector3 in [u*r, u*(r+0.57), v*(r+0.57), u*r, v*(r+0.57), v*r]:
				st.set_normal(Vector3.UP)
				st.set_color(tono.darkened(0.03 * ((i + fila * 3) % 5)))
				st.add_vertex(centro + Vector3.UP * 0.17 + esquina)
	_agregar_malla(padre, "RosetonDeAdoquines", st.commit(), piedra, false)
	if not generar_decoracion:
		return
	var hojas: Array[Transform3D] = []
	var colores: Array[Color] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla + 29
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			var jardin := centro + Vector3(10.3 * sx, 0, 7.2 * sz)
			_cilindro_ciudad(padre, "Jardinera", jardin + Vector3.UP * 0.28, 1.85, 1.65, 0.48, _piedra)
			hojas.append(Transform3D(Basis.from_scale(Vector3(3.4, 1.1, 3.4)), jardin + Vector3.UP * 0.64))
			colores.append(Color("#41914b"))
			for flor in 48:
				var theta := rng.randf() * TAU
				var radio := sqrt(rng.randf()) * 1.55
				var centro_flor := jardin + Vector3(cos(theta)*radio, 0.73 + 0.50 * sqrt(1.0-pow(radio/1.7,2)), sin(theta)*radio)
				hojas.append(Transform3D(Basis.from_scale(Vector3(0.19,0.13,0.19)), centro_flor))
				colores.append(Color("#ffd45a") if flor % 3 else Color("#fff2dd"))
			var arbol := centro + Vector3(sx * 22, 0, sz * 8)
			_cilindro_ciudad(padre, "Tronco", arbol + Vector3.UP * 2, 0.22, 0.38, 4.0, _madera)
			for j in 6:
				var t := TAU * j / 5
				var offset := Vector3(1.25*cos(t),4.0+0.35*sin(2*t),1.25*sin(t)) if j < 5 else Vector3.UP * 5.8
				hojas.append(Transform3D(Basis.from_scale(Vector3(3.1,3.8,3.0)), arbol + offset))
				colores.append(Color("#39854a") if j % 2 else Color("#69a650"))
	var bola := SphereMesh.new()
	bola.radial_segments = 8
	bola.rings = 3
	bola.material = piedra
	var plantas := MultiMesh.new()
	plantas.transform_format = MultiMesh.TRANSFORM_3D
	plantas.use_colors = true
	plantas.mesh = bola
	plantas.instance_count = hojas.size()
	for j in hojas.size():
		plantas.set_instance_transform(j, hojas[j])
		plantas.set_instance_color(j, colores[j])
	var vegetacion := MultiMeshInstance3D.new()
	vegetacion.name = "ArbolesYFlores"
	vegetacion.multimesh = plantas
	padre.add_child(vegetacion)


func _puesto_ciudad(padre: Node3D, pos: Vector3, fila: float, indice: int) -> void:
	var puestos := ["Stall_Empty", "Stall_Cart_Empty", "Workbench_Drawers", "Table_Large"]
	var carga := ["FarmCrate_Apple", "FarmCrate_Carrot", "Anvil_Log", "Pot_1_Lid",
		"Barrel_Apples", "Crate_Wooden", "Whetstone", "Vase_4"]
	var apoyo := ["Bucket_Wooden_1", "Barrel", "Dummy", "Stool",
		"Bag", "Bench", "WeaponStand", "Chair_1"]
	var giro := 180.0 if fila > 0 else 0.0
	pos.y += 0.11
	colocar_modelo_ciudad(padre, MERCADO + puestos[indice % 4] + ".gltf", pos, 3.0 if indice % 4 >= 2 else 4.6, giro)
	if generar_decoracion:
		colocar_modelo_ciudad(padre, MERCADO + carga[indice] + ".gltf",
			pos + Vector3(2.95, 0, -fila * 0.7), 1.15, giro)
		colocar_modelo_ciudad(padre, MERCADO + apoyo[indice] + ".gltf",
			pos + Vector3(-3.15, 0, fila * 0.65), 1.35, giro)
		if indice % 2 == 0:
			var tienda: String = ["Tent_01", "Tent_02", "Tent_03", "Tent_04"][indice >> 1]
			colocar_modelo_ciudad(padre, CAMPAMENTO + tienda + ".prefab.scn",
				pos + Vector3(0, 0, fila * 4.1), 3.5, giro)


const CARRETA_PLAZA := "res://assets/medieval_village/Export/Prop_Wagon.gltf"
const COFRE_HABITACION := "res://assets/interior_zappypixel/Export/box.04_animation.glb"
const TIENDA_CAMPAMENTO := "res://AnimpicStudio/POLY - Medieval Camp/Prefabs/Tent_01.prefab.scn"


func generar_ciudad() -> void:
	_centro_cuarto = _habitacion_xz()
	super.generar_ciudad()

	if not is_node_ready() or not generar_decoracion:
		return

	# La capa Market se limpia en cada reconstrucción.
	var mercado := _capa("Market")
	if mercado == null:
		return

	# Carreta a un costado de la plaza, fuera de las filas de puestos.
	var carro_x := CENTRO_PLAZA.x - 27.0
	var carro_z := CENTRO_PLAZA.y + 5.0
	colocar_modelo_ciudad(
		mercado, CARRETA_PLAZA,
		Vector3(carro_x, _altura_desierto(carro_x, carro_z), carro_z),
		4.2, 75.0
	)

	# Tienda en el lado del desierto, dejando libre el eje de la puerta.
	var tienda_x := _entrada_x() - 23.0
	var tienda_z := 27.0
	colocar_modelo_ciudad(
		mercado, TIENDA_CAMPAMENTO,
		Vector3(tienda_x, _altura_desierto(tienda_x, tienda_z), tienda_z),
		5.0, -35.0
	)

	# Se usa la posición real del cuarto y la cara superior de su piso.
	var cuarto := get_parent().get_node_or_null("RecoveryRoom") as Node3D
	if cuarto != null:
		var piso := cuarto.get_node_or_null("Floor") as CSGBox3D
		if piso != null:
			var junto_a_cama := piso.to_global(
				Vector3(3.0, piso.size.y * 0.5, 2.0)
			)
			colocar_modelo_ciudad(
				mercado, COFRE_HABITACION,
				mercado.to_local(junto_a_cama), 1.25,
				rad_to_deg(cuarto.global_rotation.y - mercado.global_rotation.y)
			)


# Instancia el modelo, ajusta su tamaño y apoya su base en el punto indicado.
# "ancho" es la medida deseada del lado horizontal más largo, en metros.
func colocar_modelo_ciudad(
	padre: Node3D,
	ruta: String,
	punto: Vector3,
	ancho: float,
	giro_grados: float = 0.0
) -> bool:
	if not ResourceLoader.exists(ruta):
		push_warning("Falta el modelo de ciudad: " + ruta)
		return false

	var escena := load(ruta) as PackedScene
	if escena == null:
		return false

	var instancia := escena.instantiate()
	var modelo := instancia as Node3D
	if modelo == null:
		instancia.free()
		return false

	var soporte := Node3D.new()
	soporte.name = ruta.get_file().get_basename().validate_node_name()
	padre.add_child(soporte, true)
	soporte.add_child(modelo)

	# Algunos packs tienen el origen en el centro y otros en el suelo.
	# Medimos las mallas para que ambos queden apoyados a la misma altura.
	var piezas := modelo.find_children("*", "MeshInstance3D", true, false)
	if modelo is MeshInstance3D:
		piezas.append(modelo)

	var limites := AABB()
	var hay_malla := false
	var inversa := soporte.global_transform.affine_inverse()

	for nodo in piezas:
		var pieza := nodo as MeshInstance3D
		if pieza == null or pieza.mesh == null:
			continue
		var caja := (inversa * pieza.global_transform) * pieza.get_aabb()
		if hay_malla:
			limites = limites.merge(caja)
		else:
			limites = caja
			hay_malla = true

	var medida := maxf(limites.size.x, limites.size.z)
	if not hay_malla or medida < 0.001:
		soporte.free()
		return false

	var base := limites.get_center()
	base.y = limites.position.y
	modelo.position -= base
	soporte.scale = Vector3.ONE * (ancho / medida)
	soporte.rotation.y = deg_to_rad(giro_grados)
	soporte.position = punto
	return true
