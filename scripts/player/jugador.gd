extends CharacterBody3D

# Diferentes velocidades
const WALK_SPEED = 5.0
const SPRINT_SPEED = 9.0
const CROUCH_SPEED = 2.0
const JUMP_VELOCITY = 4.5

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera = $Camera3D
@onready var altura_original_camara = camera.position.y # Guarda la altura inicial de tu cámara
var sensibilidad = 0.003

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * sensibilidad * Ajustes.sensibilidad)
		camera.rotate_x(-event.relative.y * sensibilidad * Ajustes.sensibilidad)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

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
	if Input.is_action_pressed("agacharse"):
		current_speed = CROUCH_SPEED
		# Baja la cámara de forma suave
		camera.position.y = move_toward(camera.position.y, altura_original_camara - 0.5, delta * 5.0)
	else:
		# Devuelve la cámara a su altura original suavemente
		camera.position.y = move_toward(camera.position.y, altura_original_camara, delta * 5.0)

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()
