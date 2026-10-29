extends Node3D
## Fondo 3D del menú principal: atardecer en el desierto, una espada clavada en la
## arena con paños rojos ondeando y arena que lleva el viento.
##
## Todo se construye por código al iniciar, así que no hay nada que arrastrar.
## Para verlo solo: abre fondo_menu.tscn y pulsa F6 (Ejecutar escena actual).
## Para ajustarlo: selecciona el nodo "FondoMenu", cambia los valores del Inspector
## y vuelve a pulsar F6.
##
## Si falta un archivo (la espada, el shader del paño...) el menú sigue funcionando
## y solo avisa en la pestaña Salida, sin romperse.

@export_group("Viento")
## 0 = calma, 1 = viento normal, 3 = tormenta. Afecta a los paños y a la arena.
@export_range(0.0, 3.0, 0.1) var fuerza_viento: float = 1.0

@export_group("Cielo y luz")
## Altura del sol sobre el horizonte, en grados. Más bajo = atardecer más rojizo.
@export_range(2.0, 40.0, 1.0) var sol_elevacion: float = 13.0
## Dónde está el sol respecto a la cámara. 0 = justo enfrente, negativo = a la izquierda.
@export_range(-90.0, 90.0, 1.0) var sol_azimut: float = -22.0

@export_group("Dunas")
## Cambia este número para obtener otro paisaje (otras dunas en el horizonte).
@export var semilla_dunas: int = 3

@export_group("Espada")
@export_range(0.5, 3.0, 0.05) var escala_espada: float = 1.5
## Inclinación en grados. Positivo = el pomo se inclina hacia la derecha.
@export_range(-30.0, 30.0, 1.0) var inclinacion_espada: float = 12.0
## Altura de la guarda sobre la arena, en metros. Más alto = menos hoja enterrada.
@export_range(0.3, 2.5, 0.05) var altura_guarda: float = 1.0
## Giro de la espada sobre sí misma, para que no quede perfectamente de frente.
@export_range(-60.0, 60.0, 1.0) var giro_espada: float = 12.0

@export_group("Cámara")
@export_range(2.0, 12.0, 0.1) var camara_distancia: float = 4.0
@export_range(0.2, 3.0, 0.05) var camara_altura: float = 0.9
## Hacia dónde mira la cámara en horizontal (negativo = a la izquierda).
## Así la espada queda a la derecha y el texto del menú tiene espacio a la izquierda.
@export_range(-4.0, 4.0, 0.1) var camara_mirar_x: float = -1.5
@export_range(0.2, 3.0, 0.05) var camara_mirar_y: float = 1.1
@export_range(20.0, 80.0, 1.0) var camara_fov: float = 42.0
## Movimiento suave de la cámara (0 = quieta).
@export_range(0.0, 2.0, 0.1) var vaiven_camara: float = 1.0

const RUTA_ESPADA := "res://espada_negra.glb"
const RUTA_DUNAS := "res://dunas.tscn"
const RUTA_SHADER_CIELO := "res://SourceCode/shader/main.gdshader"
const RUTA_SHADER_TELA := "res://tela_viento.gdshader"
const RUTA_NUBES_1 := "res://SourceCode/textures/clouds/clouds_03.tres"
const RUTA_NUBES_2 := "res://SourceCode/textures/clouds/clouds_04.tres"
const RUTA_ESTRELLAS := "res://stars/Nebula Blue.png"

# El viento sopla de derecha a izquierda de la pantalla (hacia -X) y un poco hacia arriba.
# Los paños y las partículas de más abajo usan esa dirección.

# Los paños: largo y ancho (metros), ángulo hacia arriba (grados), fase y desplazamiento vertical.
const TELAS: Array = [
	{"largo": 1.9, "ancho": 0.34, "angulo": 6.0, "fase": 0.0, "dy": 0.0},
	{"largo": 1.3, "ancho": 0.22, "angulo": -10.0, "fase": 2.1, "dy": -0.05},
	{"largo": 0.9, "ancho": 0.16, "angulo": 16.0, "fase": 4.0, "dy": 0.06},
]

var _camara: Camera3D
var _camara_base: Vector3
var _tiempo: float = 0.0
var _malla_particula: QuadMesh


func _ready() -> void:
	_crear_entorno()
	_crear_sol()
	_crear_dunas()
	var espada := _crear_espada()
	if espada != null:
		# El paño se ata en la parte alta de la empuñadura (cerca del pomo).
		_crear_telas(espada.to_global(Vector3(0.0, -0.30, 0.0)))
	_crear_arena_en_el_aire()
	_crear_camara()


func _process(delta: float) -> void:
	if _camara == null:
		return
	# Un balanceo muy leve de la cámara da sensación de vida y de aire.
	_tiempo += delta
	var vaiven := Vector3(sin(_tiempo * 0.37) * 0.07, sin(_tiempo * 0.53) * 0.04, sin(_tiempo * 0.29) * 0.06)
	_camara.position = _camara_base + vaiven * vaiven_camara


# ---------------------------------------------------------------- Cielo, luz y niebla

func _crear_entorno() -> void:
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_SKY
	entorno.sky = _crear_cielo()
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	entorno.ambient_light_energy = 0.9
	entorno.tonemap_mode = Environment.TONE_MAPPER_ACES
	entorno.glow_enabled = true
	entorno.glow_intensity = 0.7
	entorno.glow_bloom = 0.08
	# La niebla cálida es lo que da la sensación de arena en el aire y de distancia.
	entorno.fog_enabled = true
	entorno.fog_light_color = Color(0.86, 0.66, 0.43)
	entorno.fog_density = 0.013
	entorno.fog_aerial_perspective = 0.7
	entorno.fog_sky_affect = 0.2
	entorno.fog_sun_scatter = 0.5
	entorno.adjustment_enabled = true
	entorno.adjustment_saturation = 1.05
	entorno.adjustment_contrast = 1.08

	var mundo := WorldEnvironment.new()
	mundo.environment = entorno
	add_child(mundo)


func _crear_cielo() -> Sky:
	var cielo := Sky.new()
	if ResourceLoader.exists(RUTA_SHADER_CIELO):
		# Es el mismo cielo con nubes que usa el juego, con colores de atardecer polvoriento.
		var material := ShaderMaterial.new()
		material.shader = load(RUTA_SHADER_CIELO) as Shader
		material.set_shader_parameter("use_directional_light", true)
		material.set_shader_parameter("horizon_sunset", Color(1.0, 0.68, 0.34))
		material.set_shader_parameter("sky_sunset", Color(0.22, 0.20, 0.25))
		material.set_shader_parameter("horizon_day", Color(0.90, 0.75, 0.55))
		material.set_shader_parameter("sky_day", Color(0.35, 0.38, 0.48))
		material.set_shader_parameter("cloud_color", Color(0.45, 0.33, 0.27))
		material.set_shader_parameter("cloud_density", 1.3)
		material.set_shader_parameter("cloud_depth", 2.0)
		material.set_shader_parameter("wind_speed", Vector2(-0.12, 0.05))
		material.set_shader_parameter("sun_color", Color(1.0, 0.78, 0.45))
		material.set_shader_parameter("sun_strength", 14.0)
		material.set_shader_parameter("sun_scale", 0.04)
		if ResourceLoader.exists(RUTA_NUBES_1):
			material.set_shader_parameter("cloud_tex_01", load(RUTA_NUBES_1))
		if ResourceLoader.exists(RUTA_NUBES_2):
			material.set_shader_parameter("cloud_tex_02", load(RUTA_NUBES_2))
		if ResourceLoader.exists(RUTA_ESTRELLAS):
			material.set_shader_parameter("night_noise_01", load(RUTA_ESTRELLAS))
		cielo.sky_material = material
	else:
		push_warning("FondoMenu: no se encontró '%s'; se usa un cielo sencillo." % RUTA_SHADER_CIELO)
		var simple := ProceduralSkyMaterial.new()
		simple.sky_top_color = Color(0.25, 0.24, 0.30)
		simple.sky_horizon_color = Color(0.95, 0.68, 0.38)
		simple.ground_horizon_color = Color(0.80, 0.62, 0.40)
		simple.ground_bottom_color = Color(0.45, 0.33, 0.20)
		cielo.sky_material = simple
	return cielo


func _crear_sol() -> void:
	var sol := DirectionalLight3D.new()
	sol.light_color = Color(1.0, 0.74, 0.45)
	sol.light_energy = 2.4
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 90.0
	add_child(sol)

	# Vector que apunta HACIA el sol (la cámara mira hacia -Z).
	var elevacion: float = deg_to_rad(sol_elevacion)
	var azimut: float = deg_to_rad(sol_azimut)
	var hacia_el_sol := Vector3(sin(azimut) * cos(elevacion), sin(elevacion), -cos(azimut) * cos(elevacion))
	# La luz viaja desde el sol hacia la escena, o sea en sentido contrario.
	# El cielo también usa esta dirección para dibujar el sol.
	sol.look_at_from_position(Vector3.ZERO, -hacia_el_sol, Vector3.UP)


# ---------------------------------------------------------------- Terreno

func _crear_dunas() -> void:
	if not ResourceLoader.exists(RUTA_DUNAS):
		push_warning("FondoMenu: no se encontró '%s'; se usa un suelo plano." % RUTA_DUNAS)
		var suelo := MeshInstance3D.new()
		var plano := PlaneMesh.new()
		plano.size = Vector2(800.0, 800.0)
		suelo.mesh = plano
		suelo.material_override = _crear_material_arena(false)
		add_child(suelo)
		return

	# Se reutilizan tus dunas (dunas.tscn) con otros valores. El centro (donde está
	# la espada) es una zona plana a altura 0.
	var dunas := (load(RUTA_DUNAS) as PackedScene).instantiate()
	dunas.set("tamano", 400.0)
	dunas.set("celdas", 260)
	dunas.set("amplitud", 8.0)
	dunas.set("escala_dunas", 70.0)
	dunas.set("estiramiento", 2.4)
	dunas.set("direccion_viento", 15.0)
	dunas.set("rugosidad", 0.05)
	dunas.set("semilla", semilla_dunas)
	dunas.set("radio_plano", 10.0)
	dunas.set("transicion", 28.0)
	dunas.set("material_arena", _crear_material_arena(true))
	add_child(dunas)


func _crear_material_arena(con_ondas: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.78, 0.60, 0.38)
	material.roughness = 0.95
	if con_ondas:
		# Las ondas finas de la arena (rizos) se fingen con un mapa de normales de ruido.
		var ruido := FastNoiseLite.new()
		ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		ruido.frequency = 0.06
		var textura := NoiseTexture2D.new()
		textura.width = 512
		textura.height = 512
		textura.noise = ruido
		textura.seamless = true
		textura.as_normal_map = true
		textura.bump_strength = 3.0
		material.normal_enabled = true
		material.normal_texture = textura
		material.normal_scale = 0.8
		# Estira los rizos a lo largo del eje Z: quedan perpendiculares al viento.
		material.uv1_scale = Vector3(1.0, 0.25, 1.0)
	return material


# ---------------------------------------------------------------- Espada y paños

func _crear_espada() -> Node3D:
	if not ResourceLoader.exists(RUTA_ESPADA):
		push_warning("FondoMenu: no se encontró '%s'. El menú se verá sin espada." % RUTA_ESPADA)
		return null
	var escena := load(RUTA_ESPADA) as PackedScene
	if escena == null:
		push_warning("FondoMenu: '%s' no se pudo cargar como escena." % RUTA_ESPADA)
		return null
	var espada := escena.instantiate() as Node3D
	if espada == null:
		return null
	add_child(espada)

	# Acero negro para todas las piezas.
	var acero := StandardMaterial3D.new()
	acero.albedo_color = Color(0.07, 0.07, 0.085)
	acero.metallic = 0.9
	acero.roughness = 0.35
	for pieza in espada.find_children("*", "MeshInstance3D", true, false):
		(pieza as MeshInstance3D).material_override = acero

	# La espada está de cabeza: el pomo arriba y la punta hacia la arena.
	# En el modelo la hoja apunta a +Y y el origen está en la base de la hoja.
	var inclinacion: float = deg_to_rad(inclinacion_espada)
	var giro: float = deg_to_rad(giro_espada)
	espada.scale = Vector3.ONE * escala_espada
	espada.rotation_degrees = Vector3(0.0, giro_espada, 180.0 - inclinacion_espada)
	# Se coloca para que la hoja entre en la arena justo en el punto (0, 0, 0).
	var desplazamiento: float = altura_guarda * tan(inclinacion)
	espada.position = Vector3(desplazamiento * cos(giro), altura_guarda, -desplazamiento * sin(giro))

	# Un pequeño montículo de arena tapa el punto donde la hoja entra al suelo.
	var monticulo := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.6
	esfera.height = 1.2
	monticulo.mesh = esfera
	monticulo.material_override = _crear_material_arena(false)
	monticulo.scale = Vector3(1.0, 0.22, 1.0)
	add_child(monticulo)
	return espada


func _crear_telas(punto_de_atado: Vector3) -> void:
	for i in range(TELAS.size()):
		var datos: Dictionary = TELAS[i]
		var largo: float = datos["largo"]
		var tela := MeshInstance3D.new()
		tela.mesh = _crear_malla_tela(largo, datos["ancho"])
		tela.material_override = _crear_material_tela(largo, datos["fase"])
		add_child(tela)
		# Un pequeño desfase en profundidad evita que los paños "parpadeen" al cruzarse.
		tela.global_position = punto_de_atado + Vector3(0.0, datos["dy"], 0.015 * float(i))
		# El eje +X de la tira apunta hacia donde sopla el viento (a la izquierda de la pantalla).
		tela.rotation_degrees = Vector3(0.0, 180.0, datos["angulo"])


# Una tira plana de largo x ancho. UV.x va del nudo (0) a la punta (1); el shader la mueve.
func _crear_malla_tela(largo: float, ancho: float) -> ArrayMesh:
	var segmentos_largo: int = 32
	var segmentos_ancho: int = 4
	var vertices := PackedVector3Array()
	var normales := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for i in range(segmentos_largo + 1):
		var t: float = float(i) / float(segmentos_largo)
		for j in range(segmentos_ancho + 1):
			var v: float = float(j) / float(segmentos_ancho)
			vertices.append(Vector3(t * largo, (v - 0.5) * ancho, 0.0))
			normales.append(Vector3(0.0, 0.0, 1.0))
			uvs.append(Vector2(t, v))

	for i in range(segmentos_largo):
		for j in range(segmentos_ancho):
			var a: int = i * (segmentos_ancho + 1) + j
			var b: int = a + 1
			var c: int = a + segmentos_ancho + 1
			var d: int = c + 1
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normales
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# El shader mueve los vértices fuera de la caja original: se agranda para que
	# la tela no desaparezca cuando la cámara "cree" que está fuera de pantalla.
	malla.custom_aabb = AABB(Vector3(-largo, -largo, -largo), Vector3(largo * 3.0, largo * 2.0, largo * 2.0))
	return malla


func _crear_material_tela(largo: float, fase: float) -> Material:
	if ResourceLoader.exists(RUTA_SHADER_TELA):
		var material := ShaderMaterial.new()
		material.shader = load(RUTA_SHADER_TELA) as Shader
		material.set_shader_parameter("largo", largo)
		material.set_shader_parameter("fase", fase)
		material.set_shader_parameter("fuerza_viento", fuerza_viento)
		return material
	push_warning("FondoMenu: no se encontró '%s'; los paños quedarán quietos." % RUTA_SHADER_TELA)
	var simple := StandardMaterial3D.new()
	simple.albedo_color = Color(0.32, 0.04, 0.05)
	simple.cull_mode = BaseMaterial3D.CULL_DISABLED
	return simple


# ---------------------------------------------------------------- Arena en el aire

func _crear_arena_en_el_aire() -> void:
	# Cuanto más viento, más rápida pasa la arena.
	var v: float = 0.4 + 0.6 * fuerza_viento

	# 1) Remolino de polvo en la base de la espada.
	_agregar_particulas({
		"cantidad": 70, "vida": 2.8,
		"caja": Vector3(0.35, 0.05, 0.35), "posicion": Vector3(0.0, 0.1, 0.05),
		"direccion": Vector3(-1.0, 0.3, 0.05), "dispersion": 22.0,
		"vel_min": 0.8 * v, "vel_max": 2.4 * v, "gravedad": Vector3(-0.4 * v, 0.1, 0.0),
		"tam_min": 0.4, "tam_max": 1.0, "color": Color(0.80, 0.62, 0.40), "alfa": 0.55,
	})
	# 2) Polvo que corre pegado al suelo, de derecha a izquierda.
	_agregar_particulas({
		"cantidad": 90, "vida": 4.0,
		"caja": Vector3(2.5, 0.04, 3.5), "posicion": Vector3(4.5, 0.12, 0.6),
		"direccion": Vector3(-1.0, 0.06, 0.0), "dispersion": 8.0,
		"vel_min": 2.5 * v, "vel_max": 4.5 * v, "gravedad": Vector3(0.0, 0.0, 0.0),
		"tam_min": 0.7, "tam_max": 1.6, "color": Color(0.82, 0.65, 0.42), "alfa": 0.16,
	})
	# 3) Granos finos que cruzan la imagen: son los que se notan como "viento".
	_agregar_particulas({
		"cantidad": 260, "vida": 2.6,
		"caja": Vector3(3.5, 0.9, 3.0), "posicion": Vector3(5.0, 0.9, 0.0),
		"direccion": Vector3(-1.0, 0.02, 0.03), "dispersion": 4.0,
		"vel_min": 5.0 * v, "vel_max": 9.0 * v, "gravedad": Vector3(0.0, -0.3, 0.0),
		"tam_min": 0.012, "tam_max": 0.03, "color": Color(0.92, 0.74, 0.48), "alfa": 0.9,
	})


func _agregar_particulas(p: Dictionary) -> void:
	var particulas := CPUParticles3D.new()
	particulas.amount = p["cantidad"]
	particulas.lifetime = p["vida"]
	particulas.lifetime_randomness = 0.4
	# Ya viene "en marcha": al abrir el menú el aire ya está lleno de arena.
	particulas.preprocess = p["vida"]
	particulas.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particulas.emission_box_extents = p["caja"]
	particulas.direction = p["direccion"]
	particulas.spread = p["dispersion"]
	particulas.initial_velocity_min = p["vel_min"]
	particulas.initial_velocity_max = p["vel_max"]
	particulas.gravity = p["gravedad"]
	particulas.scale_amount_min = p["tam_min"]
	particulas.scale_amount_max = p["tam_max"]
	particulas.color = p["color"]
	particulas.color_ramp = _crear_rampa_alfa(p["alfa"])
	particulas.mesh = _crear_malla_particula()
	add_child(particulas)
	particulas.global_position = p["posicion"]


# Cada partícula aparece, se ve y se desvanece suavemente.
func _crear_rampa_alfa(alfa_max: float) -> Gradient:
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	rampa.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, alfa_max),
		Color(1.0, 1.0, 1.0, alfa_max * 0.6),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	return rampa


# Un cuadrado que siempre mira a la cámara, con un círculo suave dibujado por código.
func _crear_malla_particula() -> QuadMesh:
	if _malla_particula != null:
		return _malla_particula

	var degradado := Gradient.new()
	degradado.offsets = PackedFloat32Array([0.0, 1.0])
	degradado.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.0)])
	var textura := GradientTexture2D.new()
	textura.gradient = degradado
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1.0, 0.5)
	textura.width = 64
	textura.height = 64

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = textura

	var cuadrado := QuadMesh.new()
	cuadrado.size = Vector2(1.0, 1.0)
	cuadrado.material = material
	_malla_particula = cuadrado
	return cuadrado


# ---------------------------------------------------------------- Cámara

func _crear_camara() -> void:
	_camara = Camera3D.new()
	_camara.fov = camara_fov
	_camara.far = 600.0
	add_child(_camara)
	_camara.current = true
	_camara_base = Vector3(0.0, camara_altura, camara_distancia)
	_camara.position = _camara_base
	_camara.look_at(Vector3(camara_mirar_x, camara_mirar_y, 0.0))
