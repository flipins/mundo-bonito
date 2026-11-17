@tool
extends Node3D
## Zonas de huesos repartidas por el mapa: costillares, esqueletos tumbados, colmillos clavados
## en la arena y huesos sueltos con calaveras pequeñas. Quedan a los lados del sendero (nunca encima)
## y unas pocas rodean la arena de combate, fuera del claro plano.
## Las crea dunas.gd (opción "Con Huesos"); no hace falta añadirlas a mano.
## Guardar como: res://scripts/world/zonas_huesos.gd
## Todo son formas simples. Solo los colmillos tienen colisión; el resto es decoración que se puede atravesar.

# Zonas a lo largo del valle:
#   [avance, lateral, tipo, giro]
#   avance  = metros desde el inicio (hacia -Z)
#   lateral = metros al costado del centro del valle (negativo = izquierda, positivo = derecha)
#   tipo    = "costillar", "esqueleto", "colmillos" o "dispersos"
#   giro    = grados que se gira la zona sobre sí misma
# Para agregar una zona, copia una línea y cambia los números.
const ZONAS_VALLE: Array = [
	[18.0, 10.0, "costillar", 25.0],
	[52.0, -11.0, "esqueleto", -40.0],
	[68.0, 10.0, "colmillos", 0.0],
	[86.0, -10.0, "dispersos", 60.0],
	[100.0, 9.0, "costillar", -20.0],
]

# Zonas alrededor de la arena (en el borde, fuera del claro plano):
#   [ángulo en grados, tipo, giro]
# Ángulo 0 = a la derecha de la arena, 90 = hacia el inicio del valle, -90 = hacia el fondo (la calavera).
const ZONAS_ARENA: Array = [
	[-55.0, "colmillos", 0.0],
	[-125.0, "costillar", 80.0],
	[20.0, "dispersos", 15.0],
	[160.0, "esqueleto", 130.0],
]
## Distancia desde el borde del claro plano hasta el centro de cada zona alrededor de la arena.
const SEPARACION_ARENA := 5.0

var _terreno
var _rng := RandomNumberGenerator.new()
var _hueso: StandardMaterial3D
var _oscuro: StandardMaterial3D


func construir(terreno) -> void:
	_terreno = terreno
	_rng.seed = 91
	_crear_materiales()

	for z in ZONAS_VALLE:
		var avance: float = z[0]
		var x: float = _x_en_valle(avance, float(z[1]))
		_zona(String(z[2]), x, -avance, float(z[3]))

	if terreno.con_arena:
		var centro := Vector2(terreno.centro_valle(terreno.distancia_arena), -terreno.distancia_arena)
		var radio: float = terreno.radio_arena + SEPARACION_ARENA
		for z in ZONAS_ARENA:
			var ang: float = deg_to_rad(float(z[0]))
			var px: float = centro.x + radio * cos(ang)
			# Ángulo positivo = hacia el inicio (+Z), negativo = hacia el fondo (-Z).
			var pz: float = centro.y + radio * sin(ang)
			_zona(String(z[1]), px, pz, float(z[2]))


# X de un punto del valle, sin pasarse de las paredes de arena.
func _x_en_valle(avance: float, lateral: float) -> float:
	var centro: float = _terreno.centro_valle(avance)
	var lado: float = 1.0 if lateral >= 0.0 else -1.0
	var limite: float = maxf(_terreno.borde_valle(avance, lado) - 5.0, 3.0)
	return centro + clampf(lateral, -limite, limite)


func _h(x: float, z: float) -> float:
	return _terreno.altura_base(x, z)


func _crear_materiales() -> void:
	var ruido := FastNoiseLite.new()
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.frequency = 0.05
	ruido.fractal_octaves = 4
	var normal := NoiseTexture2D.new()
	normal.noise = ruido
	normal.seamless = true
	normal.as_normal_map = true
	normal.bump_strength = 6.0
	normal.width = 256
	normal.height = 256
	_hueso = StandardMaterial3D.new()
	_hueso.albedo_color = Color(0.86, 0.81, 0.69)
	_hueso.roughness = 0.8
	_hueso.normal_enabled = true
	_hueso.normal_texture = normal
	_hueso.uv1_triplanar = true
	_hueso.uv1_scale = Vector3.ONE
	_oscuro = StandardMaterial3D.new()
	_oscuro.albedo_color = Color(0.03, 0.025, 0.02)
	_oscuro.roughness = 1.0


# ------------------------------------------------------------------------------------
# Zonas
# ------------------------------------------------------------------------------------

func _zona(tipo: String, x: float, z: float, giro: float) -> void:
	var raiz := Node3D.new()
	raiz.name = "Zona_" + tipo
	raiz.position = Vector3(x, _h(x, z), z)
	raiz.rotation.y = deg_to_rad(giro)
	add_child(raiz)
	match tipo:
		"costillar":
			_costillar(raiz)
		"esqueleto":
			_esqueleto(raiz)
		"colmillos":
			_colmillos(raiz)
		_:
			_dispersos(raiz)


# Altura del terreno en un punto local de la zona, relativa al centro de la zona.
func _suelo(raiz: Node3D, lx: float, lz: float) -> float:
	var p: Vector3 = raiz.transform * Vector3(lx, 0.0, lz)
	return _h(p.x, p.z) - raiz.position.y


# Una caja torácica enterrada: arcos de costillas en fila, unidos por la columna.
func _costillar(raiz: Node3D) -> void:
	var cantidad: int = 7
	var paso: float = 1.25
	var ultimo: Vector3 = Vector3.ZERO
	for i in range(cantidad):
		var f: float = float(i) / float(cantidad - 1)
		var curva: float = sin(f * PI)  # los arcos del medio son los más grandes
		var zi: float = (float(i) - float(cantidad - 1) * 0.5) * paso
		var semi: float = 1.3 + 0.8 * curva + _rng.randf_range(-0.1, 0.1)
		var alto: float = 1.2 + 1.2 * curva + _rng.randf_range(-0.1, 0.2)
		var y0: float = minf(_suelo(raiz, -semi, zi), _suelo(raiz, semi, zi)) - 0.3
		# Algunas costillas están rotas: les falta un lado.
		var lados: Array = [-1.0, 1.0]
		if _rng.randf() < 0.25:
			lados = [1.0] if _rng.randf() < 0.5 else [-1.0]
		_arco(raiz, Vector3(0.0, y0, zi), semi, alto, 0.13, lados, _rng.randf_range(-0.12, 0.12))
		# Vértebra en la cima de cada arco y hueso fino que las une.
		var cima := Vector3(0.0, y0 + alto, zi)
		_esfera(raiz, 0.28, Vector3(1.0, 0.7, 1.0), cima, _hueso)
		if i > 0:
			_cil(raiz, ultimo, cima, 0.1, 0.1, _hueso)
		ultimo = cima
	# Una calavera pequeña en un extremo.
	var zc: float = -(float(cantidad - 1) * 0.5) * paso - 1.4
	_craneo(raiz, Vector3(0.0, _suelo(raiz, 0.0, zc) + 0.1, zc), PI, 1.0)


# Un esqueleto tumbado: columna de vértebras, costillas caídas, patas y calavera.
func _esqueleto(raiz: Node3D) -> void:
	var vertebras: int = 12
	var largo: float = 6.0
	for i in range(vertebras):
		var f: float = float(i) / float(vertebras - 1)
		var zi: float = (f - 0.5) * largo
		var suelo: float = _suelo(raiz, 0.0, zi)
		# La columna queda arriba del pecho y baja hasta el suelo hacia la cola.
		var alto: float = 0.12 + 0.85 * clampf(1.0 - f / 0.65, 0.0, 1.0)
		var radio: float = lerpf(0.26, 0.15, f)
		_esfera(raiz, radio, Vector3(1.0, 0.7, 1.2), Vector3(0.0, suelo + alto, zi), _hueso)
		# Costillas: arcos que bajan desde la columna hasta el suelo, solo en la zona del pecho.
		if alto > 0.3 and i % 2 == 0:
			_arco(raiz, Vector3(0.0, suelo - 0.1, zi), 0.75 + 0.3 * alto, alto, 0.08, [-1.0, 1.0], 0.0)
	# Patas: dos huesos largos al final de la columna.
	for lado in [-1.0, 1.0]:
		var a := Vector3(lado * 0.4, 0.0, largo * 0.5)
		var b := Vector3(lado * 1.2, 0.0, largo * 0.5 + 1.9)
		a.y = _suelo(raiz, a.x, a.z) + 0.1
		b.y = _suelo(raiz, b.x, b.z) + 0.1
		_hueso_largo(raiz, a, b, 0.1)
	# Calavera en el extremo del pecho, mirando hacia adelante.
	var zc: float = -largo * 0.5 - 0.9
	_craneo(raiz, Vector3(0.0, _suelo(raiz, 0.0, zc) + 0.1, zc), PI, 1.3)


# Colmillos gigantes clavados en la arena, curvados hacia afuera. Estos sí tienen colisión.
func _colmillos(raiz: Node3D) -> void:
	var cantidad: int = 5
	for i in range(cantidad):
		var ang: float = float(i) / float(cantidad) * TAU + _rng.randf_range(-0.3, 0.3)
		var dist: float = _rng.randf_range(0.8, 2.4)
		var base := Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)
		base.y = _suelo(raiz, base.x, base.z) - 0.5
		var hacia := Vector3(cos(ang), 0.0, sin(ang))
		_colmillo(raiz, base, hacia, _rng.randf_range(3.0, 6.0))


func _colmillo(raiz: Node3D, base: Vector3, hacia: Vector3, altura: float) -> void:
	var pasos: int = 8
	for i in range(pasos):
		var t0: float = float(i) / pasos
		var t1: float = float(i + 1) / pasos
		var r0: float = lerpf(0.5, 0.03, t0)
		var r1: float = lerpf(0.5, 0.03, t1)
		var p0: Vector3 = base + hacia * (altura * 0.55 * t0 * t0) + Vector3.UP * (altura * (t0 - 0.15 * t0 * t0))
		var p1: Vector3 = base + hacia * (altura * 0.55 * t1 * t1) + Vector3.UP * (altura * (t1 - 0.15 * t1 * t1))
		_cil(raiz, p0, p1, r0, r1, _hueso, true)


# Huesos sueltos, calaveras pequeñas, vértebras y costillas rotas tiradas en el suelo.
func _dispersos(raiz: Node3D) -> void:
	for i in range(9):
		var lx: float = _rng.randf_range(-3.5, 3.5)
		var lz: float = _rng.randf_range(-3.5, 3.5)
		var yaw: float = _rng.randf_range(0.0, TAU)
		var largo: float = _rng.randf_range(0.9, 1.8)
		var dir := Vector3(cos(yaw), 0.0, sin(yaw)) * largo * 0.5
		var a := Vector3(lx - dir.x, 0.0, lz - dir.z)
		var b := Vector3(lx + dir.x, 0.0, lz + dir.z)
		a.y = _suelo(raiz, a.x, a.z) + 0.08
		b.y = _suelo(raiz, b.x, b.z) + 0.08 + _rng.randf_range(0.0, 0.25)
		_hueso_largo(raiz, a, b, _rng.randf_range(0.07, 0.12))
	for i in range(2):
		var lx: float = _rng.randf_range(-2.5, 2.5)
		var lz: float = _rng.randf_range(-2.5, 2.5)
		_craneo(raiz, Vector3(lx, _suelo(raiz, lx, lz) + 0.05, lz), _rng.randf_range(0.0, TAU), _rng.randf_range(0.8, 1.3))
	for i in range(4):
		var lx: float = _rng.randf_range(-3.0, 3.0)
		var lz: float = _rng.randf_range(-3.0, 3.0)
		_esfera(raiz, 0.2, Vector3(1.0, 0.6, 1.0), Vector3(lx, _suelo(raiz, lx, lz) + 0.05, lz), _hueso)
	for i in range(2):
		var lx: float = _rng.randf_range(-2.5, 2.5)
		var lz: float = _rng.randf_range(-2.5, 2.5)
		var b := Vector3(lx, _suelo(raiz, lx, lz) - 0.15, lz)
		_arco(raiz, b, 1.0, 0.8, 0.09, [1.0], _rng.randf_range(0.8, 1.4))


# ------------------------------------------------------------------------------------
# Piezas de hueso
# ------------------------------------------------------------------------------------

# Arco de costilla: media elipse hecha con segmentos que se afinan hacia la punta.
# "lados" dice qué lados dibujar (-1 izquierda, 1 derecha). "caida" lo inclina hacia un costado.
func _arco(raiz: Node3D, base: Vector3, semi: float, alto: float, grosor: float, lados: Array, caida: float) -> void:
	var pasos: int = 5
	var rot := Basis(Vector3(0.0, 0.0, 1.0), caida)
	for lado in lados:
		for i in range(pasos):
			var t0: float = float(i) / pasos
			var t1: float = float(i + 1) / pasos
			var a0: float = t0 * PI * 0.5
			var a1: float = t1 * PI * 0.5
			var p0: Vector3 = rot * Vector3(lado * semi * cos(a0), alto * sin(a0), 0.0)
			var p1: Vector3 = rot * Vector3(lado * semi * cos(a1), alto * sin(a1), 0.0)
			_cil(raiz, base + p0, base + p1, lerpf(grosor, grosor * 0.35, t0), lerpf(grosor, grosor * 0.35, t1), _hueso)


# Hueso largo con una bolita en cada punta.
func _hueso_largo(raiz: Node3D, a: Vector3, b: Vector3, grosor: float) -> void:
	_cil(raiz, a, b, grosor, grosor, _hueso)
	_esfera(raiz, grosor * 1.7, Vector3.ONE, a, _hueso)
	_esfera(raiz, grosor * 1.7, Vector3.ONE, b, _hueso)


# Calavera pequeña de criatura: cráneo, hocico, mandíbula y dos cuencas oscuras. Mira hacia +Z local.
func _craneo(raiz: Node3D, pos: Vector3, yaw: float, escala: float) -> void:
	var c := Node3D.new()
	c.position = pos
	c.rotation.y = yaw
	raiz.add_child(c)
	_esfera(c, 0.42 * escala, Vector3(1.0, 0.85, 1.1), Vector3(0.0, 0.38 * escala, 0.0), _hueso)
	_esfera(c, 0.24 * escala, Vector3(0.9, 0.7, 1.4), Vector3(0.0, 0.26 * escala, 0.45 * escala), _hueso)
	_esfera(c, 0.2 * escala, Vector3(1.1, 0.5, 1.5), Vector3(0.0, 0.1 * escala, 0.42 * escala), _hueso)
	for lado in [-1.0, 1.0]:
		_esfera(c, 0.11 * escala, Vector3(1.0, 1.2, 0.6), Vector3(lado * 0.2 * escala, 0.47 * escala, 0.37 * escala), _oscuro)


func _esfera(padre: Node3D, radio: float, escala: Vector3, pos: Vector3, mat: Material) -> void:
	var malla := SphereMesh.new()
	malla.radius = radio
	malla.height = radio * 2.0
	malla.radial_segments = 10
	malla.rings = 5
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = mat
	mi.scale = escala
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(mi)


# Cilindro (o cono si un radio es casi 0) del punto a al punto b, con colisión opcional.
func _cil(padre: Node3D, a: Vector3, b: Vector3, r_a: float, r_b: float, mat: Material, colision: bool = false) -> void:
	var dir: Vector3 = b - a
	var largo: float = dir.length()
	if largo < 0.001:
		return
	var malla := CylinderMesh.new()
	malla.bottom_radius = r_a
	malla.top_radius = r_b
	malla.height = largo
	malla.radial_segments = 8
	malla.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = mat
	mi.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir / largo)), (a + b) * 0.5)
	# Las piezas finas no necesitan sombra propia; los colmillos grandes sí.
	if not colision:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(mi)
	if colision:
		var cuerpo := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var forma := CylinderShape3D.new()
		forma.radius = maxf(r_a, r_b)
		forma.height = largo
		cs.shape = forma
		cuerpo.add_child(cs)
		mi.add_child(cuerpo)
