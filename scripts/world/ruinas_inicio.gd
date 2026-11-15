@tool
extends Node3D
## Ruinas del punto de inicio: plataforma circular de piedra, tres columnas rotas de
## distinta altura, dintel curvo, telas rasgadas con viento y escombros.
## Las crea dunas.gd y las coloca sobre el terreno; no hace falta añadirlas a mano.
## Guardar como: res://scripts/world/ruinas_inicio.gd
## Todo se arma con formas simples (cilindros y cajas): luego puedes reemplazar
## cada pieza por un modelo 3D propio.

const RADIO_PLATAFORMA := 4.0
const ALTO_PLATAFORMA := 0.25  # altura de la plataforma sobre la arena
const RADIO_COLUMNAS := 3.2
const ALTURAS_COLUMNAS := [1.5, 3.0, 4.5]
const ANGULOS_COLUMNAS := [205.0, 250.0, 295.0]  # grados; quedan al fondo (-Z) de la plataforma

const SHADER_TELA := """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 color : source_color = vec4(0.55, 0.2, 0.18, 1.0);
uniform float largo = 2.0;
uniform float fuerza = 0.25;
varying vec2 pos;
void vertex() {
	pos = vec2(VERTEX.x, (VERTEX.y + largo * 0.5) / largo);
	float w = 1.0 - pos.y;
	float t = TIME * 2.0 + NODE_POSITION_WORLD.x * 0.7;
	VERTEX.z += sin(t + VERTEX.y * 3.0) * fuerza * w;
	VERTEX.x += sin(t * 0.8 + VERTEX.y * 4.0) * fuerza * 0.3 * w;
}
void fragment() {
	float borde = 0.10 + 0.08 * sin(pos.x * 22.0) + 0.05 * sin(pos.x * 51.0 + 1.3);
	if (pos.y < borde) {
		discard;
	}
	ALBEDO = color.rgb * (0.8 + 0.2 * sin(pos.y * 35.0 + pos.x * 6.0));
	ROUGHNESS = 1.0;
}
"""

var _terreno
var _mats: Array = []
var _shader_tela: Shader
var _rng := RandomNumberGenerator.new()


## Construye las ruinas con su centro en (centro.x, centro.y) del espacio del terreno.
func construir(terreno, centro: Vector2) -> void:
	_terreno = terreno
	position = Vector3(centro.x, terreno.altura_base(centro.x, centro.y), centro.y)
	_rng.seed = 11
	_crear_materiales()
	_plataforma()
	var cimas: Array = _columnas()
	# Dintel curvo entre las dos columnas altas.
	var a: Vector3 = cimas[1]
	var b: Vector3 = cimas[2]
	_dintel(a, b)
	# Telas: dos colgando del dintel y una de la columna baja.
	_tela(_punto_arco(a, b, 0.30) + Vector3(0, -0.1, 0.25), 2.2, 0.7, Color(0.55, 0.20, 0.18))
	_tela(_punto_arco(a, b, 0.75) + Vector3(0, -0.1, 0.25), 1.8, 0.6, Color(0.22, 0.38, 0.52))
	var c: Vector3 = cimas[0]
	_tela(c + Vector3(0.3, -0.1, 0.35), 1.3, 0.5, Color(0.50, 0.24, 0.20))
	_escombros()


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
	_mats.clear()
	# Tres tonos de piedra: claro, medio y oscuro.
	for c in [Color(0.78, 0.70, 0.58), Color(0.68, 0.60, 0.49), Color(0.50, 0.44, 0.37)]:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.95
		m.normal_enabled = true
		m.normal_texture = normal
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.4
		_mats.append(m)
	_shader_tela = Shader.new()
	_shader_tela.code = SHADER_TELA


func _plataforma() -> void:
	var tope: float = ALTO_PLATAFORMA
	# Cuerpo semienterrado en la arena.
	_cilindro(RADIO_PLATAFORMA, RADIO_PLATAFORMA, 1.2, Vector3(0, tope - 0.6, 0), _mats[1], true)
	# Anillos grabados en la superficie (oscuro / claro / oscuro / claro).
	_cilindro(3.5, 3.5, 0.04, Vector3(0, tope + 0.00, 0), _mats[2], false)
	_cilindro(3.2, 3.2, 0.04, Vector3(0, tope + 0.01, 0), _mats[0], false)
	_cilindro(2.2, 2.2, 0.04, Vector3(0, tope + 0.02, 0), _mats[2], false)
	_cilindro(1.9, 1.9, 0.04, Vector3(0, tope + 0.03, 0), _mats[0], false)


# Crea las columnas y devuelve la posición de la cima de cada una.
func _columnas() -> Array:
	var cimas: Array = []
	for i in range(ALTURAS_COLUMNAS.size()):
		var alto: float = ALTURAS_COLUMNAS[i]
		var ang: float = deg_to_rad(ANGULOS_COLUMNAS[i])
		var px: float = cos(ang) * RADIO_COLUMNAS
		var pz: float = sin(ang) * RADIO_COLUMNAS
		var base_y: float = ALTO_PLATAFORMA
		# Fuste (ligeramente más fino arriba).
		_cilindro(0.42, 0.5, alto + 0.1, Vector3(px, base_y - 0.05 + alto * 0.5, pz), _mats[0], true)
		# Base cuadrada.
		_caja(Vector3(1.3, 0.3, 1.3), Vector3(px, base_y + 0.15, pz), Vector3(0, rad_a_grados(-ang), 0), _mats[1], false)
		if i == 2:
			# La columna alta conserva su capitel.
			_caja(Vector3(1.2, 0.25, 1.2), Vector3(px, base_y + alto + 0.12, pz), Vector3(0, rad_a_grados(-ang), 0), _mats[1], false)
		else:
			# Las otras terminan rotas: un trozo inclinado en la punta.
			_caja(Vector3(0.7, 0.3, 0.6), Vector3(px, base_y + alto + 0.1, pz), Vector3(12, 30 * i, -15), _mats[2], false)
		cimas.append(Vector3(px, base_y + alto + (0.25 if i == 2 else 0.0), pz))
	return cimas


func rad_a_grados(r: float) -> float:
	return rad_to_deg(r)


# Punto de un arco que une a con b y se abomba hacia arriba.
func _punto_arco(a: Vector3, b: Vector3, t: float) -> Vector3:
	return a.lerp(b, t) + Vector3.UP * (sin(t * PI) * 0.7 + 0.2)


func _dintel(a: Vector3, b: Vector3) -> void:
	var tramos: int = 8
	for i in range(tramos):
		var p0: Vector3 = _punto_arco(a, b, float(i) / tramos)
		var p1: Vector3 = _punto_arco(a, b, float(i + 1) / tramos)
		var dir: Vector3 = p1 - p0
		var malla := BoxMesh.new()
		malla.size = Vector3(0.55, 0.38, dir.length() * 1.08)
		var mi := MeshInstance3D.new()
		mi.mesh = malla
		mi.material_override = _mats[1]
		mi.transform = Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), (p0 + p1) * 0.5)
		add_child(mi)


# Tela rasgada que cuelga de "arriba" y se mueve con el viento.
func _tela(arriba: Vector3, largo: float, ancho: float, color: Color) -> void:
	var malla := PlaneMesh.new()
	malla.size = Vector2(ancho, largo)
	malla.orientation = PlaneMesh.FACE_Z
	malla.subdivide_width = 4
	malla.subdivide_depth = 12
	var mat := ShaderMaterial.new()
	mat.shader = _shader_tela
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("largo", largo)
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = mat
	mi.position = arriba - Vector3(0, largo * 0.5, 0)
	mi.extra_cull_margin = 1.0
	add_child(mi)


func _escombros() -> void:
	# Trozos de piedra caídos alrededor de la plataforma.
	for i in range(9):
		var ang: float = _rng.randf() * TAU
		var dist: float = _rng.randf_range(3.8, 8.0)
		var lx: float = cos(ang) * dist
		var lz: float = sin(ang) * dist
		var tam := Vector3(_rng.randf_range(0.4, 1.2), _rng.randf_range(0.3, 0.7), _rng.randf_range(0.4, 1.0))
		var rot := Vector3(_rng.randf_range(-15, 15), _rng.randf_range(0, 360), _rng.randf_range(-15, 15))
		_caja(tam, Vector3(lx, _altura_local(lx, lz) + tam.y * 0.2, lz), rot, _mats[_rng.randi_range(0, 2)], true)
	# Dos tambores de columna caídos, tumbados en la arena.
	for par in [[150.0, 5.5], [330.0, 4.8]]:
		var ang: float = deg_to_rad(par[0])
		var lx: float = cos(ang) * par[1]
		var lz: float = sin(ang) * par[1]
		_cilindro(0.45, 0.45, 1.3, Vector3(lx, _altura_local(lx, lz) + 0.3, lz), _mats[0], true, Vector3(0, _rng.randf_range(0, 360), 90))
	# Tocón de columna roto sobre el borde de la plataforma.
	_cilindro(0.45, 0.5, 0.9, Vector3(0, ALTO_PLATAFORMA + 0.35, RADIO_COLUMNAS), _mats[1], true)


# Altura de la arena en un punto local de las ruinas, relativa al centro de las ruinas.
func _altura_local(lx: float, lz: float) -> float:
	return _terreno.altura_base(position.x + lx, position.z + lz) - position.y


func _cilindro(r_arriba: float, r_abajo: float, alto: float, pos: Vector3, mat: Material, colision: bool, rot: Vector3 = Vector3.ZERO) -> void:
	var malla := CylinderMesh.new()
	malla.top_radius = r_arriba
	malla.bottom_radius = r_abajo
	malla.height = alto
	malla.radial_segments = 20
	malla.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
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


func _caja(tam: Vector3, pos: Vector3, rot: Vector3, mat: Material, colision: bool) -> void:
	var malla := BoxMesh.new()
	malla.size = tam
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	add_child(mi)
	if colision:
		var cuerpo := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var forma := BoxShape3D.new()
		forma.size = tam
		cs.shape = forma
		cuerpo.add_child(cs)
		mi.add_child(cuerpo)
