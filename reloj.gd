extends Node
signal amanecer
signal anochecer

## Versión sin reloj/contador debug en pantalla.
## Mantiene el sistema horario y las señales, pero ya no muestra la hora en la esquina superior izquierda.

const HORA_AMANECER: float = 6.0
const HORA_ANOCHECER: float = 19.0

var hora: float = 12.0
var es_de_dia: bool = true

var _player: AnimationPlayer = null
var _hora_en_inicio: float = 6.0
var _primera_lectura: bool = true


func _ready() -> void:
	pass


func registrar(player: AnimationPlayer, hora_en_inicio: float) -> void:
	_player = player
	_hora_en_inicio = hora_en_inicio
	_primera_lectura = true


func desregistrar(player: AnimationPlayer) -> void:
	if _player == player:
		_player = null


func es_de_noche() -> bool:
	return not es_de_dia


func hora_texto() -> String:
	var horas := int(hora)
	var minutos := int((hora - float(horas)) * 60.0)
	return "%02d:%02d" % [horas, minutos]


func saltar_a_hora(hora_objetivo: float) -> void:
	if not _hay_animacion():
		return
	var largo := _player.current_animation_length
	if largo <= 0.0:
		return
	var fraccion := fposmod(hora_objetivo - _hora_en_inicio, 24.0) / 24.0
	_player.seek(fraccion * largo, true)


func _hay_animacion() -> bool:
	return is_instance_valid(_player) and _player.current_animation != ""


func _process(_delta: float) -> void:
	if not _hay_animacion():
		return

	var largo := _player.current_animation_length
	if largo <= 0.0:
		return

	var fraccion := _player.current_animation_position / largo
	hora = fposmod(_hora_en_inicio + fraccion * 24.0, 24.0)
	var de_dia := hora >= HORA_AMANECER and hora < HORA_ANOCHECER
	if _primera_lectura:
		es_de_dia = de_dia
		_primera_lectura = false
	elif de_dia != es_de_dia:
		es_de_dia = de_dia
		if es_de_dia:
			amanecer.emit()
		else:
			anochecer.emit()
