extends RayCast3D
## Detecta objetos interactuables frente a la cámara y gestiona la tecla de interacción.
## Se agrega como hijo de la Camera3D del jugador.
## Un objeto es interactuable si tiene un método "interactuar" (ver interactuable.gd).

## Hasta qué distancia (en metros) se puede interactuar.
@export var distancia: float = 3.0

## Nombre de la acción de entrada. Si no existe, se crea con la tecla E.
@export var accion: StringName = &"interactuar"

## Tecla que se muestra en el aviso en pantalla.
@export var texto_tecla: String = "E"

## Segundos que se queda visible un mensaje (se puede cerrar antes con la misma tecla).
@export var segundos_mensaje: float = 8.0

var _objetivo: Object = null
var _jugador: Node = null
var _tiempo_mensaje: float = 0.0

var _label_aviso: Label
var _label_mensaje: Label


func _ready() -> void:
	target_position = Vector3(0.0, 0.0, -distancia)
	_asegurar_accion()
	_excluir_jugador()
	_crear_interfaz()


func _process(delta: float) -> void:
	if _objetivo != null and not is_instance_valid(_objetivo):
		_objetivo = null

	var nuevo: Object = null
	if is_colliding():
		var colision: Object = get_collider()
		if colision != null and colision.has_method("interactuar"):
			nuevo = colision
	if nuevo != _objetivo:
		_objetivo = nuevo
		_actualizar_aviso()

	if _tiempo_mensaje > 0.0:
		_tiempo_mensaje -= delta
		if _tiempo_mensaje <= 0.0:
			_ocultar_mensaje()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(accion):
		return
	if _tiempo_mensaje > 0.0:
		# Si hay un mensaje abierto, la misma tecla lo cierra.
		_ocultar_mensaje()
		get_viewport().set_input_as_handled()
	elif is_instance_valid(_objetivo):
		var objetivo: Object = _objetivo
		# Se lee el mensaje antes de interactuar, por si el objeto se elimina al usarlo.
		var texto: Variant = objetivo.get("mensaje")
		objetivo.interactuar(_jugador)
		if texto != null and str(texto) != "":
			_mostrar_mensaje(str(texto))
		get_viewport().set_input_as_handled()


func _asegurar_accion() -> void:
	if InputMap.has_action(accion):
		return
	InputMap.add_action(accion)
	var tecla := InputEventKey.new()
	tecla.physical_keycode = KEY_E
	InputMap.action_add_event(accion, tecla)


func _excluir_jugador() -> void:
	# El rayo nace dentro del jugador: se busca su cuerpo y se ignora,
	# si no el rayo chocaría siempre con él mismo.
	var nodo: Node = get_parent()
	while nodo != null:
		if nodo is CollisionObject3D:
			_jugador = nodo
			add_exception(nodo)
			return
		nodo = nodo.get_parent()


func _mostrar_mensaje(texto: String) -> void:
	_label_mensaje.text = texto
	_label_mensaje.show()
	_tiempo_mensaje = segundos_mensaje
	_actualizar_aviso()


func _ocultar_mensaje() -> void:
	_label_mensaje.hide()
	_tiempo_mensaje = 0.0
	_actualizar_aviso()


func _actualizar_aviso() -> void:
	if is_instance_valid(_objetivo) and _tiempo_mensaje <= 0.0:
		var prompt: Variant = _objetivo.get("texto_prompt")
		var texto: String = str(prompt) if prompt != null else "Interactuar"
		_label_aviso.text = "[%s] %s" % [texto_tecla, texto]
		_label_aviso.show()
	else:
		_label_aviso.hide()


func _crear_interfaz() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 10
	add_child(capa)

	var margen := MarginContainer.new()
	capa.add_child(margen)
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margen.add_theme_constant_override("margin_left", 160)
	margen.add_theme_constant_override("margin_right", 160)
	margen.add_theme_constant_override("margin_bottom", 90)

	var caja := VBoxContainer.new()
	caja.alignment = BoxContainer.ALIGNMENT_END
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_theme_constant_override("separation", 16)
	margen.add_child(caja)

	_label_mensaje = _crear_label(26)
	_label_mensaje.hide()
	caja.add_child(_label_mensaje)

	_label_aviso = _crear_label(22)
	_label_aviso.hide()
	caja.add_child(_label_aviso)


func _crear_label(tamano: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", tamano)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label
