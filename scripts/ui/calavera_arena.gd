@tool
extends Node3D
## Calavera gigante con cuernos y púas que mira hacia la arena de combate.
## Se apoya sobre la pared de dunas que cierra el fondo del valle, justo detrás del claro de pelea.
## La crea dunas.gd (opción "Con Calavera"); no hace falta añadirla a mano.
## Guardar como: res://scripts/world/calavera_arena.gd
## Todo son formas simples: luego puedes reemplazarla por un modelo 3D propio.
## No tiene colisión: queda fuera del alcance del jugador, detrás de la pared de dunas.

## Tamaño de toda la calavera (1.0 = unos 22 m de ancho de cráneo y unos 38 m con los cuernos).
const ESCALA := 1.0
## Metros que sube la pared de dunas al cierre (el mismo valor que ANCHO_CIERRE de dunas.gd).
const ANCHO_CIERRE := 16.0
## Metros detrás de donde termina de subir la pared. Menos = más cerca de la arena.
const SEPARACION := 3.0
## Cuánto se hunde la mandíbula en la arena, en metros.
const HUNDIDO := 0.5

var _terreno
var _hueso: StandardMaterial3D
var _cuerno: StandardMaterial3D
var _pua: StandardMaterial3D
var _oscuro: StandardMaterial3D


func construir(terreno) -> void:
	_terreno = terreno
	_crear_materiales()

	# Va justo detrás de la pared de dunas, centrada con la arena.
	var avance: float = terreno.distancia_arena + terreno.radio_arena + terreno.transicion_arena * 0.5 \
			+ ANCHO_CIERRE + SEPARACION
	# Que no se salga del borde del terreno (la calavera tiene unos 12 m de fondo).
	avance = minf(avance, terreno.tamano * 0.5 - 16.0)
	var x: float = terreno.centro_valle(terreno.distancia_arena)
	var z: float = -avance

	# Se apoya en la parte más baja del terreno que ocupa, para no quedar flotando.
	var suelo: float = INF
	for dx in [-12.0, 0.0, 12.0]:
		for dz in [-8.0, 0.0, 8.0]:
			suelo = minf(suelo, terreno.altura_base(x + dx, z + dz))
	position = Vector3(x, suelo - HUNDIDO * ESCALA, z)
	scale = Vector3.ONE * ESCALA
	# La cara mira hacia +Z, o sea, hacia el inicio del valle y la arena.

	_craneo()
	_rostro()
	_dientes()
	_cuernos()
	_puas()


# ------------------------------------------------------------------------------------
# Materiales
# ------------------------------------------------------------------------------------

func _crear_materiales() -> void:
	var ruido := FastNoiseLite.new()
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.frequency = 0.04
	ruido.fractal_octaves = 4
	var normal := NoiseTexture2D.new()
	normal.noise = ruido
	normal.seamless = true
	normal.as_normal_map = true
	normal.bump_strength = 8.0
	normal.width = 256
	normal.height = 256
	_hueso = _material(Color(0.80, 0.78, 0.72), 0.9, normal, 0.12)
	_cuerno = _material(Color(0.36, 0.30, 0.25), 1.0, normal, 0.2)
	_pua = _material(Color(0.33, 0.31, 0.30), 0.6, normal, 0.2)
	# Las cuencas de los ojos, la nariz y la boca: casi negro, sin brillo.
	_oscuro = _material(Color(0.012, 0.010, 0.010), 1.0, null, 1.0)


func _material(color: Color, rugosidad: float, normal: Texture2D, escala: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rugosidad
	if normal != null:
		m.normal_enabled = true
		m.normal_texture = normal
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * escala
	return m


# ------------------------------------------------------------------------------------
# Cráneo, rostro y dientes (coordenadas locales: y = 0 es la base de la mandíbula)
# ------------------------------------------------------------------------------------

func _craneo() -> void:
	# Bóveda del cráneo.
	_esfera(1.0, Vector3(11.0, 10.0, 11.5), Vector3(0.0, 17.0, 0.0), _hueso)
	# Parte de atrás, un poco más baja, para que se vea hondo desde los lados.
	_esfera(1.0, Vector3(9.0, 8.0, 8.0), Vector3(0.0, 14.0, -5.5), _hueso)


func _rostro() -> void:
	# Maxilar y mejillas.
	_esfera(1.0, Vector3(7.5, 6.5, 8.0), Vector3(0.0, 7.5, 4.5), _hueso)
	for lado in [-1.0, 1.0]:
		_esfera(1.0, Vector3(2.4, 2.2, 3.2), Vector3(lado * 7.3, 8.8, 6.0), _hueso)
	# Mentón: el bloque de abajo de la mandíbula.
	_esfera(1.0, Vector3(6.8, 2.3, 7.5), Vector3(0.0, 1.3, 5.5), _hueso)
	# Interior de la boca (se ve oscuro entre las dos filas de dientes).
	_esfera(1.0, Vector3(6.2, 3.0, 5.0), Vector3(0.0, 3.4, 6.5), _oscuro)

	# Cuencas de los ojos: manchas negras casi a ras de la superficie, con un borde de hueso.
	for lado in [-1.0, 1.0]:
		_esfera(1.0, Vector3(3.5, 4.1, 2.0), Vector3(lado * 5.0, 14.5, 8.0), _oscuro)
		var aro := TorusMesh.new()
		aro.inner_radius = 3.1
		aro.outer_radius = 4.1
		aro.rings = 24
		aro.ring_segments = 10
		var mi := MeshInstance3D.new()
		mi.mesh = aro
		mi.material_override = _hueso
		# El toro nace acostado; se levanta para que mire hacia adelante y se estira para hacerlo ovalado.
		mi.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		mi.scale = Vector3(1.0, 1.0, 1.18)
		mi.position = Vector3(lado * 5.0, 14.5, 9.4)
		add_child(mi)

	# Hueco de la nariz.
	_esfera(1.0, Vector3(1.4, 2.6, 1.0), Vector3(0.0, 9.4, 11.4), _oscuro)


func _dientes() -> void:
	for fila in [0, 1]:
		var y: float = 4.1 if fila == 0 else 2.0
		var alto: float = 2.4 if fila == 0 else 2.0
		for i in range(9):
			var x: float = lerpf(-5.2, 5.2, float(i) / 8.0)
			# Siguen la curva del maxilar: los de los lados quedan más atrás.
			var z: float = 4.5 + 8.0 * sqrt(maxf(0.0, 1.0 - pow(x / 7.5, 2.0) - 0.2)) - 0.3
			if fila == 1:
				z -= 0.4
			var diente := BoxMesh.new()
			diente.size = Vector3(1.15, alto, 0.9)
			var mi := MeshInstance3D.new()
			mi.mesh = diente
			mi.material_override = _hueso
			mi.position = Vector3(x, y, z)
			# Un poco de desorden: ningún diente queda igual a otro.
			mi.rotation = Vector3(0.0, 0.0, sin(float(i) * 2.3 + float(fila)) * 0.08)
			add_child(mi)


# ------------------------------------------------------------------------------------
# Cuernos y púas
# ------------------------------------------------------------------------------------

# Punto del cuerno: sale de las sienes, se abre hacia afuera, sube curvándose y la punta vuelve hacia adentro.
func _punto_cuerno(lado: float, t: float) -> Vector3:
	var x: float = lado * (9.0 + 12.0 * sin(t * PI * 0.8))
	var y: float = 19.0 + 15.0 * t + 4.0 * t * t
	var z: float = -1.0 - 4.0 * t
	return Vector3(x, y, z)


func _cuernos() -> void:
	var pasos: int = 14
	for lado in [-1.0, 1.0]:
		for i in range(pasos):
			var t0: float = float(i) / pasos
			var t1: float = float(i + 1) / pasos
			var r0: float = lerpf(1.9, 0.25, pow(t0, 0.8))
			var r1: float = lerpf(1.9, 0.25, pow(t1, 0.8))
			_segmento(_punto_cuerno(lado, t0), _punto_cuerno(lado, t1), r0, r1, _cuerno)


func _puas() -> void:
	# Dos púas grises por lado, clavadas detrás del cráneo y apuntando hacia afuera.
	var datos: Array = [
		[Vector3(11.0, 8.0, -3.0), Vector3(1.0, 0.45, 0.1), 17.0],
		[Vector3(12.0, 13.0, -5.0), Vector3(1.0, 0.95, -0.05), 15.0],
	]
	for lado in [-1.0, 1.0]:
		for d in datos:
			var base: Vector3 = d[0]
			var dir: Vector3 = d[1]
			var largo: float = d[2]
			base.x *= lado
			dir.x *= lado
			dir = dir.normalized()
			_segmento(base, base + dir * largo, 1.7, 0.0, _pua)


# ------------------------------------------------------------------------------------
# Piezas básicas
# ------------------------------------------------------------------------------------

func _esfera(radio: float, escala: Vector3, pos: Vector3, mat: Material) -> void:
	var malla := SphereMesh.new()
	malla.radius = radio
	malla.height = radio * 2.0
	malla.radial_segments = 32
	malla.rings = 16
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = mat
	mi.scale = escala
	mi.position = pos
	add_child(mi)


# Cilindro (o cono si un radio es 0) que va del punto a al punto b.
func _segmento(a: Vector3, b: Vector3, r_a: float, r_b: float, mat: Material) -> void:
	var dir: Vector3 = b - a
	var largo: float = dir.length()
	if largo < 0.001:
		return
	var malla := CylinderMesh.new()
	malla.bottom_radius = r_a
	malla.top_radius = r_b
	malla.height = largo
	malla.radial_segments = 12
	malla.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = mat
	mi.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir / largo)), (a + b) * 0.5)
	add_child(mi)
