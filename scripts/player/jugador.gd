extends CharacterBody3D
 
# Diferentes velocidades
const WALK_SPEED = 5.0
const SPRINT_SPEED = 9.0
const CROUCH_SPEED = 2.0
const JUMP_VELOCITY = 4.5
 
## Cámara en tercera persona (detrás del jugador). Si lo apagas vuelve la cámara en primera persona.
@export var tercera_persona: bool = true
 
@export_group("Salto")
## Con el salto en curso (despegue, aire y aterrizaje) no se puede correr ni cambiar de dirección.
## Al aterrizar el personaje frena con esta fuerza (metros por segundo cada segundo).
@export var frenado_aterrizaje: float = 40.0
## Qué tan rápido puedes cambiar de dirección en el aire (metros por segundo cada segundo).
## 0 = el salto sigue recto sin importar las teclas; más alto = giras más rápido.
@export var control_aire: float = 35.0
## Velocidad máxima en el aire si saltas casi quieto (si saltas corriendo, se conserva esa velocidad).
@export var velocidad_aire_minima: float = 5.0
 
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
 
@export_group("Agacharse")
## Altura de la colisión al agacharse, en metros. Debe ser menor que la altura del pasaje de
## los techos bajos (altura_pasaje en GrietaDesierto). Nunca baja del doble del radio de la cápsula.
@export_range(0.8, 1.8, 0.05) var altura_agachado: float = 1.1
 
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
 
@onready var camera: Camera3D = $Camera3D
@onready var altura_original_camara: float = camera.position.y # Guarda la altura inicial de tu cámara
# El maniquí (con animar_maniqui.gd) avisa cuándo se puede mover. Si no existe, nunca se bloquea.
@onready var _maniqui: Node = get_node_or_null("UAL1_Standard")
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
 
# Colisión del jugador, que se achata al agacharse.
var _colision: CollisionShape3D
var _forma: CapsuleShape3D
var _alto_pie: float = 2.0
var _colision_y_base: float = 0.0
var _agachado_real: bool = false
 
# Velocidad horizontal que llevabas la última vez que pisaste el suelo (límite de velocidad en el aire).
var _velocidad_suelo: float = 0.0
 
 
func _ready():
	_preparar_colision()
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
 
 
# true mientras dura el salto completo (lo decide el script del maniquí).
func _movimiento_bloqueado() -> bool:
	if _maniqui == null:
		return false
	var puede: Variant = _maniqui.get("puede_moverse")
	return puede != null and not puede
 
 
func _physics_process(delta):
	if is_on_floor():
		_velocidad_suelo = Vector2(velocity.x, velocity.z).length()
	else:
		velocity.y -= gravity * delta
 
	var bloqueado: bool = _movimiento_bloqueado()
 
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not bloqueado:
		velocity.y = JUMP_VELOCITY
 
	# Por defecto la velocidad es la de caminar
	var current_speed = WALK_SPEED
 
	# Sistema para correr
	if Input.is_action_pressed("correr"):
		current_speed = SPRINT_SPEED
 
	# Sistema para agacharse. Si hay un techo encima, se sigue agachado aunque sueltes la tecla.
	var agachado: bool = Input.is_action_pressed("agacharse") or (_agachado_real and not _puede_levantarse())
	_agachado_real = agachado
	_aplicar_altura_colision(agachado)
	if agachado:
		current_speed = CROUCH_SPEED
 
	if tercera_persona:
		# Baja el punto de la cámara y achata un poco el cuerpo, de forma suave
		_agachado_t = move_toward(_agachado_t, 1.0 if agachado else 0.0, delta * 10.0)
		_altura_pivote = altura_original_camara + altura_extra - _bajada_al_agacharse() * _agachado_t
		_agachar_malla()
	else:
		# Baja la cámara de forma suave y la devuelve a su altura original al soltar
		var altura_objetivo: float = altura_original_camara - (_bajada_al_agacharse() if agachado else 0.0)
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
 
	if bloqueado:
		if is_on_floor():
			# Aterrizaje: se frena hasta quedar quieto.
			velocity.x = move_toward(velocity.x, 0.0, frenado_aterrizaje * delta)
			velocity.z = move_toward(velocity.z, 0.0, frenado_aterrizaje * delta)
		elif direction != Vector3.ZERO and control_aire > 0.0:
			# En el aire: las teclas desvían el salto, pero sin pasar de la velocidad con la que
			# despegaste (no se puede acelerar ni correr en el aire). Sin teclas, sigue de largo.
			var limite: float = minf(maxf(_velocidad_suelo, velocidad_aire_minima), SPRINT_SPEED)
			var horizontal := Vector2(velocity.x, velocity.z)
			horizontal = horizontal.move_toward(Vector2(direction.x, direction.z) * limite, control_aire * delta)
			velocity.x = horizontal.x
			velocity.z = horizontal.y
	elif direction != Vector3.ZERO:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
 
	move_and_slide()
 
	if tercera_persona:
		_calcular_distancia_libre()
 
 
## Coloca al jugador en un punto del mundo mirando hacia un ángulo (0 = hacia -Z, como al empezar).
## En tercera persona la cámara queda detrás de golpe, sin viaje ni suavizado.
func teletransportar(posicion: Vector3, giro: float) -> void:
	global_position = posicion
	velocity = Vector3.ZERO
	rotation.y = giro
	# Evita que la interpolación dibuje al jugador "viajando" desde el punto anterior.
	reset_physics_interpolation()
	if tercera_persona:
		_yaw = giro
		_pivote = global_position + Vector3(0.0, _altura_pivote, 0.0)
		_actualizar_camara(0.0, true)
 
 
# --- Agacharse (colisión) ----------------------------------------------------------------------
 
# Altura que tiene la cápsula de colisión cuando el jugador está agachado.
func _alto_agachado() -> float:
	if _forma == null:
		return _alto_pie * 0.75
	return clampf(maxf(altura_agachado, _forma.radius * 2.0), 0.1, _alto_pie)
 
 
# Cuánto baja la cabeza al agacharse, en metros.
func _bajada_al_agacharse() -> float:
	if _forma == null:
		return 0.5
	return _alto_pie - _alto_agachado()
 
 
func _preparar_colision() -> void:
	_colision = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if _colision == null or not (_colision.shape is CapsuleShape3D):
		push_warning("Jugador: no se encontró una CollisionShape3D con forma de cápsula; agacharse no cambiará la colisión.")
		return
	# Se duplica la forma para no modificar el recurso compartido de la escena.
	_forma = (_colision.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
	_colision.shape = _forma
	_alto_pie = _forma.height
	_colision_y_base = _colision.position.y
 
 
# Cambia la altura de la cápsula manteniendo los pies en el mismo lugar.
func _aplicar_altura_colision(agachado: bool) -> void:
	if _forma == null:
		return
	var objetivo: float = _alto_agachado() if agachado else _alto_pie
	if is_equal_approx(_forma.height, objetivo):
		return
	_forma.height = objetivo
	_colision.position.y = _colision_y_base - (_alto_pie - objetivo) * 0.5
 
 
# Prueba si cabe de pie: mueve la cápsula agachada hacia arriba lo que le falta y mira si choca.
func _puede_levantarse() -> bool:
	if _forma == null or not _agachado_real:
		return true
	return not test_move(global_transform, Vector3(0.0, _alto_pie - _forma.height, 0.0))
 
 
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
	# Como la coloca este script en cada cuadro, no debe interpolarla la física (si no, se pelean).
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
 
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
	# Se sigue la posición INTERPOLADA del jugador (la que se ve en pantalla), no la de la física,
	# que avanza a saltos y hacía temblar la cámara.
	var base: Vector3 = get_global_transform_interpolated().origin
	var objetivo: Vector3 = base + Vector3(0.0, _altura_pivote, 0.0)
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
 
# Achata la cápsula visible para que coincida con la colisión, sin despegarla del suelo.
func _agachar_malla() -> void:
	if _malla == null:
		return
	var proporcion: float = _alto_agachado() / _alto_pie
	var factor: float = 1.0 - (1.0 - proporcion) * _agachado_t
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
