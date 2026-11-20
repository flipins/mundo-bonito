
extends Node3D

# Mundo Bonito: despertar en la habitación.

@export var test_direct_wakeup: bool = true

@onready var jugador: CharacterBody3D = get_node(
    "../Jugador"
) as CharacterBody3D

@onready var spawn_cama: Marker3D = get_node(
    "../RecoveryRoom/WakeUpSpawnPoint"
) as Marker3D

@onready var spawn_pie: Marker3D = get_node(
    "../RecoveryRoom/StandUpSpawnPoint"
) as Marker3D

@onready var wake_camera: Camera3D = $WakeCamera


func _ready() -> void:
	var debe_despertar := (
		SceneTransition.pending_wakeup or test_direct_wakeup
	)

	SceneTransition.pending_wakeup = false

	if debe_despertar:
		SceneTransition.force_black()
		_despertar.call_deferred()
	else:
		jugador.global_position = spawn_pie.global_position


func _despertar() -> void:
	# El jugador existe, pero no puede moverse ni girar.
	jugador.set_process(false)
	jugador.set_physics_process(false)
	jugador.set_process_input(false)
	jugador.set_process_unhandled_input(false)

	# Lo colocamos sobre la cama, invisible durante
	# el plano subjetivo de despertar.
	jugador.global_position = spawn_cama.global_position
	jugador.visible = false

	var hud := jugador.get_node_or_null(
        "CanvasLayer"
	) as CanvasLayer

	if hud != null:
		hud.visible = false

	# Cámara desde la perspectiva del protagonista acostado.
	wake_camera.make_current()
	wake_camera.global_position = (
		spawn_cama.global_position + Vector3(0.0, 0.2, 0.0)
	)

	# Mirada inclinada hacia el techo.
	wake_camera.rotation_degrees = Vector3(72.0, 0.0, 0.0)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	await get_tree().create_timer(0.6).timeout

	# Abre los ojos lentamente.
	await SceneTransition.fade_from_black(2.5)

	# El protagonista comienza a incorporarse.
	var movimiento := create_tween()
	movimiento.set_parallel(true)
	movimiento.set_trans(Tween.TRANS_SINE)
	movimiento.set_ease(Tween.EASE_IN_OUT)

	movimiento.tween_property(
		wake_camera,
		"global_position",
		spawn_cama.global_position + Vector3(0.0, 1.25, 0.0),
		2.7
	)

	movimiento.tween_property(
		wake_camera,
		"rotation_degrees",
		Vector3.ZERO,
		2.7
	)

	await movimiento.finished
	await get_tree().create_timer(0.7).timeout

	# Simulamos levantarse de la cama.
	await SceneTransition.fade_to_black(0.55)

	_activar_jugador()

	await get_tree().process_frame
	await SceneTransition.fade_from_black(0.75)


func _activar_jugador() -> void:
	jugador.visible = true

	# Reutiliza la función existente en tu jugador.gd.
	if jugador.has_method("teletransportar"):
		jugador.teletransportar(
			spawn_pie.global_position,
			0.0
		)
	else:
		jugador.global_position = spawn_pie.global_position

	# Vuelve a la cámara original del personaje.
	wake_camera.current = false

	var camara_jugador := jugador.get_node_or_null(
        "Camera3D"
	) as Camera3D

	if camara_jugador != null:
		camara_jugador.make_current()

	jugador.set_process(true)
	jugador.set_physics_process(true)
	jugador.set_process_input(true)
	jugador.set_process_unhandled_input(true)

	var hud := jugador.get_node_or_null(
        "CanvasLayer"
	) as CanvasLayer

	if hud != null:
		hud.visible = true

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
