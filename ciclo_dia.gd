extends AnimationPlayer
## Ciclo de día y noche.
##
## La animación "ciclo" gira la luz del sol; este script hace el resto: según qué tan alto
## está el sol, atenúa la luz ambiente, oscurece y enfría la niebla y las nubes, apaga el sol
## y enciende una luna tenue y azulada. Los valores de DÍA son los que ya tienes en tu
## Environment y en tu DirectionalLight3D; aquí solo se ajusta cuánto cambian de noche.
##
## Se coloca como siempre (en el AnimationPlayer del ciclo) y busca solo el WorldEnvironment
## y el DirectionalLight3D que sean hermanos suyos, así que no hay que conectar nada.

@export_range(0.0, 24.0, 0.25) var hora_en_inicio: float = 6.0

@export_group("Noche")
## Cuánta luz ambiente queda de noche respecto del día (1 = igual que de día, 0 = oscuridad total).
@export_range(0.0, 1.0, 0.01) var luz_ambiente_noche: float = 0.2
## Fuerza de la luz de la luna (el sol vale su propia energía). 0 = sin luna.
@export_range(0.0, 1.0, 0.01) var fuerza_luna: float = 0.12
## Color de la luz de la luna.
@export var color_luna: Color = Color(0.55, 0.68, 1.0)
## Color de la niebla de noche. De día se usa el que tengas en el Environment.
@export var color_niebla_noche: Color = Color(0.02, 0.035, 0.07)
## Cuánta niebla hay de noche respecto del día (1 = igual).
@export_range(0.0, 2.0, 0.05) var niebla_noche: float = 1.0
## Color de las nubes de noche (de día se usa el del cielo).
@export var color_nubes_noche: Color = Color(0.05, 0.06, 0.1)

@export_group("Atardecer y amanecer")
## Hace que la luz del sol sea anaranjada cuando está bajo, cerca del horizonte.
@export var sol_anaranjado_en_horizonte: bool = true
## Color de la luz del sol justo en el horizonte.
@export var color_sol_horizonte: Color = Color(1.0, 0.55, 0.3)
## Altura del sol (0 = horizonte, 1 = justo arriba) a la que empieza a anochecer del todo.
## Más negativo = el crepúsculo dura más. Por defecto, el cielo está totalmente oscuro con el sol a -24°.
@export_range(-1.0, 0.0, 0.01) var altura_noche_total: float = -0.4

var _reloj: Node = null
var _entorno: Environment = null
var _material_cielo: ShaderMaterial = null
var _sol: DirectionalLight3D = null
var _luna: DirectionalLight3D = null

# Valores de día, tal como están en tu escena.
var _sol_energia: float = 1.0
var _sol_color: Color = Color.WHITE
var _ambiente_energia: float = 1.0
var _niebla_color: Color = Color.WHITE
var _niebla_densidad: float = 0.0
var _niebla_dispersion_sol: float = 0.0
var _color_nubes_dia: Color = Color.WHITE
var _tiene_nubes: bool = false


func _ready() -> void:
	_buscar_escena()
	_reloj = get_node_or_null("/root/Reloj")
	if _reloj == null:
		push_warning("ciclo_dia.gd: no se encontró el Autoload 'Reloj'.")
		return
	_reloj.registrar(self, hora_en_inicio)


func _exit_tree() -> void:
	if is_instance_valid(_reloj):
		_reloj.desregistrar(self)


func _process(_delta: float) -> void:
	if _sol == null:
		return

	# Altura del sol: 1 = justo arriba, 0 = en el horizonte, -1 = justo abajo.
	var hacia_el_sol: Vector3 = _sol.global_transform.basis.z.normalized()
	var altura: float = hacia_el_sol.y

	# 0 = pleno día, 1 = noche cerrada (crece de forma suave durante el atardecer).
	var noche: float = 1.0 - smoothstep(altura_noche_total, 0.04, altura)

	_actualizar_sol(altura)
	_actualizar_luna(hacia_el_sol, altura)
	_actualizar_entorno(noche)


# --- Preparación -------------------------------------------------------------------------------

func _buscar_escena() -> void:
	var raiz: Node = get_parent()
	if raiz == null:
		return
	var mundo: WorldEnvironment = null
	for hijo in raiz.get_children():
		if mundo == null and hijo is WorldEnvironment:
			mundo = hijo as WorldEnvironment
		if _sol == null and hijo is DirectionalLight3D:
			_sol = hijo as DirectionalLight3D

	if _sol == null:
		push_warning("ciclo_dia.gd: no se encontró un DirectionalLight3D junto al AnimationPlayer; solo se mueve el reloj.")
		return
	_sol_energia = _sol.light_energy
	_sol_color = _sol.light_color

	if mundo != null and mundo.environment != null:
		# Se trabaja sobre copias para no dejar valores de noche guardados en el recurso de la escena.
		_entorno = mundo.environment.duplicate() as Environment
		mundo.environment = _entorno
		_ambiente_energia = _entorno.ambient_light_energy
		_niebla_color = _entorno.fog_light_color
		_niebla_densidad = _entorno.fog_density
		_niebla_dispersion_sol = _entorno.fog_sun_scatter
		if _entorno.sky != null and _entorno.sky.sky_material is ShaderMaterial:
			var cielo: Sky = _entorno.sky.duplicate() as Sky
			_material_cielo = (cielo.sky_material as ShaderMaterial).duplicate() as ShaderMaterial
			cielo.sky_material = _material_cielo
			_entorno.sky = cielo
			var color_nubes: Variant = _material_cielo.get_shader_parameter(&"cloud_color")
			if color_nubes is Color:
				_color_nubes_dia = color_nubes
				_tiene_nubes = true
	else:
		push_warning("ciclo_dia.gd: no se encontró un WorldEnvironment junto al AnimationPlayer; solo se ajustan las luces.")

	_crear_luna(raiz)


func _crear_luna(raiz: Node) -> void:
	_luna = DirectionalLight3D.new()
	_luna.name = &"Luna"
	_luna.light_color = color_luna
	_luna.light_energy = 0.0
	_luna.shadow_enabled = true
	# Solo ilumina el mundo: el cielo sigue dibujando su propia luna y su sol.
	_luna.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_luna.visible = false
	raiz.add_child.call_deferred(_luna)


# --- Sol, luna y entorno -----------------------------------------------------------------------

func _actualizar_sol(altura: float) -> void:
	# La luz del sol se desvanece al llegar al horizonte, sin que "salte" al anochecer.
	var visible_sol: float = smoothstep(-0.04, 0.12, altura)
	# Nunca llega a 0 exacto: así el cielo siempre sigue encontrando al sol.
	_sol.light_energy = maxf(_sol_energia * visible_sol, 0.0005)
	_sol.shadow_enabled = visible_sol > 0.02

	if sol_anaranjado_en_horizonte:
		var calido: float = smoothstep(0.02, 0.45, altura)
		_sol.light_color = color_sol_horizonte.lerp(_sol_color, calido)
	else:
		_sol.light_color = _sol_color


func _actualizar_luna(hacia_el_sol: Vector3, altura: float) -> void:
	if _luna == null or not _luna.is_inside_tree():
		return
	# La luna está justo en el lado opuesto del sol; sale cuando el sol baja del horizonte.
	var presencia: float = smoothstep(0.0, 0.25, -altura)
	var energia: float = fuerza_luna * presencia
	_luna.light_color = color_luna
	_luna.light_energy = energia
	_luna.visible = energia > 0.001
	if not _luna.visible:
		return
	# La luz viaja desde la luna hacia el suelo, o sea, en la misma dirección que "hacia el sol".
	var arriba: Vector3 = Vector3.UP if absf(hacia_el_sol.y) < 0.99 else Vector3.RIGHT
	_luna.global_transform = Transform3D(Basis.looking_at(hacia_el_sol, arriba), _luna.global_position)


func _actualizar_entorno(noche: float) -> void:
	if _entorno == null:
		return
	_entorno.ambient_light_energy = lerpf(_ambiente_energia, _ambiente_energia * luz_ambiente_noche, noche)
	_entorno.fog_light_color = _niebla_color.lerp(color_niebla_noche, noche)
	_entorno.fog_density = _niebla_densidad * lerpf(1.0, niebla_noche, noche)
	_entorno.fog_sun_scatter = _niebla_dispersion_sol * (1.0 - noche)
	if _material_cielo != null and _tiene_nubes:
		_material_cielo.set_shader_parameter(&"cloud_color", _color_nubes_dia.lerp(color_nubes_noche, noche))
