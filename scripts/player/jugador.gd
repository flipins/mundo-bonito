extends CharacterBody3D

# Diferentes velocidades
const WALK_SPEED = 5.0
const SPRINT_SPEED = 9.0
const CROUCH_SPEED = 2.0
const JUMP_VELOCITY = 4.5

## Cámara en tercera persona (detrás del jugador). Si lo apagas vuelve la cámara en primera persona.
@export var tercera_persona: bool = true

@export_group("Cámara en tercera persona")
## A qué distancia queda la cámara detrás del jugador, en metros.
@export var distancia_camara: float = 4.5
## Cuánto se corre la cámara hacia la derecha (positivo) o la izquierda (negativo), en metros.
## 0 = centrada justo detrás del jugador.
@export var desplazamiento_hombro: float = 0.45
## Cuánto sube el punto al que mira la cámara sobre la altura de los ojos, en metros.
@export var altura_extra: float = 0.1
## Hasta dónde puede mirar hacia abajo (negativo), en grados. Más negativo = cámara más alta.
@export_range(-89.0, 0.0, 1.0) var angulo_minimo: float = -70.0
## Hasta dónde puede mirar hacia arriba (positivo), en grados. Más alto = cámara más baja.
@export_range(0.0, 89.0, 1.0) var angulo_maximo: float = 35.0
## Qué tan rápido gira el personaje hacia donde camina (más alto = giro más brusco).
@export var velocidad_giro: float = 12.0
## Qué tan pegada sigue la cámara al jugador (más alto = más pegada, más bajo = más suave).
@export var suavizado_camara: float = 18.0
## Margen con las dunas y los objetos, para que la cámara no se meta dentro de ellos, en metros.
@export var margen_colision: float = 0.3
## Dibuja una visera oscura al frente de la cápsula para ver hacia dónde mira el personaje
## (apágalo cuando tengas el modelo real).
@export var mostrar_visera: bool = true

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera: Camera3D = $Camera3D
@onready var altura_original_camara: float = camera.position.y # Guarda la altura inicial de tu cámara
var sensibilidad = 0.003

# Estado de la cámara en tercera persona.
var _yaw: float = 0.0
var _pitch: float = deg_to_rad(-12.0)
var _pivote: Vector3 = Vector3.ZERO
var _altura_pivote: float = 0.0
var _distancia_actual: float = 0.0
var _distancia_objetivo: float = 0.0
var _agachado_t: float = 0.0

# Cuerpo visible (la cápsula) para agacharlo y dibujarle la visera.
var _malla: MeshInstance3D
var _malla_y_base: float = 0.0
var _malla_alto: float = 2.0


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if tercera_persona:
		_preparar_tercera_persona()


func _unhandled_input(event):
	if event is InputEventMouseMotion:
		var giro: float = sensibilidad * Ajustes.sensibilidad
		if tercera_persona:
			# El mouse mueve la cámara alrededor del jugador, no al jugador.
			_yaw -= event.relative.x * giro
			_pitch = clampf(_pitch - event.relative.y * giro, deg_to_rad(angulo_minimo), deg_to_rad(angulo_maximo))
		else:
			rotate_y(-event.relative.x * giro)
			camera.rotate_x(-event.relative.y * giro)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))


func _process(delta):
	if tercera_persona:
		_actualizar_camara(delta, false)


func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Por defecto la velocidad es la de caminar
	var current_speed = WALK_SPEED

	# Sistema para correr
	if Input.is_action_pressed("correr"):
		current_speed = SPRINT_SPEED

	# Sistema para agacharse
	var agachado: bool = Input.is_action_pressed("agacharse")
	if agachado:
		current_speed = CROUCH_SPEED

	if tercera_persona:
		# Baja el punto de la cámara y achata un poco el cuerpo, de forma suave
		_agachado_t = move_toward(_agachado_t, 1.0 if agachado else 0.0, delta * 10.0)
		_altura_pivote = altura_original_camara + altura_extra - 0.5 * _agachado_t
		_agachar_malla()
	else:
		# Baja la cámara de forma suave y la devuelve a su altura original al soltar
		var altura_objetivo: float = altura_original_camara - (0.5 if agachado else 0.0)
		camera.position.y = move_toward(camera.position.y, altura_objetivo, delta * 5.0)

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction: Vector3
	if tercera_persona:
		# Se camina hacia donde mira la cámara, y el personaje gira hacia donde avanza.
		direction = (Basis(Vector3.UP, _yaw) * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if direction != Vector3.ZERO:
			var giro_objetivo: float = atan2(-direction.x, -direction.z)
			rotation.y = lerp_angle(rotation.y, giro_objetivo, 1.0 - exp(-velocidad_giro * delta))
	else:
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction != Vector3.ZERO:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()

	if tercera_persona:
		_calcular_distancia_libre()


# --- Cámara en tercera persona -----------------------------------------------------------------

func _preparar_tercera_persona() -> void:
	# La cámara empieza detrás de hacia donde mira el jugador.
	_yaw = rotation.y
	_altura_pivote = altura_original_camara + altura_extra
	_distancia_actual = distancia_camara
	_distancia_objetivo = distancia_camara
	_pivote = global_position + Vector3(0.0, _altura_pivote, 0.0)

	# La cámara deja de girar con el cuerpo: se coloca a mano en cada cuadro.
	camera.top_level = true

	# El rayo de interacción nace en la cámara: se alarga lo que la cámara queda de lejos,
	# para que el jugador siga alcanzando lo mismo que antes.
	for hijo in camera.get_children():
		if hijo is RayCast3D:
			var rayo := hijo as RayCast3D
			rayo.target_position += Vector3(0.0, 0.0, -distancia_camara)

	_malla = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if _malla != null and _malla.mesh != null:
		_malla_y_base = _malla.position.y
		_malla_alto = _malla.mesh.get_aabb().size.y * _malla.scale.y
		if mostrar_visera:
			_crear_visera()

	_actualizar_camara(0.0, true)


# Coloca la cámara detrás del jugador según hacia dónde mira con el mouse.
func _actualizar_camara(delta: float, instantaneo: bool) -> void:
	var objetivo: Vector3 = global_position + Vector3(0.0, _altura_pivote, 0.0)
	if instantaneo:
		_pivote = objetivo
		_distancia_actual = _distancia_objetivo
	else:
		# Sigue al jugador con un poco de suavidad, para que no tiemble al caminar.
		_pivote = _pivote.lerp(objetivo, 1.0 - exp(-suavizado_camara * delta))
		# Se acerca rápido si hay algo en medio y se aleja despacio cuando se despeja.
		var rapidez: float = 25.0 if _distancia_objetivo < _distancia_actual else 4.0
		_distancia_actual = lerpf(_distancia_actual, _distancia_objetivo, 1.0 - exp(-rapidez * delta))

	var rotacion := Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
	var origen: Vector3 = _pivote + rotacion * Vector3(desplazamiento_hombro, 0.0, 0.0)
	camera.global_transform = Transform3D(rotacion, origen + rotacion.z * _distancia_actual)


# Mira si hay una duna o un objeto entre el jugador y la cámara, y acerca la cámara si lo hay.
func _calcular_distancia_libre() -> void:
	var rotacion := Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
	var origen: Vector3 = global_position + Vector3(0.0, _altura_pivote, 0.0) + rotacion * Vector3(desplazamiento_hombro, 0.0, 0.0)
	var destino: Vector3 = origen + rotacion.z * (distancia_camara + margen_colision)

	# El rayo ignora al propio jugador.
	var excluir: Array[RID] = [get_rid()]
	var consulta := PhysicsRayQueryParameters3D.create(origen, destino)
	consulta.exclude = excluir

	var resultado: Dictionary = get_world_3d().direct_space_state.intersect_ray(consulta)
	if resultado.is_empty():
		_distancia_objetivo = distancia_camara
	else:
		var punto: Vector3 = resultado["position"]
		_distancia_objetivo = clampf(origen.distance_to(punto) - margen_colision, 0.3, distancia_camara)


# --- Cuerpo visible ----------------------------------------------------------------------------

# Achata un poco la cápsula al agacharse, sin despegarla del suelo.
func _agachar_malla() -> void:
	if _malla == null:
		return
	var factor: float = 1.0 - 0.25 * _agachado_t
	_malla.scale.y = factor
	_malla.position.y = _malla_y_base - (1.0 - factor) * _malla_alto * 0.5


# Una visera oscura al frente de la cápsula: como la cápsula es igual por todos lados,
# sin esto no se vería hacia dónde mira el personaje.
func _crear_visera() -> void:
	var radio: float = 0.35
	if _malla.mesh is CapsuleMesh:
		radio = (_malla.mesh as CapsuleMesh).radius

	var caja := BoxMesh.new()
	caja.size = Vector3(radio * 1.1, 0.1, 0.14)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 0.1, 0.12)

	var visera := MeshInstance3D.new()
	visera.name = "Visera"
	visera.mesh = caja
	visera.material_override = material
	visera.position = Vector3(0.0, _malla_alto * 0.22, -radio)
	_malla.add_child(visera)
