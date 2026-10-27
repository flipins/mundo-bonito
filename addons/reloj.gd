extends Node
## Reloj del mundo (se registra como Autoload con el nombre "Reloj").
## Lee la hora del ciclo de día y noche (la animación de tu AnimationPlayer)
## para que misiones, puertas, NPCs y enemigos puedan consultarla.
##
## Uso desde cualquier script:
##   if Reloj.es_de_dia: ...
##   Reloj.anochecer.connect(mi_funcion)
##   Reloj.saltar_a_hora(6.0)

signal amanecer
signal anochecer

## Horas a las que empieza el día y la noche. Ajústalas para que coincidan con lo que se ve.
const HORA_AMANECER: float = 6.0
const HORA_ANOCHECER: float = 19.0

## Hora actual, de 0.0 a 24.0 (por ejemplo, 18.5 = 18:30).
var hora: float = 12.0
var es_de_dia: bool = true

var _player: AnimationPlayer = null
var _hora_en_inicio: float = 6.0
var _primera_lectura: bool = true

var _mostrar_debug: bool = true
var _label_debug: Label


func _ready() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 50
	add_child(capa)
	_label_debug = Label.new()
	_label_debug.position = Vector2(16.0, 12.0)
	_label_debug.add_theme_font_size_override("font_size", 18)
	_label_debug.add_theme_constant_override("outline_size", 6)
	_label_debug.add_theme_color_override("font_outline_color", Color.BLACK)
	capa.add_child(_label_debug)


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


## Mueve el ciclo a una hora concreta (por ejemplo, al dormir).
func saltar_a_hora(hora_objetivo: float) -> void:
	if not is_instance_valid(_player):
		return
	var largo := _player.current_animation_length
	if largo <= 0.0:
		return
	var fraccion := fposmod(hora_objetivo - _hora_en_inicio, 24.0) / 24.0
	_player.seek(fraccion * largo, true)


func _unhandled_input(event: InputEvent) -> void:
	# F3 muestra u oculta el reloj en pantalla (útil mientras calibras el ciclo).
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_mostrar_debug = not _mostrar_debug


func _process(_delta: float) -> void:
	var hay_reloj := is_instance_valid(_player)
	_label_debug.visible = _mostrar_debug and hay_reloj
	if not hay_reloj:
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

	_label_debug.text = "%s  (%s)" % [hora_texto(), "día" if es_de_dia else "noche"]
