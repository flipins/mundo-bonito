@tool
extends RefCounted

const TAM := 128
static var _cache: Dictionary = {}


static func _hash(x: int, y: int, semilla: int) -> float:
	var h := (x * 374761393 + y * 668265263 + semilla * 982451653) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h & 0xffff) / 65535.0


static func _ruido(u: float, v: float, celdas: int, semilla: int) -> float:
	var fx := u * celdas
	var fy := v * celdas
	var x := floori(fx)
	var y := floori(fy)
	var tx := smoothstep(0.0, 1.0, fx - x)
	var ty := smoothstep(0.0, 1.0, fy - y)

	var a := _hash(posmod(x, celdas), posmod(y, celdas), semilla)
	var b := _hash(posmod(x + 1, celdas), posmod(y, celdas), semilla)
	var c := _hash(posmod(x, celdas), posmod(y + 1, celdas), semilla)
	var d := _hash(posmod(x + 1, celdas), posmod(y + 1, celdas), semilla)

	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


static func _tono(base: Color, factor: float) -> Color:
	return Color(
		clampf(base.r * factor, 0.0, 1.0),
		clampf(base.g * factor, 0.0, 1.0),
		clampf(base.b * factor, 0.0, 1.0)
	)


static func _imagen(tamano: int) -> Image:
	return Image.create_empty(tamano, tamano, false, Image.FORMAT_RGBA8)


static func _material(
	color: Image,
	altura: Image,
	escala: float,
	rugosidad: float,
	relieve: float
) -> StandardMaterial3D:
	altura.bump_map_to_normal_map(relieve)
	color.generate_mipmaps()
	altura.generate_mipmaps()

	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(color)
	material.normal_enabled = true
	material.normal_texture = ImageTexture.create_from_image(altura)
	material.roughness = rugosidad
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * escala
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


static func piedra(base: Color, escala: float = 0.22) -> StandardMaterial3D:
	var clave := "piedra/%s/%s" % [base, escala]
	if _cache.has(clave):
		return _cache[clave] as StandardMaterial3D

	var tam := 256
	var color := _imagen(tam)
	var altura := _imagen(tam)

	for y in range(tam):
		var fila := floori(y / 32.0)
		for x in range(tam):
			var xx := (x + (fila % 2) * 32) % tam
			var columna := floori(xx / 64.0)
			var lx := xx % 64
			var ly := y % 32

			if lx < 2 or ly < 2:
				color.set_pixel(x, y, _tono(base, 0.42))
				altura.set_pixel(x, y, Color.BLACK)
				continue

			var u := float(x) / tam
			var v := float(y) / tam
			var bloque := 0.84 + _hash(columna, fila, 7) * 0.30
			var mancha := 0.88 + _ruido(u, v, 6, 11) * 0.24
			var grano := 0.95 + _hash(x, y, 3) * 0.10
			color.set_pixel(x, y, _tono(base, bloque * mancha * grano))

			var borde := mini(mini(lx, 64 - lx), mini(ly, 32 - ly))
			var h := clampf(borde / 6.0, 0.0, 1.0) * 0.55
			h += _ruido(u, v, 16, 5) * 0.35 + _hash(x, y, 9) * 0.10
			altura.set_pixel(x, y, Color(h, h, h))

	var resultado := _material(color, altura, escala, 0.95, 5.0)
	_cache[clave] = resultado
	return resultado


static func adobe(base: Color, escala: float = 0.16) -> StandardMaterial3D:
	var clave := "adobe/%s/%s" % [base, escala]
	if _cache.has(clave):
		return _cache[clave] as StandardMaterial3D

	var color := _imagen(TAM)
	var altura := _imagen(TAM)

	for y in range(TAM):
		for x in range(TAM):
			var u := float(x) / TAM
			var v := float(y) / TAM
			var grande := 0.86 + _ruido(u, v, 4, 21) * 0.28
			var medio := 0.94 + _ruido(u, v, 12, 22) * 0.12
			var grano := 0.97 + _hash(x, y, 23) * 0.06
			color.set_pixel(x, y, _tono(base, grande * medio * grano))

			var h := _ruido(u, v, 8, 24) * 0.6 + _ruido(u, v, 24, 25) * 0.4
			altura.set_pixel(x, y, Color(h, h, h))

	var resultado := _material(color, altura, escala, 0.97, 2.5)
	_cache[clave] = resultado
	return resultado


static func teja(base: Color, escala: float = 0.30) -> StandardMaterial3D:
	var clave := "teja/%s/%s" % [base, escala]
	if _cache.has(clave):
		return _cache[clave] as StandardMaterial3D

	var color := _imagen(TAM)
	var altura := _imagen(TAM)

	for y in range(TAM):
		var fila := floori(y / 16.0)
		for x in range(TAM):
			var xx := (x + (fila % 2) * 16) % TAM
			var columna := floori(xx / 32.0)
			var perfil := sin(float(xx % 32) / 32.0 * PI)
			var solape := smoothstep(0.0, 0.35, float(y % 16) / 16.0)
			var sombra := (0.55 + 0.45 * perfil) * (0.70 + 0.30 * solape)
			var tono := 0.80 + _hash(columna, fila, 31) * 0.38
			var suciedad := 0.88 + _ruido(float(x) / TAM, float(y) / TAM, 5, 35) * 0.24
			color.set_pixel(x, y, _tono(base, sombra * tono * suciedad))

			var h := perfil * 0.70 + solape * 0.30
			altura.set_pixel(x, y, Color(h, h, h))

	var resultado := _material(color, altura, escala, 0.90, 6.0)
	_cache[clave] = resultado
	return resultado


static func madera(base: Color, escala: float = 0.35) -> StandardMaterial3D:
	var clave := "madera/%s/%s" % [base, escala]
	if _cache.has(clave):
		return _cache[clave] as StandardMaterial3D

	var color := _imagen(TAM)
	var altura := _imagen(TAM)

	for y in range(TAM):
		for x in range(TAM):
			if x % 32 < 2:
				color.set_pixel(x, y, _tono(base, 0.35))
				altura.set_pixel(x, y, Color.BLACK)
				continue

			var tabla := floori(x / 32.0)
			var ruido := _ruido(float(x) / TAM, float(y) / TAM, 6, 41 + tabla)
			var veta := sin(x * 0.55 + ruido * 9.0 + tabla * 3.0)
			var tono := 0.80 + _hash(tabla, 0, 43) * 0.35
			var grano := 0.96 + _hash(x, y, 45) * 0.08
			color.set_pixel(x, y, _tono(base, tono * (0.88 + 0.12 * veta) * grano))

			var h := 0.5 + 0.5 * veta
			altura.set_pixel(x, y, Color(h, h, h))

	var resultado := _material(color, altura, escala, 0.88, 3.0)
	_cache[clave] = resultado
	return resultado


static func empedrado(
	base: Color, arena: Color, escala: float = 0.12
) -> StandardMaterial3D:
	var clave := "empedrado/%s/%s/%s" % [base, arena, escala]
	if _cache.has(clave):
		return _cache[clave] as StandardMaterial3D

	var color := _imagen(TAM)
	var altura := _imagen(TAM)
	var celdas := 8
	var tam_celda := float(TAM) / celdas
	var puntos := PackedVector2Array()

	for j in range(celdas):
		for i in range(celdas):
			var px := i + 0.15 + _hash(i, j, 51) * 0.7
			var py := j + 0.15 + _hash(i, j, 52) * 0.7
			puntos.append(Vector2(px, py) * tam_celda)

	for y in range(TAM):
		for x in range(TAM):
			var p := Vector2(x, y)
			var cx := floori(x / tam_celda)
			var cy := floori(y / tam_celda)
			var d1 := INF
			var d2 := INF
			var piedra_id := 0

			for dj in range(-1, 2):
				for di in range(-1, 2):
					var ii := posmod(cx + di, celdas)
					var jj := posmod(cy + dj, celdas)
					var indice := jj * celdas + ii
					var q := puntos[indice]
					q += Vector2(cx + di - ii, cy + dj - jj) * tam_celda
					var dist := p.distance_to(q)

					if dist < d1:
						d2 = d1
						d1 = dist
						piedra_id = indice
					elif dist < d2:
						d2 = dist

			var forma := clampf((d2 - d1) / 5.0, 0.0, 1.0)
			var grano := 0.94 + _hash(x, y, 53) * 0.12

			if forma < 0.25:
				color.set_pixel(x, y, _tono(arena, 0.85 * grano))
			else:
				var tono := 0.72 + _hash(piedra_id, 1, 54) * 0.50
				var sombra := 0.80 + 0.20 * forma
				color.set_pixel(x, y, _tono(base, tono * sombra * grano))

			var h := forma * 0.8 + _hash(x, y, 56) * 0.08
			altura.set_pixel(x, y, Color(h, h, h))

	var resultado := _material(color, altura, escala, 0.96, 6.0)
	_cache[clave] = resultado
	return resultado
