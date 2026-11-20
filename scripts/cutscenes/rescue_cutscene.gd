
extends Node3D

# Mundo Bonito: cinemática de rescate.

@export_file("*.tscn") var city_scene: String = (
    "res://scenes/city/coastal_city.tscn"
)

@export var horse_duration: float = 12.0
@export var crane_duration: float = 8.0

@onready var camino: Path3D = $HorsePath
@onready var caballo_a: PathFollow3D = $HorsePath/HorseFollowA
@onready var caballo_b: PathFollow3D = $HorsePath/HorseFollowB

@onready var camera_rig: Node3D = $CameraRig
@onready var camara: Camera3D = $CameraRig/CinematicCamera
@onready var animador: AnimationPlayer = $AnimationPlayer
@onready var preview_anchor: Node3D = $CityPreviewAnchor

var _crane_activo: bool = false
var _ciudad_preview: Node3D


func _ready() -> void:
	SceneTransition.force_black()

	_preparar_camino()
	_preparar_animaciones()

	caballo_a.loop = false
	caballo_b.loop = false

	caballo_a.rotation_mode = PathFollow3D.ROTATION_Y
	caballo_b.rotation_mode = PathFollow3D.ROTATION_Y

	caballo_a.progress_ratio = 0.06
	caballo_b.progress_ratio = 0.0

	camara.make_current()

	_reproducir_secuencia.call_deferred()


func _preparar_camino() -> void:
	if camino.curve == null:
		camino.curve = Curve3D.new()

	if camino.curve.get_point_count() >= 2:
		return

	camino.curve.clear_points()

	camino.curve.add_point(Vector3(-600, 0, 40))
	camino.curve.add_point(Vector3(-460, 0, 24))
	camino.curve.add_point(Vector3(-320, 0, 15))
	camino.curve.add_point(Vector3(-220, 0, 0))


func _preparar_animaciones() -> void:
	# AnimationPlayer está como hijo de la raíz.
	animador.root_node = NodePath("..")
	if not animador.has_animation_library(""):
		animador.add_animation_library("", AnimationLibrary.new())
	var biblioteca := animador.get_animation_library("")
  
	if biblioteca == null:
		biblioteca = AnimationLibrary.new()
		animador.add_animation_library("", biblioteca)

	# Tramo A: plano lateral que acompaña a los caballos.
	var lateral := Animation.new()
	lateral.length = horse_duration

	var track_a := lateral.add_track(Animation.TYPE_VALUE)

	lateral.track_set_path(
		track_a,
		NodePath("CameraRig/CinematicCamera:position")
	)

	lateral.track_insert_key(
		track_a, 0.0, Vector3(0, 3.7, 24)
	)

	lateral.track_insert_key(
		track_a, horse_duration, Vector3(0, 4.5, 24)
	)

	if biblioteca.has_animation("horse_side"):
		biblioteca.remove_animation("horse_side")

	biblioteca.add_animation("horse_side", lateral)

	# Tramo B: ascenso de grúa para revelar la ciudad.
	var crane := Animation.new()
	crane.length = crane_duration

	var track_b := crane.add_track(Animation.TYPE_VALUE)

	crane.track_set_path(
		track_b,
		NodePath("CameraRig/CinematicCamera:position")
	)

	crane.track_insert_key(
		track_b, 0.0, Vector3(0, 6, 24)
	)

	crane.track_insert_key(
		track_b,
		crane_duration * 0.5,
		Vector3(80, 170, 230)
	)

	crane.track_insert_key(
		track_b,
		crane_duration,
		Vector3(220, 420, 520)
	)

	if biblioteca.has_animation("crane"):
		biblioteca.remove_animation("crane")

	biblioteca.add_animation("crane", crane)


func _process(_delta: float) -> void:
	var punto_medio := (
		caballo_a.global_position + caballo_b.global_position
	) * 0.5

	# El rig acompaña el movimiento de los caballos.
	camera_rig.global_position = punto_medio

	if _crane_activo:
		# La mirada queda dirigida hacia la ciudad y la costa.
		camara.look_at(
			Vector3(120, 5, -20),
			Vector3.UP
		)
	else:
		# Plano lateral del grupo viajando.
		camara.look_at(
			punto_medio + Vector3(0, 1.8, 0),
			Vector3.UP
		)


func _actualizar_progreso(valor: float) -> void:
	# Primer caballo ligeramente por delante.
	caballo_a.progress_ratio = lerpf(0.06, 1.0, valor)
	caballo_b.progress_ratio = lerpf(0.0, 0.94, valor)


func _mostrar_ciudad() -> void:
	if _ciudad_preview != null:
		return

	var escena := load(city_scene) as PackedScene

	if escena == null:
		push_error("Cinemática: no se encontró la ciudad.")
		return

	_ciudad_preview = escena.instantiate() as Node3D

	if _ciudad_preview == null:
		return

	# Importante: activar antes de insertar en el árbol.
	_ciudad_preview.set("preview_only", true)
	preview_anchor.add_child(_ciudad_preview)


func _reproducir_secuencia() -> void:
	# ---------------- TRAMO A ----------------
	await get_tree().process_frame

	animador.play("horse_side")
	await SceneTransition.fade_from_black(1.4)

	var viaje := create_tween()

	viaje.set_trans(Tween.TRANS_LINEAR)
	viaje.tween_method(
		_actualizar_progreso,
		0.0,
		1.0,
		horse_duration
	)

	await viaje.finished

	# Corte oscuro para preparar la vista aérea.
	await SceneTransition.fade_to_black(0.6)

	# ---------------- TRAMO B ----------------
	_mostrar_ciudad()

	if _ciudad_preview == null:
		push_error("No se puede continuar sin la ciudad.")
		return

	_crane_activo = true

	animador.play("crane")
	await SceneTransition.fade_from_black(0.9)

	await animador.animation_finished

	await get_tree().create_timer(0.8).timeout

	# ---------------- DESPERTAR ----------------
	await SceneTransition.fade_to_black(1.5)

	SceneTransition.pending_wakeup = true

	var error := get_tree().change_scene_to_file(city_scene)

	if error != OK:
		push_error(
			"Cinemática: error al cargar la ciudad: " + str(error)
		)
