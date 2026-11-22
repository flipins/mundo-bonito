@tool
extends "res://scripts/city/coastal_base.gd"


# Posición de la puerta sobre el camino que viene del desierto.
# Con un camino de 310 unidades, queda unas 170 unidades
# antes de donde estaba la antigua muralla.
func _entrada_x() -> float:
	return -145.0 - longitud_camino_llegada * 0.55


# PUERTA DE ENTRADA
# Dos torres y dos alas cortas. Los barrios se abren hacia las sierras.
func _crear_murallas() -> void:
	var padre := _capa("Walls")
	var x := _entrada_x()

	for lado: float in [-1.0, 1.0]:
		var z := 8.0 + lado * 13.0
		var extremo := Vector2(x, 8.0 + lado * 43.0)

		_segmento(
			padre, "AlaPuerta",
			Vector2(x, z), extremo,
			4.0, 8.5, _piedra
		)

		_torre(
			padre, "TorrePuerta",
			Vector3(x, 6.5, z),
			4.5, 13.0, _piedra
		)

	_segmento(
		padre, "DintelPuerta",
		Vector2(x, -5), Vector2(x, 21),
		4.0, 2.0, _piedra, 9.0
	)


# TERRENO DISPONIBLE PARA LAS CASAS
func _lote_valido(p: Vector2) -> bool:
	# La ciudad empieza al cruzar la puerta.
	if p.x < _entrada_x() + 16.0:
		return false

	# Deja libre la avenida desde la puerta hasta la plaza.
	if p.x < CENTRO_PLAZA.x and absf(p.y - 8.0) < 15.0:
		return false

	# Respeta la colina del castillo y la habitación del jugador.
	if p.distance_to(CENTRO_CASTILLO) < 52.0:
		return false

	if p.distance_to(_habitacion_xz()) < 22.0:
		return false

	# Reserva la plaza y el camino que baja al muelle.
	if absf(p.x - CENTRO_PLAZA.x) < 34.0 and absf(p.y - CENTRO_PLAZA.y) < 29.0:
		return false

	if _distancia_segmento(p, CENTRO_PLAZA, Vector2(72, 28)) < 14.0:
		return false

	# Las bodegas existentes están junto al puerto.
	if absf(p.x - 57.0) < 15.0 and p.y > -66.0 and p.y < -4.0:
		return false

	var rampa := PackedVector2Array([
		Vector2(-45, -10),
		Vector2(-39, -42),
		Vector2(-35, -78),
		Vector2(-62, -94),
		Vector2(-73, -63)
	])

	for i in range(rampa.size() - 1):
		if _distancia_segmento(p, rampa[i], rampa[i + 1]) < 13.0:
			return false

	# Comprueba el centro, los bordes y las esquinas de la parcela.
	# Así se pueden usar los laterales del valle sin poner media
	# casa dentro de la montaña o sobre la playa.
	var altura := _altura_desierto(p.x, p.y)

	for dx: float in [-8.0, 0.0, 8.0]:
		for dz: float in [-8.0, 0.0, 8.0]:
			var x := p.x + dx
			var z := p.y + dz

			if x >= _costa(z) - 12.0:
				return false

			if generar_montanas_v25 and absf(z) >= absf(_eje_sierra(x, signf(z))) - 28.0:
				return false

			if absf(_altura_desierto(x, z) - altura) > 0.55:
				return false

	return true


# DISTRIBUCIÓN DE LA CIUDAD
func _crear_barrio() -> void:
	var lotes: Array[Vector2] = []
	var limite_z := ceili(maxf(semiancho_valle_v25, 220.0))

	for x in range(ceili(_entrada_x() + 18.0), 160, 20):
		for z in range(-limite_z, limite_z + 1, 20):
			var p := Vector2(x, z)
			if _lote_valido(p):
				lotes.append(p)

	var cantidad := mini(cantidad_casas, lotes.size())
	if cantidad == 0:
		return

	# La primera ubicación depende de la semilla. Para cada casa
	# siguiente se elige el lote más alejado de las ya colocadas.
	# Así también se ocupan los extremos del valle.
	var distancias := PackedFloat32Array()
	distancias.resize(lotes.size())
	distancias.fill(INF)

	var indice := _rng.randi_range(0, lotes.size() - 1)

	for numero in range(cantidad):
		var elegido := lotes[indice]
		_crear_casa(numero, elegido)

		var casa := _capa("Buildings").get_node("Casa_%03d" % numero) as Node3D
		casa.position.y = _altura_desierto(elegido.x, elegido.y)

		# El cimiento cubre pequeñas diferencias de altura en las dunas.
		var cuerpo := casa.get_node("Cuerpo") as MeshInstance3D
		var medidas := (cuerpo.mesh as BoxMesh).size
		_caja(
			casa, "Cimiento",
			Vector3(0, -0.5, 0),
			Vector3(medidas.x, 1, medidas.z),
			_piedra_oscura, false
		)

		var mayor := -1.0
		for i in range(lotes.size()):
			distancias[i] = minf(
				distancias[i],
				lotes[i].distance_squared_to(elegido)
			)
			if distancias[i] > mayor:
				mayor = distancias[i]
				indice = i

	print("Casas generadas: ", cantidad)
