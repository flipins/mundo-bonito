@tool
extends "res://scripts/city/coastal_base.gd"

# Distancia entre el eje de la sierra y el muro lateral (queda al pie de la ladera).
const DISTANCIA_MURO_SIERRA := 44.0


# Posición de la puerta sobre el camino que viene del desierto.
# Con un camino de 310 unidades, queda unas 170 unidades
# antes de donde estaba la antigua muralla.
func _entrada_x() -> float:
	return -145.0 - longitud_camino_llegada * 0.55


# MURALLAS
# 1) Muralla de entrada: cierra el valle de sierra a sierra con la puerta en
#    el centro y sube por las laderas hasta perderse en la montaña.
# 2) Murallas laterales: salen de la entrada y corren al pie de cada sierra
#    hasta la costa, así la ciudad queda completamente rodeada.
func _crear_murallas() -> void:
	var padre := _capa("Walls")
	var x := _entrada_x()
	var altura_muro := 18.0
	var grosor := 6.0
	var almenas: Array[Transform3D] = []

	# Torres de la puerta, enormes.
	for lado: float in [-1.0, 1.0]:
		var z := 8.0 + lado * 17.5
		var suelo := _altura_desierto(x, z)
		_crear_torre_muralla(
			padre, almenas, Vector3(x, suelo, z), 14.0, 28.0,
			"TorrePuerta" + ("Sur" if lado > 0.0 else "Norte")
		)

	# Dintel sobre la puerta (14 m libres de altura), con almenas.
	var suelo_puerta := _altura_desierto(x, 8.0)
	_segmento(
		padre, "DintelPuerta", Vector2(x, -5), Vector2(x, 21),
		6.0, 5.0, _muro, suelo_puerta + 14.0
	)
	_agregar_almenas(almenas, Vector2(x, -5), Vector2(x, 21), suelo_puerta + 20.2, 2.2, 4.0)
	_agregar_almenas(almenas, Vector2(x, -5), Vector2(x, 21), suelo_puerta + 20.2, -2.2, 4.0)

	for lado: float in [-1.0, 1.0]:
		var nombre := "Sur" if lado > 0.0 else "Norte"

		# Ala de la entrada hacia la sierra (la torre de la puerta ya existe).
		_construir_muro(
			padre, almenas, _puntos_muralla(x, lado),
			"Muralla" + nombre, altura_muro, grosor, false, true
		)

		# Muro lateral al pie de la sierra, hasta la costa.
		var numero := 0
		for puntos in _tramos_muralla_lateral(lado):
			_construir_muro(
				padre, almenas, puntos,
				"MurallaLateral%s%d" % [nombre, numero],
				altura_muro, grosor, true, true
			)
			numero += 1

	_crear_almenas(padre, almenas)


# Construye un muro completo sobre una lista de puntos: zócalo, cuerpo,
# almenas a ambos lados y torres (cada ~40 m y en los extremos que se pidan).
func _construir_muro(
	padre: Node3D,
	almenas: Array[Transform3D],
	puntos: Array[Vector3],
	nombre: String,
	altura_muro: float,
	grosor: float,
	torre_inicio: bool,
	torre_final: bool
) -> void:
	if puntos.size() < 2:
		return

	_agregar_malla(
		padre, "Zocalo" + nombre,
		_prisma_muro(puntos, (grosor + 2.0) * 0.5, -2.0, 3.0),
		_muro, false
	)
	_agregar_malla(
		padre, nombre,
		_prisma_muro(puntos, grosor * 0.5, -6.0, altura_muro),
		_muro, true
	)

	var desplazamiento := grosor * 0.5 - 0.8
	for i in range(puntos.size() - 1):
		_agregar_almenas_pendiente(
			almenas, puntos[i], puntos[i + 1],
			altura_muro + 1.2, desplazamiento, 4.0
		)
		_agregar_almenas_pendiente(
			almenas, puntos[i], puntos[i + 1],
			altura_muro + 1.2, -desplazamiento, 4.0
		)

	var ultimo := puntos.size() - 1
	for i in range(puntos.size()):
		var cada_cuatro := i > 0 and i % 4 == 0 and ultimo - i >= 2
		var inicio := i == 0 and torre_inicio
		var final := i == ultimo and torre_final
		if cada_cuatro or inicio or final:
			_crear_torre_muralla(
				padre, almenas, puntos[i], 10.0, 24.0,
				"Torre%s%d" % [nombre, i]
			)


# Puntos del eje del ala de entrada, cada 10 m, desde la torre de la puerta
# hasta que la ladera es lo bastante alta (y pasa de la barrera de la sierra).
func _puntos_muralla(x: float, lado: float) -> Array[Vector3]:
	var puntos: Array[Vector3] = []
	var z := 8.0 + lado * 17.5
	puntos.append(Vector3(x, _altura_desierto(x, z), z))

	for paso in range(60):
		z += lado * 10.0
		var h := _altura_desierto(x, z)
		puntos.append(Vector3(x, h, z))

		var eje := absf(_eje_sierra(x, lado))
		var llegado := absf(z) >= eje - 8.0 and (h > 30.0 or absf(z) >= eje + 10.0)
		if llegado or absf(z) > 260.0:
			break

	return puntos


# Puntos del muro lateral: sigue el pie de la sierra desde la entrada hasta
# la costa, un punto cada 10 m.
func _puntos_muralla_lateral(lado: float) -> Array[Vector3]:
	var puntos: Array[Vector3] = []
	var x := _entrada_x()

	for paso in range(100):
		var z := lado * (absf(_eje_sierra(x, lado)) - DISTANCIA_MURO_SIERRA)
		puntos.append(Vector3(x, _altura_desierto(x, z), z))
		if x >= _costa(z) - 16.0:
			break
		x += 10.0

	return puntos


# Divide el muro lateral en tramos, dejando un hueco frente a la puerta del
# castillo de montaña para que el camino pueda pasar.
func _tramos_muralla_lateral(lado: float) -> Array:
	var tramos: Array = []
	var actual: Array[Vector3] = []
	var hay_hueco := (
		generar_castillo_montana
		and generar_montanas_v25
		and signf(lado) == signf(lado_castillo_montana)
	)

	for p in _puntos_muralla_lateral(lado):
		if hay_hueco and absf(p.x - x_castillo_montana) < 14.0:
			if actual.size() >= 2:
				tramos.append(actual)
			actual = []
			continue
		actual.append(p)

	if actual.size() >= 2:
		tramos.append(actual)
	return tramos


# Cara de muro con el sentido de giro correcto: `saliente` es hacia donde
# debe mirar la cara.
func _cara_muro(
	st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
	saliente: Vector3
) -> void:
	if (b - a).cross(c - a).dot(saliente) > 0.0:
		var temporal := b
		b = d
		d = temporal
	_cara_puerto(st, a, b, c, d)


# Prisma que recorre los puntos en cualquier dirección (muro con la cara
# vertical y la corona siguiendo el terreno). abajo y arriba son alturas
# relativas al suelo.
func _prisma_muro(
	puntos: Array[Vector3], semiancho: float, abajo: float, arriba: float
) -> ArrayMesh:
	if puntos.size() < 2:
		return null

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var bajo := Vector3.UP * abajo
	var alto := Vector3.UP * arriba

	# Vector lateral en cada punto, perpendicular a la dirección del muro.
	var laterales: Array[Vector3] = []
	for i in range(puntos.size()):
		var previo := puntos[maxi(i - 1, 0)]
		var siguiente := puntos[mini(i + 1, puntos.size() - 1)]
		var t := Vector3(siguiente.x - previo.x, 0.0, siguiente.z - previo.z).normalized()
		laterales.append(Vector3(-t.z, 0.0, t.x) * semiancho)

	for i in range(puntos.size() - 1):
		var p := puntos[i]
		var q := puntos[i + 1]
		var lp := laterales[i]
		var lq := laterales[i + 1]

		var bl_p := p - lp + bajo
		var br_p := p + lp + bajo
		var tl_p := p - lp + alto
		var tr_p := p + lp + alto
		var bl_q := q - lq + bajo
		var br_q := q + lq + bajo
		var tl_q := q - lq + alto
		var tr_q := q + lq + alto

		_cara_muro(st, tl_p, tr_p, tr_q, tl_q, Vector3.UP)
		_cara_muro(st, bl_p, tl_p, tl_q, bl_q, -lp.normalized())
		_cara_muro(st, br_p, br_q, tr_q, tr_p, lp.normalized())

	# Tapas en los dos extremos.
	var ultimo := puntos.size() - 1
	var dir_inicio := Vector3(
		puntos[1].x - puntos[0].x, 0.0, puntos[1].z - puntos[0].z
	).normalized()
	var dir_final := Vector3(
		puntos[ultimo].x - puntos[ultimo - 1].x, 0.0,
		puntos[ultimo].z - puntos[ultimo - 1].z
	).normalized()

	var e0 := puntos[0]
	var l0 := laterales[0]
	_cara_muro(
		st, e0 - l0 + bajo, e0 + l0 + bajo, e0 + l0 + alto, e0 - l0 + alto,
		-dir_inicio
	)
	var e1 := puntos[ultimo]
	var l1 := laterales[ultimo]
	_cara_muro(
		st, e1 - l1 + bajo, e1 + l1 + bajo, e1 + l1 + alto, e1 - l1 + alto,
		dir_final
	)

	st.generate_normals()
	return st.commit()


# Torre cuadrada apoyada en el suelo, con cimiento hundido 6 m, cornisa
# saliente y almenas.
func _crear_torre_muralla(
	padre: Node3D,
	almenas: Array[Transform3D],
	base: Vector3,
	lado: float,
	alto: float,
	nombre: String
) -> void:
	_caja(
		padre, nombre,
		Vector3(base.x, base.y + (alto - 6.0) * 0.5, base.z),
		Vector3(lado, alto + 6.0, lado), _muro
	)

	# Cornisa que sobresale en lo alto de la torre.
	_caja(
		padre, nombre + "Cornisa",
		Vector3(base.x, base.y + alto + 0.3, base.z),
		Vector3(lado + 2.0, 0.8, lado + 2.0), _muro, false
	)

	var h := lado * 0.5
	var centro := Vector2(base.x, base.z)
	var esquinas: Array[Vector2] = [
		centro + Vector2(-h, -h), centro + Vector2(h, -h),
		centro + Vector2(h, h), centro + Vector2(-h, h)
	]
	for j in range(4):
		_agregar_almenas(
			almenas, esquinas[j], esquinas[(j + 1) % 4],
			base.y + alto + 2.0, 0.0, 3.6
		)


# Como _agregar_almenas, pero entre dos puntos 3D (sigue la pendiente).
func _agregar_almenas_pendiente(
	lista: Array[Transform3D],
	a: Vector3,
	b: Vector3,
	elevacion: float,
	desplazamiento: float,
	paso: float
) -> void:
	var d := b - a
	var plano := Vector2(d.x, d.z)
	if plano.length() < 1.0:
		return

	var u := plano.normalized()
	var perpendicular := Vector2(-u.y, u.x)
	var orientacion := Basis.looking_at(d.normalized(), Vector3.UP)
	var cantidad := maxi(1, int(d.length() / paso))

	for k in range(cantidad):
		var t := (float(k) + 0.5) / float(cantidad)
		var punto := a.lerp(b, t)
		var posicion := Vector3(
			punto.x + perpendicular.x * desplazamiento,
			punto.y + elevacion,
			punto.z + perpendicular.y * desplazamiento
		)
		lista.append(Transform3D(orientacion, posicion))


# CASTILLO DE MONTAÑA
# Se añade al castillo de la colina. La meseta plana la prepara coastal_base.gd.
# Todo escala con radio_meseta (44 = tamaño por defecto).

func _crear_castillo() -> void:
	super._crear_castillo()
	if generar_castillo_montana and generar_montanas_v25:
		_crear_castillo_montana()


func _cono(
	padre: Node3D, nombre: String, pos: Vector3, radio: float, alto: float
) -> void:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = radio
	m.height = alto

	var n := MeshInstance3D.new()
	n.name = nombre
	n.mesh = m
	n.position = pos
	n.material_override = _teja
	padre.add_child(n)


func _crear_castillo_montana() -> void:
	if not _meseta_lista:
		_preparar_meseta()

	var padre := _capa("Castle")
	var c := _meseta_xz
	var y := _meseta_y
	var k := radio_meseta / 26.0
	var r := radio_meseta * 0.8
	var alt := 13.0 * k
	var grosor := 3.5 * k
	var entierro := 5.0
	var hueco := 3.5 * k
	var almenas: Array[Transform3D] = []
	var lados := 8
	var hacia_valle := Vector2(0.0, -lado_castillo_montana)

	var esq: Array[Vector2] = []
	for i in range(lados):
		var ang := TAU * float(i) / float(lados) + TAU / 16.0
		esq.append(c + Vector2(cos(ang), sin(ang)) * r)

	# La puerta va en el muro que mira al valle.
	var puerta := 0
	var mejor := -2.0
	for i in range(lados):
		var medio := ((esq[i] + esq[(i + 1) % lados]) * 0.5 - c).normalized()
		if medio.dot(hacia_valle) > mejor:
			mejor = medio.dot(hacia_valle)
			puerta = i

	var puerta_a := esq[puerta]
	var puerta_b := esq[(puerta + 1) % lados]
	var puerta_m := (puerta_a + puerta_b) * 0.5
	var puerta_u := (puerta_b - puerta_a).normalized()

	# Muros del recinto (el de la puerta se parte en dos con un dintel).
	for i in range(lados):
		var a := esq[i]
		var b := esq[(i + 1) % lados]
		var tramos: Array = [[a, b]]
		if i == puerta:
			tramos = [
				[a, puerta_m - puerta_u * hueco],
				[puerta_m + puerta_u * hueco, b]
			]
			_segmento(
				padre, "DintelCastilloMonte",
				puerta_m - puerta_u * hueco, puerta_m + puerta_u * hueco,
				grosor, alt * 0.4, _muro, y + alt * 0.6
			)
			_agregar_almenas(
				almenas, puerta_m - puerta_u * hueco, puerta_m + puerta_u * hueco,
				y + alt + 1.2, grosor * 0.5 - 0.8, 4.0
			)
			_agregar_almenas(
				almenas, puerta_m - puerta_u * hueco, puerta_m + puerta_u * hueco,
				y + alt + 1.2, -(grosor * 0.5 - 0.8), 4.0
			)
		for t in range(tramos.size()):
			var p: Vector2 = tramos[t][0]
			var q: Vector2 = tramos[t][1]
			_segmento(
				padre, "MuroCastilloMonte_%d_%d" % [i, t], p, q,
				grosor, alt + entierro, _muro, y - entierro
			)
			_agregar_almenas(almenas, p, q, y + alt + 1.2, grosor * 0.5 - 0.8, 4.0)
			_agregar_almenas(almenas, p, q, y + alt + 1.2, -(grosor * 0.5 - 0.8), 4.0)

	# Torres redondas en las esquinas, con cornisa y techo cónico.
	var radio_torre := 4.4 * k
	var sobre := 8.0 * k
	var alto_torre := alt + sobre + entierro
	for i in range(lados):
		var pt := esq[i]
		_torre(
			padre, "TorreCastilloMonte_%d" % i,
			Vector3(pt.x, y - entierro + alto_torre * 0.5, pt.y),
			radio_torre, alto_torre, _muro
		)
		_torre(
			padre, "CornisaCastilloMonte_%d" % i,
			Vector3(pt.x, y + alt + sobre + 0.4, pt.y),
			radio_torre * 1.2, 0.8, _piedra_oscura
		)
		_cono(
			padre, "TechoCastilloMonte_%d" % i,
			Vector3(pt.x, y + alt + sobre + 0.8 + 4.0 * k, pt.y),
			radio_torre * 1.3, 8.0 * k
		)

	# Dos torres cuadradas custodian la puerta.
	for lado: float in [-1.0, 1.0]:
		var pos := puerta_m + puerta_u * lado * (hueco + 4.5 * k)
		_crear_torre_muralla(
			padre, almenas, Vector3(pos.x, y, pos.y),
			8.0 * k, alt + 6.0 * k, "TorrePuertaCastilloMonte%d" % int(lado)
		)

	# Torre del homenaje en el centro, con una torre más alta y techo cónico.
	var ancho_h := 14.0 * k
	var alto_h := 26.0 * k
	_caja(
		padre, "HomenajeMonte",
		Vector3(c.x, y + alto_h * 0.5 - 1.0, c.y),
		Vector3(ancho_h, alto_h + 2.0, ancho_h), _muro
	)
	_caja(
		padre, "TorreAltaMonte",
		Vector3(c.x + 3.0 * k, y + alto_h + 6.0 * k, c.y),
		Vector3(7.0 * k, 12.0 * k, 7.0 * k), _piedra_oscura
	)
	_cono(
		padre, "TechoTorreAltaMonte",
		Vector3(c.x + 3.0 * k, y + alto_h + 12.0 * k + 5.0 * k, c.y),
		6.0 * k, 10.0 * k
	)

	var h := ancho_h * 0.5 - 0.8
	var cuadro: Array[Vector2] = [
		c + Vector2(-h, -h), c + Vector2(h, -h), c + Vector2(h, h), c + Vector2(-h, h)
	]
	for j in range(4):
		_agregar_almenas(
			almenas, cuadro[j], cuadro[(j + 1) % 4], y + alto_h + 1.2, 0.0, 4.0
		)

	_crear_almenas(padre, almenas)

	# Camino desde el valle hasta la puerta, siguiendo el terreno.
	var inicio := Vector2(puerta_m.x, lado_castillo_montana * 70.0)
	var pasos := ceili(inicio.distance_to(puerta_m) / 6.0)
	var previo := Vector3.ZERO
	for n in range(pasos + 1):
		var p2 := inicio.lerp(puerta_m, float(n) / float(pasos))
		var punto := Vector3(p2.x, _altura_desierto(p2.x, p2.y) + 0.15, p2.y)
		if n > 0:
			_bloque_entre(
				padre, "CaminoCastilloMonte_%d" % n, previo, punto,
				7.0, 0.4, _camino, false
			)
		previo = punto


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
	# Deja libre la franja del muro lateral al pie de las sierras.
	var altura := _altura_desierto(p.x, p.y)

	for dx: float in [-8.0, 0.0, 8.0]:
		for dz: float in [-8.0, 0.0, 8.0]:
			var x := p.x + dx
			var z := p.y + dz

			if x >= _costa(z) - 12.0:
				return false

			if generar_montanas_v25 and absf(z) >= absf(_eje_sierra(x, signf(z))) - (DISTANCIA_MURO_SIERRA + 10.0):
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
