@tool
extends Node3D
## Props del recorrido: sendero de lajas, postes con cuerdas y telas, costillas óseas gigantes,
## formaciones de arenisca en capas, matas de hierba seca con viento y polvo en el aire.
## Al final del sendero deja un cadáver con la espada vieja clavada (ver cadaver_espada.gd).
## Los crea dunas.gd y los coloca sobre el terreno; no hace falta añadirlos a mano.
## Guardar como: res://scripts/world/props_recorrido.gd
## Todo son formas simples: luego puedes reemplazar cada pieza por un modelo 3D propio.

## Altura libre bajo las costillas (hay que agacharse). Sube este valor si el jugador agachado no cabe.
const ALTURA_LIBRE_COSTILLAS := 1.5
const AVANCE_COSTILLAS := 35.0  # metros desde el inicio (hacia -Z)
## Postes con cuerdas y banderas a lo largo del sendero (apagados). Pon true para volver a crearlos.
const CON_POSTES := false
## Script que crea el cadáver y la espada recogible (si no existe, simplemente no se crean).
const RUTA_CADAVER := "res://scripts/world/cadaver_espada.gd"
## Hasta dónde llega el sendero de lajas, en metros desde el inicio (hacia -Z). Súbelo para alargar el recorrido.
const FIN_SENDERO := 108.0
## Metros desde el inicio (hacia -Z) donde queda el cadáver: un poco después del final del sendero.
const AVANCE_CADAVER := 112.0

const SHADER_TELA := """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 color : source_color = vec4(0.55, 0.2, 0.18, 1.0);
uniform float largo = 2.0;
uniform float ancho = 0.7;
uniform float punta = 0.0;
uniform float fuerza = 0.25;
varying vec2 pos;
void vertex() {
	pos = vec2(VERTEX.x, (VERTEX.y + largo * 0.5) / largo);
	float w = 1.0 - pos.y;
	float t = TIME * 2.2 + NODE_POSITION_WORLD.x * 0.7 + NODE_POSITION_WORLD.z * 0.5;
	VERTEX.z += sin(t + VERTEX.y * 3.0) * fuerza * w;
	VERTEX.x += sin(t * 0.8 + VERTEX.y * 4.0) * fuerza * 0.3 * w;
}
void fragment() {
	float lim = ancho * 0.5 * mix(1.0, pos.y, punta);
	if (abs(pos.x) > lim) {
		discard;
	}
	float borde = 0.06 + 0.06 * sin(pos.x * 22.0) + 0.04 * sin(pos.x * 51.0 + 1.3);
	if (pos.y < borde) {
		discard;
	}
	ALBEDO = color.rgb * (0.8 + 0.2 * sin(pos.y * 35.0 + pos.x * 6.0));
	ROUGHNESS = 1.0;
}
"""

const SHADER_HIERBA := """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 color_base : source_color = vec4(0.50, 0.34, 0.10, 1.0);
uniform vec4 color_punta : source_color = vec4(0.96, 0.80, 0.40, 1.0);
varying float altura;
void vertex() {
	altura = clamp(VERTEX.y, 0.0, 1.0);
	float w = altura * altura;
	vec3 p = MODEL_MATRIX[3].xyz;
	VERTEX.x += sin(TIME * 1.7 + p.x * 0.8 + p.z * 0.6) * 0.2 * w;
	VERTEX.z += cos(TIME * 1.3 + p.x * 0.5) * 0.1 * w;
}
void fragment() {
	ALBEDO = mix(color_base.rgb, color_punta.rgb, altura);
	ROUGHNESS = 0.9;
}
"""

var _terreno
var _rng := RandomNumberGenerator.new()
var _laja: StandardMaterial3D
var _roca: StandardMaterial3D
var _arenisca: Array = []
var _madera: StandardMaterial3D
var _hueso: StandardMaterial3D
var _shader_tela: Shader
var _matas: Array = []  # puntos donde crece una mata de hierba seca
var _polvo: GPUParticles3D


func construir(terreno) -> void:
	_terreno = terreno
	_rng.seed = 23
	_crear_materiales()
	_sendero()
	if CON_POSTES:
		_postes()
	_costillas(AVANCE_COSTILLAS)
	_rocas()
	_hierba()
	_polvo_ambiente()
	# Va al final y usa su propio generador de azar: no cambia nada de lo anterior.
	_cadaver_y_espada()
	set_process(not Engine.is_editor_hint())


# El polvo sigue a la cámara para que siempre haya partículas alrededor del jugador.
func _process(_delta: float) -> void:
	if _polvo == null:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam != null:
		_polvo.global_position = cam.global_position


# ------------------------------------------------------------------------------------
# Utilidades de terreno
# ------------------------------------------------------------------------------------

func _h(x: float, z: float) -> float:
	return _terreno.altura_base(x, z)


# Normal del terreno en un punto (para apoyar las lajas siguiendo la pendiente).
func _normal(x: float, z: float) -> Vector3:
	var dhdx: float = (_h(x + 0.5, z) - _h(x - 0.5, z)) / 1.0
	var dhdz: float = (_h(x, z + 0.5) - _h(x, z - 0.5)) / 1.0
	return Vector3(-dhdx, 1.0, -dhdz).normalized()


# Punto (X, Z) del sendero a "avance" metros del inicio: curva suave hacia el centro del valle.
func _punto_camino(avance: float) -> Vector2:
	var x: float = _terreno.centro_valle(avance) + 3.5 * sin(avance * 0.11 + 0.8)
	return Vector2(x, -avance)


# ------------------------------------------------------------------------------------
# Materiales
# ------------------------------------------------------------------------------------

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
	_laja = _material(Color(0.60, 0.58, 0.55), 0.95, normal, 0.5)
	_roca = _material(Color(0.50, 0.39, 0.30), 0.95, normal, 0.25)
	# Arenisca en capas: cuatro tonos que se alternan para marcar los estratos.
	_arenisca.clear()
	for c in [Color(0.80, 0.55, 0.40), Color(0.72, 0.45, 0.32), Color(0.86, 0.64, 0.47), Color(0.64, 0.40, 0.30)]:
		_arenisca.append(_material(c, 0.95, normal, 0.35))
	_madera = _material(Color(0.36, 0.26, 0.17), 1.0, null, 1.0)
	_hueso = _material(Color(0.86, 0.81, 0.69), 0.8, normal, 1.0)
	_shader_tela = Shader.new()
	_shader_tela.code = SHADER_TELA


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
# Sendero de lajas
# ------------------------------------------------------------------------------------

func _sendero() -> void:
	var avance: float = 6.0
	while avance < 56.0:
		avance += _paso_sendero(avance)
	# Tramo extra hasta FIN_SENDERO: usa su propio azar para no mover el resto de los props.
	var azar_original: RandomNumberGenerator = _rng
	_rng = RandomNumberGenerator.new()
	_rng.seed = 31
	while avance < FIN_SENDERO:
		avance += _paso_sendero(avance)
	_rng = azar_original


# Pone una o dos lajas a "avance" metros y devuelve cuánto hay que avanzar hasta la siguiente.
func _paso_sendero(avance: float) -> float:
	var p: Vector2 = _punto_camino(avance)
	_laja_en(p.x + _rng.randf_range(-0.9, 0.9), p.y)
	# A veces una segunda laja más pequeña al lado.
	if _rng.randf() < 0.5:
		_laja_en(p.x + _rng.randf_range(-2.0, 2.0), p.y + _rng.randf_range(-1.0, 1.0))
	return _rng.randf_range(2.0, 3.0)


func _laja_en(x: float, z: float) -> void:
	var tam := Vector3(_rng.randf_range(1.1, 2.1), 0.14, _rng.randf_range(0.8, 1.5))
	var n: Vector3 = _normal(x, z)
	var base: Basis = Basis(Quaternion(Vector3.UP, n)) * Basis(Vector3.UP, _rng.randf_range(-0.5, 0.5))
	_caja(tam, Vector3(x, _h(x, z) + 0.02, z), base, _laja, false)


# ------------------------------------------------------------------------------------
# Cadáver con la espada vieja, al final del sendero
# ------------------------------------------------------------------------------------

func _cadaver_y_espada() -> void:
	if not ResourceLoader.exists(RUTA_CADAVER):
		return
	var p: Vector2 = _punto_camino(AVANCE_CADAVER)
	var nodo := Node3D.new()
	nodo.name = "CadaverEspada"
	nodo.set_script(load(RUTA_CADAVER))
	add_child(nodo)
	# Un poco a un lado del sendero, para que se vea junto al camino y no encima.
	nodo.call("construir", _terreno, Vector2(p.x + 2.2, p.y))


# ------------------------------------------------------------------------------------
# Postes inclinados con cuerdas y telas
# ------------------------------------------------------------------------------------

func _postes() -> void:
	var avances: Array = [14.0, 30.0, 52.0]
	var banderas: Array = [
		[Color(0.22, 0.38, 0.55), Color(0.60, 0.20, 0.18)],
		[Color(0.50, 0.48, 0.45), Color(0.22, 0.38, 0.55)],
		[Color(0.60, 0.20, 0.18), Color(0.50, 0.48, 0.45)],
	]
	for i in range(avances.size()):
		var c: Vector2 = _punto_camino(avances[i])
		var sep: float = 4.5
		var cima_i: Vector3 = _poste(Vector3(c.x - sep, 0.0, c.y), 10.0)
		var cima_d: Vector3 = _poste(Vector3(c.x + sep, 0.0, c.y), -10.0)
		_cuerda(cima_i + Vector3(0, -0.35, 0), cima_d + Vector3(0, -0.35, 0))
		# Una bandera en punta en lo alto de cada poste, volando con el viento.
		_tela(cima_i + Vector3(0, -0.2, 0), 1.8, 0.7, banderas[i][0], true)
		_tela(cima_d + Vector3(0, -0.2, 0), 1.8, 0.7, banderas[i][1], true)


# Crea un poste de madera inclinado y devuelve la posición de su punta.
func _poste(pos: Vector3, inclinacion: float) -> Vector3:
	var largo: float = 3.4
	var y: float = _h(pos.x, pos.z) - 0.3
	var base := Vector3(pos.x, y, pos.z)
	var rot: Basis = Basis(Vector3(0, 0, 1), deg_to_rad(inclinacion))
	var centro: Vector3 = base + rot * Vector3(0, largo * 0.5, 0)
	_cilindro(0.07, 0.1, largo, centro, rot, _madera, true)
	_matas.append(Vector3(pos.x, y + 0.3, pos.z))
	return base + rot * Vector3(0, largo, 0)


# Cuerda que cuelga entre dos puntas, con trozos de tela colgando.
func _cuerda(a: Vector3, b: Vector3) -> void:
	var tramos: int = 8
	for i in range(tramos):
		var p0: Vector3 = _punto_cuerda(a, b, float(i) / tramos)
		var p1: Vector3 = _punto_cuerda(a, b, float(i + 1) / tramos)
		var dir: Vector3 = p1 - p0
		var base := Basis.looking_at(dir.normalized(), Vector3.UP)
		_caja(Vector3(0.04, 0.04, dir.length() * 1.05), (p0 + p1) * 0.5, base, _madera, false)
	var colores: Array = [Color(0.55, 0.20, 0.18), Color(0.22, 0.38, 0.55), Color(0.50, 0.48, 0.45)]
	var ts: Array = [0.25, 0.5, 0.78]
	for i in range(3):
		var pt: Vector3 = _punto_cuerda(a, b, ts[i])
		_tela(pt, _rng.randf_range(0.6, 1.0), 0.3, colores[i], false)


func _punto_cuerda(a: Vector3, b: Vector3, t: float) -> Vector3:
	return a.lerp(b, t) + Vector3.DOWN * sin(t * PI) * 0.55


# Tela rasgada. Colgando (horizontal = false) o volando hacia +X como bandera en punta.
func _tela(arriba: Vector3, largo: float, ancho: float, color: Color, horizontal: bool) -> void:
	var malla := PlaneMesh.new()
	malla.size = Vector2(ancho, largo)
	malla.orientation = PlaneMesh.FACE_Z
	malla.subdivide_width = 4
	malla.subdivide_depth = 12
	var mat := ShaderMaterial.new()
	mat.shader = _shader_tela
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("largo", largo)
	mat.set_shader_parameter("ancho", ancho)
	mat.set_shader_parameter("punta", 1.0 if horizontal else 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = mat
	if horizontal:
		# Se gira 90° para que el lado atado quede en el poste y el extremo libre apunte a +X.
		mi.transform = Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(90.0)), arriba + Vector3(largo * 0.5, 0, 0))
	else:
		mi.position = arriba - Vector3(0, largo * 0.5, 0)
	mi.extra_cull_margin = 1.0
	add_child(mi)


# ------------------------------------------------------------------------------------
# Costillas óseas gigantes (paso bajo: hay que agacharse)
# ------------------------------------------------------------------------------------

func _costillas(avance0: float) -> void:
	var extras: Array = [0.5, 0.25, 0.0, 0.2, 0.6]  # los arcos de los extremos son más altos
	for i in range(extras.size()):
		var c: Vector2 = _punto_camino(avance0 + float(i) * 1.6)
		var semi: float = 2.3 + _rng.randf_range(-0.2, 0.3)
		var alto: float = ALTURA_LIBRE_COSTILLAS + extras[i]
		var y0: float = minf(_h(c.x - semi, c.y), _h(c.x + semi, c.y)) - 0.25
		_arco_oseo(Vector3(c.x, y0, c.y), semi, alto)


# Un arco: dos mitades de elipse (una por lado) hechas con segmentos que se afinan hacia la cima.
func _arco_oseo(centro: Vector3, semi: float, alto: float) -> void:
	var pasos: int = 6
	for lado in [-1.0, 1.0]:
		for i in range(pasos):
			var t0: float = float(i) / pasos
			var t1: float = float(i + 1) / pasos
			var p0: Vector3 = centro + _punto_elipse(semi, alto, t0, lado)
			var p1: Vector3 = centro + _punto_elipse(semi, alto, t1, lado)
			var dir: Vector3 = p1 - p0
			var rot: Basis = Basis(Quaternion(Vector3.UP, dir.normalized()))
			_cilindro(lerpf(0.2, 0.07, t1), lerpf(0.2, 0.07, t0), dir.length() * 1.04, (p0 + p1) * 0.5, rot, _hueso, true)


# Punto de la media elipse: t = 0 en la base (suelo) y t = 1 en la cima.
func _punto_elipse(semi: float, alto: float, t: float, lado: float) -> Vector3:
	var ang: float = t * PI * 0.5
	return Vector3(lado * semi * cos(ang), alto * sin(ang), 0.0)


# ------------------------------------------------------------------------------------
# Formaciones de arenisca en capas (columnas, copas, mesas y un arco natural)
# ------------------------------------------------------------------------------------

func _rocas() -> void:
	# Al pie de las paredes y un poco sobre ellas, a ambos lados del valle.
	for i in range(14):
		var avance: float = _rng.randf_range(6.0, 78.0)
		var lado: float = -1.0 if i % 2 == 0 else 1.0
		var borde: float = _terreno.borde_valle(avance, lado)
		var desde_borde: float = _rng.randf_range(-3.0, _terreno.ancho_pared * 0.5)
		var x: float = _terreno.centro_valle(avance) + lado * (borde + desde_borde)
		_formacion_aleatoria(x, -avance)
	# Sueltas por el suelo del valle, lejos del sendero y de las ruinas, para que no se sienta vacío.
	var colocadas: int = 0
	var intentos: int = 0
	while colocadas < 8 and intentos < 60:
		intentos += 1
		var avance: float = _rng.randf_range(10.0, 75.0)
		var lado: float = -1.0 if _rng.randf() < 0.5 else 1.0
		var x: float = _terreno.centro_valle(avance) + lado * _rng.randf_range(12.0, 32.0)
		var z: float = -avance
		if absf(x - _punto_camino(avance).x) < 9.0:
			continue
		if Vector2(x, z).distance_to(_terreno.posicion_ruinas) < 12.0:
			continue
		_formacion_aleatoria(x, z)
		colocadas += 1
	# En la ladera del muro trasero (detrás del inicio), para que no se vea vacío.
	for i in range(6):
		var avance: float = _rng.randf_range(-36.0, -16.0)
		var x: float = _terreno.centro_valle(avance) + _rng.randf_range(-35.0, 35.0)
		_formacion_aleatoria(x, -avance)
	# Un arco natural a un lado del recorrido.
	_arco_natural(_terreno.centro_valle(55.0) - 24.0, -55.0)


func _formacion_aleatoria(x: float, z: float) -> void:
	match _rng.randi_range(0, 3):
		0:  # columna alta con tapa ancha
			_formacion(x, z, _rng.randf_range(7.0, 11.0), _rng.randf_range(2.2, 3.0), _rng.randf_range(0.8, 1.1), _rng.randf_range(1.7, 2.2))
		1:  # copa: tallo fino y tapa muy ancha
			_formacion(x, z, _rng.randf_range(4.0, 6.5), 2.2, 1.0, _rng.randf_range(2.6, 3.2))
		2:  # mesa ancha y baja
			_formacion(x, z, _rng.randf_range(3.0, 4.5), _rng.randf_range(3.5, 5.0), 3.2, 3.4)
		_:  # bloque: varias mesas juntas
			for k in range(3):
				_formacion(x + _rng.randf_range(-2.5, 2.5), z + _rng.randf_range(-2.5, 2.5), _rng.randf_range(2.5, 5.0), _rng.randf_range(2.5, 3.5), 2.2, 2.6)


# Apila discos de roca (capas) con un perfil: base ancha, cuello, tapa. Devuelve la cima.
func _formacion(x: float, z: float, altura: float, r_base: float, r_cuello: float, r_tapa: float) -> Vector3:
	var capas: int = int(clampf(altura * 1.8, 6.0, 20.0))
	var y: float = _base_formacion(x, z, r_base) - 0.5
	var grosor_medio: float = (altura + 0.5) / float(capas)
	var tono0: int = _rng.randi_range(0, 3)
	for i in range(capas):
		var t: float = float(i) / float(capas - 1)
		var r: float = r_cuello + (r_base - r_cuello) * pow(1.0 - t, 4.0) + (r_tapa - r_cuello) * smoothstep(0.78, 0.92, t)
		var g: float = grosor_medio * _rng.randf_range(0.6, 1.4)
		if t > 0.9:
			g *= 1.5
		var jx: float = _rng.randf_range(-0.12, 0.12) * r
		var jz: float = _rng.randf_range(-0.12, 0.12) * r
		var mat: Material = _arenisca[(tono0 + i + _rng.randi_range(0, 1)) % 4]
		_disco(Vector3(x + jx, y + g * 0.5, z + jz), r * _rng.randf_range(0.92, 1.0), r * _rng.randf_range(1.0, 1.08), g, mat)
		y += g * 0.85
	if r_base > 2.0 and _rng.randf() < 0.6:
		_matas.append(Vector3(x + r_base + 0.5, _h(x + r_base + 0.5, z), z))
	return Vector3(x, y, z)


# El punto más bajo del terreno bajo la formación: así la base queda enterrada también cuesta arriba.
func _base_formacion(x: float, z: float, r: float) -> float:
	var m: float = _h(x, z)
	for ang in [0.0, 1.57, 3.14, 4.71]:
		m = minf(m, _h(x + cos(ang) * r, z + sin(ang) * r))
	return m


# Arco de roca entre dos pilares, con paso libre por debajo.
func _arco_natural(x: float, z: float) -> void:
	var sep: float = 4.0
	var cima_a: Vector3 = _formacion(x - sep, z, 5.0, 2.6, 1.7, 1.9)
	var cima_b: Vector3 = _formacion(x + sep, z, 5.0, 2.6, 1.7, 1.9)
	var a: Vector3 = cima_a + Vector3(0, -0.3, 0)
	var b: Vector3 = cima_b + Vector3(0, -0.3, 0)
	var tramos: int = 7
	for i in range(tramos):
		var t0: float = float(i) / tramos
		var t1: float = float(i + 1) / tramos
		var p0: Vector3 = a.lerp(b, t0) + Vector3.UP * sin(t0 * PI) * 1.3
		var p1: Vector3 = a.lerp(b, t1) + Vector3.UP * sin(t1 * PI) * 1.3
		var dir: Vector3 = p1 - p0
		var base := Basis.looking_at(dir.normalized(), Vector3.UP)
		_caja(Vector3(1.6, 1.1, dir.length() * 1.1), (p0 + p1) * 0.5, base, _arenisca[i % 4], false)


func _disco(pos: Vector3, r_arriba: float, r_abajo: float, alto: float, mat: Material) -> void:
	var malla := CylinderMesh.new()
	malla.top_radius = r_arriba
	malla.bottom_radius = r_abajo
	malla.height = alto
	malla.radial_segments = 9
	malla.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = Vector3(_rng.randf_range(-3, 3), _rng.randf_range(0, 360), _rng.randf_range(-3, 3))
	add_child(mi)
	var cuerpo := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var forma := CylinderShape3D.new()
	forma.radius = maxf(r_arriba, r_abajo)
	forma.height = alto
	cs.shape = forma
	cuerpo.add_child(cs)
	mi.add_child(cuerpo)


# ------------------------------------------------------------------------------------
# Hierba seca (MultiMesh con viento)
# ------------------------------------------------------------------------------------

func _hierba() -> void:
	# Matas a los lados del sendero.
	for i in range(10):
		var p: Vector2 = _punto_camino(_rng.randf_range(8.0, 56.0))
		var lado: float = -1.0 if i % 2 == 0 else 1.0
		var x: float = p.x + lado * _rng.randf_range(2.5, 4.5)
		_matas.append(Vector3(x, _h(x, p.y), p.y))
	# Matas alrededor de las ruinas.
	var r: Vector2 = _terreno.posicion_ruinas
	for i in range(5):
		var ang: float = _rng.randf() * TAU
		var d: float = _rng.randf_range(4.5, 7.0)
		var x: float = r.x + cos(ang) * d
		var z: float = r.y + sin(ang) * d
		_matas.append(Vector3(x, _h(x, z), z))

	var instancias: Array = []
	for m in _matas:
		for k in range(_rng.randi_range(9, 13)):
			var px: float = m.x + _rng.randf_range(-0.9, 0.9)
			var pz: float = m.z + _rng.randf_range(-0.9, 0.9)
			var s: float = _rng.randf_range(0.8, 1.5)
			var base: Basis = Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s))
			instancias.append(Transform3D(base, Vector3(px, _h(px, pz) - 0.05, pz)))

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _mata_de_hierba()
	mm.instance_count = instancias.size()
	for i in range(instancias.size()):
		mm.set_instance_transform(i, instancias[i])
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER_HIERBA
	mat.shader = sh
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# Una mata: 9 briznas triangulares inclinadas en distintas direcciones.
func _mata_de_hierba() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(9):
		var rot: Basis = Basis(Vector3.UP, TAU * float(i) / 9.0 + _rng.randf_range(-0.3, 0.3))
		var alto: float = _rng.randf_range(0.55, 1.0)
		var inclina: float = _rng.randf_range(0.1, 0.35)
		var pa: Vector3 = rot * Vector3(-0.03, 0.0, 0.0)
		var pb: Vector3 = rot * Vector3(0.03, 0.0, 0.0)
		var pc: Vector3 = rot * Vector3(0.0, alto, inclina)
		for pt in [pa, pb, pc]:
			st.set_normal(Vector3.UP)
			st.add_vertex(pt)
	return st.commit()


# ------------------------------------------------------------------------------------
# Polvo en el aire
# ------------------------------------------------------------------------------------

func _polvo_ambiente() -> void:
	var proceso := ParticleProcessMaterial.new()
	proceso.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proceso.emission_box_extents = Vector3(25.0, 6.0, 25.0)
	proceso.direction = Vector3(1.0, 0.05, 0.3)
	proceso.spread = 15.0
	proceso.initial_velocity_min = 2.0
	proceso.initial_velocity_max = 5.0
	proceso.gravity = Vector3.ZERO
	proceso.scale_min = 0.6
	proceso.scale_max = 1.6

	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.80, 0.62, 0.42, 0.85)
	# Textura circular suave: así las partículas se ven redondas y no como cuadrados.
	var degradado := Gradient.new()
	degradado.set_color(0, Color(1, 1, 1, 1))
	degradado.set_color(1, Color(1, 1, 1, 0))
	var circulo := GradientTexture2D.new()
	circulo.gradient = degradado
	circulo.fill = GradientTexture2D.FILL_RADIAL
	circulo.fill_from = Vector2(0.5, 0.5)
	circulo.fill_to = Vector2(1.0, 0.5)
	circulo.width = 64
	circulo.height = 64
	mat.albedo_texture = circulo
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = mat

	_polvo = GPUParticles3D.new()
	_polvo.name = "PolvoAmbiente"
	_polvo.amount = 500
	_polvo.lifetime = 6.0
	_polvo.preprocess = 6.0
	_polvo.process_material = proceso
	_polvo.draw_pass_1 = quad
	_polvo.visibility_aabb = AABB(Vector3(-60, -20, -60), Vector3(120, 40, 120))
	add_child(_polvo)
	_polvo.position = Vector3(0, 3, 0)


# ------------------------------------------------------------------------------------
# Piezas básicas
# ------------------------------------------------------------------------------------

func _cilindro(r_arriba: float, r_abajo: float, alto: float, pos: Vector3, rot: Basis, mat: Material, colision: bool) -> void:
	var malla := CylinderMesh.new()
	malla.top_radius = r_arriba
	malla.bottom_radius = r_abajo
	malla.height = alto
	malla.radial_segments = 12
	malla.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = mat
	mi.transform = Transform3D(rot, pos)
	add_child(mi)
	if colision:
		var cuerpo := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var forma := CylinderShape3D.new()
		forma.radius = maxf(r_arriba, r_abajo)
		forma.height = alto
		cs.shape = forma
		cuerpo.add_child(cs)
		mi.add_child(cuerpo)


func _caja(tam: Vector3, pos: Vector3, rot: Basis, mat: Material, colision: bool) -> void:
	var malla := BoxMesh.new()
	malla.size = tam
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = mat
	mi.transform = Transform3D(rot, pos)
	add_child(mi)
	if colision:
		var cuerpo := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var forma := BoxShape3D.new()
		forma.size = tam
		cs.shape = forma
		cuerpo.add_child(cs)
		mi.add_child(cuerpo)
