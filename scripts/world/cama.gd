extends Interactuable
## Cama: al usarla la pantalla se funde a negro, el tiempo salta a una hora fija
## y la luz vuelve. Sirve para que el jugador controle el ciclo de día y noche.

## Hora a la que despierta el jugador (6.0 = amanecer, 19.0 = anochecer).
## Cuántas horas del juego avanza el tiempo al dormir.
@export_range(1.0, 24.0, 0.5) var horas_de_sueno: float = 6.0

var _durmiendo: bool = false
var _quien: Node = null


func interactuar(quien: Node) -> void:
	super.interactuar(quien)
	if _durmiendo:
		return
	_durmiendo = true
	_quien = quien
	_bloquear_jugador(true)

	var capa := CanvasLayer.new()
	capa.layer = 80
	add_child(capa)
	var negro := ColorRect.new()
	negro.color = Color.BLACK
	negro.modulate.a = 0.0
	negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(negro)
	negro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var tween := create_tween()
	tween.tween_property(negro, "modulate:a", 1.0, 0.8)
	tween.tween_callback(_avanzar_tiempo)
	tween.tween_interval(0.6)
	tween.tween_property(negro, "modulate:a", 0.0, 0.8)
	tween.tween_callback(_despertar.bind(capa))


func _despertar(capa: CanvasLayer) -> void:
	capa.queue_free()
	_bloquear_jugador(false)
	_durmiendo = false
func _avanzar_tiempo() -> void:
	# Se suma a la hora que sea justo cuando la pantalla está en negro.
	Reloj.saltar_a_hora(Reloj.hora + horas_de_sueno)

func _bloquear_jugador(bloquear: bool) -> void:
	# Mientras la pantalla está en negro, el jugador no se mueve ni gira la cámara.
	if is_instance_valid(_quien):
		_quien.set_physics_process(not bloquear)
		_quien.set_process_unhandled_input(not bloquear)
