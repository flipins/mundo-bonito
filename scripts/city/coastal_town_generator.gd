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

func _crear_casa(numero: int, posicion: Vector2) -> void:
	var casa := Node3D.new()
	casa.name = "Casa_%03d" % numero
	casa.position = Vector3(posicion.x, 0.0, posicion.y)

	var hacia := CENTRO_PLAZA - posicion
	var giro := roundf(atan2(hacia.x, hacia.y) / (PI * 0.5)) * (PI * 0.5)
	casa.rotation.y = giro + float(_rng.randi_range(-1, 1)) * 0.12
	_capa("Buildings").add_child(casa)

	var ancho := _rng.randf_range(9.0, 11.5)
	var largo := _rng.randf_range(9.0, 12.0)
	var alto := _rng.randf_range(5.4, 7.1)
	var tipo := _rng.randf()

	if tipo < 0.45:
		_caja(
			casa, "Cuerpo", Vector3(0, alto * 0.5, 0),
			Vector3(ancho, alto, largo), _adobe_ciudad
		)
		_azotea_ciudad(casa, ancho, largo, alto)
	elif tipo < 0.75:
		_caja(
			casa, "Cuerpo", Vector3(0, alto * 0.5, 0),
			Vector3(ancho, alto, largo), _piedra
		)
		_crear_techo(casa, "Tejado", Vector3.UP * alto, ancho, largo, 2.8)
		_caja(
			casa, "Chimenea", Vector3(ancho * 0.23, alto + 2.1, -largo * 0.18),
			Vector3(0.9, 2.8, 0.9), _piedra_oscura, false
		)
	else:
		_caja(
			casa, "Cuerpo", Vector3(0, alto * 0.5, 0),
			Vector3(ancho, alto, largo), _adobe_claro_ciudad
		)
		_crear_techo(casa, "Tejado", Vector3.UP * alto, ancho, largo, 3.2)
		_entramado_ciudad(casa, ancho, largo, alto)

	_fachada_ciudad(casa, ancho, largo, alto)

	if generar_decoracion:
		_decoracion_casa_ciudad(casa, ancho, largo, numero)


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

	var indice := 0
	for fila: float in [-1.0, 1.0]:
		for desplazamiento_x: float in [-18.0, -6.0, 6.0, 18.0]:
			var pos := centro + Vector3(desplazamiento_x, 0, fila * 13.0)
			_puesto_ciudad(padre, pos, fila, indice)
			indice += 1


func _puesto_ciudad(padre: Node3D, pos: Vector3, fila: float, indice: int) -> void:
	var tela: Material = _tela_roja
	if indice % 3 == 1:
		tela = _tela_ocre
	elif indice % 3 == 2:
		tela = _tela_azul

	_caja(
		padre, "Mostrador", pos + Vector3.UP * 0.65,
		Vector3(4.2, 1.3, 2.8), _madera, false
	)

	var toldo := _caja(
		padre, "Toldo", pos + Vector3.UP * 3.10,
		Vector3(5.2, 0.16, 3.9), tela, false
	)
	toldo.rotation.x = -fila * 0.12

	for dx: float in [-2.3, 2.3]:
		for dz: float in [-1.65, 1.65]:
			_caja(
				padre, "PostePuesto", pos + Vector3(dx, 1.52, dz),
				Vector3(0.16, 3.04, 0.16), _madera, false
			)

	if generar_decoracion:
		if indice % 2 == 0:
			_vasija_ciudad(padre, pos + Vector3(0.9, 1.30, 0))
		else:
			_barril_ciudad(padre, pos + Vector3(2.9, 0, 0))
