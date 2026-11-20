
extends Area3D

# Mundo Bonito — conexión entre tutorial y rescate.

const CUTSCENE_PATH := (
    "res://scenes/cutscenes/desert_rescue_cutscene.tscn"
)

@export var jugador_path: NodePath = NodePath("../jugador")

@export var requiere_espada: bool = true
@export var requiere_arena_despejada: bool = true

var _jugador: CharacterBody3D
var _jugador_dentro: bool = false
var _activado: bool = false


func _ready() -> void:
	_jugador = get_node_or_null(
		jugador_path
	) as CharacterBody3D

	if _jugador == null:
		push_error("Trigger: no se encontró el jugador.")
		return

	monitoring = true

	body_entered.connect(_al_entrar)
	body_exited.connect(_al_salir)


func _al_entrar(body: Node3D) -> void:
	if body == _jugador:
		_jugador_dentro = true


func _al_salir(body: Node3D) -> void:
	if body == _jugador:
		_jugador_dentro = false


func _physics_process(_delta: float) -> void:
	if _activado or not _jugador_dentro:
		return

	if requiere_espada:
		var tiene_espada := (
			Inventario.tiene(&"espada")
			or Inventario.tiene(&"rama_espada")
		)

		if not tiene_espada:
			return

	if requiere_arena_despejada:
		var enemigos := get_tree().get_nodes_in_group(
            "enemigos_arena"
		)

		if not enemigos.is_empty():
			return

	_activado = true
	_iniciar_cinematica.call_deferred()


func _iniciar_cinematica() -> void:
	# Bloquear al protagonista.
	_jugador.set_process(false)
	_jugador.set_physics_process(false)
	_jugador.set_process_input(false)
	_jugador.set_process_unhandled_input(false)

	# Ocultar su interfaz.
	var hud := _jugador.get_node_or_null(
        "CanvasLayer"
	) as CanvasLayer

	if hud != null:
		hud.visible = false

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	SceneTransition.pending_wakeup = false

	await SceneTransition.fade_to_black(1.5)

	var error := get_tree().change_scene_to_file(
		CUTSCENE_PATH
	)

	if error != OK:
		push_error(
			"Trigger: no se pudo cargar la cinemática: " +
			str(error)
		)
