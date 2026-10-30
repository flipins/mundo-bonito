extends Area3D
## Zona de historia (escena 3, la caminata): un lugar del camino que muestra un texto
## la primera vez que el jugador lo pisa.
##
## Cómo se usa:
##  - Se coloca (como hijo de "CaminataDesierto") en el punto del camino donde quieres el hallazgo.
##  - Se escribe el texto en el Inspector y se ajusta el tamaño de la caja de colisión.
##  - Al jugar se apoya sola sobre el terreno y dibuja un marcador visible (un haz de luz
##    alto y un anillo en el suelo) para que el jugador vea de lejos adónde ir.
##  - No detecta nada hasta que el gestor de la caminata la "arma" (al terminar el tutorial),
##    así que el jugador no activa textos antes de tiempo.
##  - El orden de las zonas en el árbol de nodos es el orden del camino.

## Se emite la primera (y única) vez que el jugador pisa la zona ya armada.
signal activada(zona: Area3D)

## Lo que se muestra en pantalla al pisar la zona. Déjalo vacío para una zona muda.
@export_multiline var texto: String = "Escribe aquí lo que descubre el jugador."
## Marca la última zona del camino (junto a la espada): al pisarla, el gestor emite "llego_a_la_espada".
@export var es_final: bool = false

@export_group("Marcador visible")
## Dibuja el haz de luz y el anillo para guiar al jugador. Si lo apagas, la zona queda invisible.
@export var mostrar_marcador_en_juego: bool = true
## Color del marcador. El celeste resalta sobre la arena; para la espada va bien el dorado.
@export var color_marcador: Color = Color(0.3, 0.9, 1.0, 1.0)
## Altura del haz de luz, en metros (que se vea por encima de las dunas).
@export var altura_haz: float = 60.0
## Radio del haz de luz, en metros.
@export var grosor_haz: float = 0.5
## Qué tan fuerte se ve el marcador (0 = invisible, 1 = opaco).
@export_range(0.0, 1.0, 0.05) var intensidad_marcador: float = 0.45

@export_group("Terreno")
## Al empezar el juego, baja la zona hasta apoyarla sobre el terreno (como PegarAlSuelo).
@export var ajustar_al_terreno: bool = true
## Desde qué altura sobre la zona se empieza a buscar el suelo, en metros.
@export var altura_busqueda: float = 100.0

# Un solo shader sirve para el haz y el anillo: color plano, sin luz, que ignora la niebla
# (así se ve a través de la bruma del desierto), con un pulso suave y que se desvanece hacia arriba.
const SHADER_MARCADOR := """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, depth_draw_never;

uniform vec4 color : source_color = vec4(0.3, 0.9, 1.0, 1.0);
uniform float intensidad : hint_range(0.0, 1.0) = 0.4;
uniform float alto = 60.0;
uniform float desvanecer = 0.75;

varying float altura;

void vertex() {
	altura = VERTEX.y;
}

void fragment() {
	float t = clamp(altura / alto + 0.5, 0.0, 1.0);
	float pulso = 0.8 + 0.2 * sin(TIME * 2.5);
	ALBEDO = color.rgb;
	ALPHA = intensidad * pulso * (1.0 - t * desvanecer);
}
"""

var _armada: bool = false
var _usada: bool = false

var _marcador: Node3D
var _material_haz: ShaderMaterial
var _material_anillo: ShaderMaterial
var _nivel: float = 0.0
var _tween: Tween


func _ready() -> void:
	# Hasta que la armen no detecta a nadie.
	monitoring = false
	body_entered.connect(_al_entrar)
	if mostrar_marcador_en_juego:
		_crear_marcador()
	if ajustar_al_terreno:
		_ajustar_al_terreno()


## La deja lista para detectar al jugador (la llama el gestor de la caminata).
func armar() -> void:
	if _armada or _usada:
		return
	_armada = true
	set_deferred("monitoring", true)


func desarmar() -> void:
	_armada = false
	set_deferred("monitoring", false)


func fue_usada() -> bool:
	return _usada


## Muestra u oculta el marcador con un fundido (la llama el gestor de la caminata).
func mostrar_marcador(activo: bool) -> void:
	if _marcador == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_poner_nivel, _nivel, 1.0 if activo else 0.0, 1.2)


func _al_entrar(cuerpo: Node3D) -> void:
	if not _armada or _usada:
		return
	# Solo el jugador (el único CharacterBody3D del mundo) activa la zona.
	if not cuerpo is CharacterBody3D:
		return
	_usada = true
	set_deferred("monitoring", false)
	mostrar_marcador(false)
	activada.emit(self)


# --- Marcador ----------------------------------------------------------------------------------

func _crear_marcador() -> void:
	var shader := Shader.new()
	shader.code = SHADER_MARCADOR

	_marcador = Node3D.new()
	_marcador.name = "Marcador"
	add_child(_marcador)

	# Haz de luz vertical, alto para verse por encima de las dunas.
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = grosor_haz
	cilindro.bottom_radius = grosor_haz
	cilindro.height = altura_haz
	cilindro.radial_segments = 24
	cilindro.rings = 1
	cilindro.cap_top = false
	cilindro.cap_bottom = false
	_material_haz = _crear_material(shader, altura_haz, 0.75)
	var haz := MeshInstance3D.new()
	haz.mesh = cilindro
	haz.material_override = _material_haz
	haz.position.y = altura_haz * 0.5
	haz.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marcador.add_child(haz)

	# Anillo en el suelo con el tamaño de la zona: muestra dónde hay que pisar.
	var radio := _radio_de_la_zona()
	var toro := TorusMesh.new()
	toro.inner_radius = maxf(radio - 0.3, 0.1)
	toro.outer_radius = radio + 0.3
	toro.rings = 48
	toro.ring_segments = 8
	_material_anillo = _crear_material(shader, 1.0, 0.0)
	var anillo := MeshInstance3D.new()
	anillo.mesh = toro
	anillo.material_override = _material_anillo
	anillo.scale = Vector3(1.0, 0.12, 1.0)
	anillo.position.y = 0.1
	anillo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marcador.add_child(anillo)

	# Empieza escondido: el gestor lo muestra cuando le toca a esta zona.
	_poner_nivel(0.0)


func _crear_material(shader: Shader, alto: float, desvanecer: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"color", color_marcador)
	material.set_shader_parameter(&"intensidad", 0.0)
	material.set_shader_parameter(&"alto", alto)
	material.set_shader_parameter(&"desvanecer", desvanecer)
	return material


func _poner_nivel(valor: float) -> void:
	_nivel = valor
	_material_haz.set_shader_parameter(&"intensidad", intensidad_marcador * valor)
	_material_anillo.set_shader_parameter(&"intensidad", minf(intensidad_marcador * 1.6, 1.0) * valor)
	_marcador.visible = valor > 0.001


# El anillo mide lo mismo que la caja (o esfera, o cilindro) de colisión de la zona.
func _radio_de_la_zona() -> float:
	for hijo in get_children():
		if hijo is CollisionShape3D:
			var forma := (hijo as CollisionShape3D).shape
			if forma is BoxShape3D:
				var tamano := (forma as BoxShape3D).size
				return minf(tamano.x, tamano.z) * 0.5
			if forma is SphereShape3D:
				return (forma as SphereShape3D).radius
			if forma is CylinderShape3D:
				return (forma as CylinderShape3D).radius
	return 3.0


# --- Terreno -----------------------------------------------------------------------------------

func _ajustar_al_terreno() -> void:
	# El terreno crea su colisión al iniciar; se espera a que la física esté lista.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return

	var origen: Vector3 = global_position + Vector3.UP * altura_busqueda
	var destino: Vector3 = global_position + Vector3.DOWN * altura_busqueda
	var consulta := PhysicsRayQueryParameters3D.create(origen, destino)
	var resultado: Dictionary = get_world_3d().direct_space_state.intersect_ray(consulta)
	if resultado.is_empty():
		push_warning("ZonaHistoria '%s': no se encontró terreno debajo; revisa su posición." % name)
		return

	var punto: Vector3 = resultado["position"]
	global_position.y = punto.y
