extends RayCast3D
## Detecta objetos interactuables frente a la cámara y gestiona la tecla de interacción.
## Se agrega como hijo de la Camera3D del jugador.
## Un objeto es interactuable si tiene un método "interactuar" (ver interactuable.gd).
## Si el objeto define "anim_recoger", se reproduce esa animación en el maniquí y la
## interacción ocurre en el momento del agarre.

## Hasta qué distancia (en metros) se puede interactuar.
@export var distancia: float = 3.0

## Nombre de la acción de entrada. Si no existe, se crea con la tecla E.
@export var accion: StringName = &"interactuar"

## Tecla que se muestra en el aviso en pantalla.
@export var texto_tecla: String = "E"

## Segundos que se queda visible un mensaje (se puede cerrar antes con la misma tecla).
@export var segundos_mensaje: float = 8.0

## Nombre del nodo del maniquí (el que tiene animar_maniqui.gd), hijo del jugador.
@export var nombre_maniqui: StringName = &"UAL1_Standard"

var _objetivo: Object = null
var _jugador: Node = null
var _maniqui: Node = null
var _ocupado: bool = false
var _tiempo_mensaje: float = 0.0

var _label_aviso: Label
var _label_mensaje: Label


func _ready() -> void:
	target_position = Vector3(0.0, 0.0, -distancia)
	_asegurar_accion()
	_excluir_jugador()
	_buscar_maniqui()
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
	elif _ocupado:
		# Ya hay una animación de interacción en curso.
		get_viewport().set_input_as_handled()
	elif is_instance_valid(_objetivo):
		var objetivo: Object = _objetivo
		# Se leen estos datos antes de interactuar, por si el objeto se elimina al usarlo.
		var texto: Variant = objetivo.get("mensaje")
		var anim: Variant = objetivo.get("anim_recoger")

		if anim != null and str(anim) != "" and _maniqui != null:
			_interactuar_con_animacion(objetivo, texto, StringName(str(anim)))
		else:
			_ejecutar_interaccion(objetivo, texto)
		get_viewport().set_input_as_handled()


func _interactuar_con_animacion(objetivo: Object, texto: Variant, anim: StringName) -> void:
	if not _maniqui.reproducir_interaccion(anim):
		return # En el aire, ya interactuando o animación inexistente: no se hace nada.
	_ocupado = true
	_actualizar_aviso()
	_maniqui.momento_de_agarre.connect(_ejecutar_interaccion.bind(objetivo, texto), CONNECT_ONE_SHOT)
	_maniqui.interaccion_terminada.connect(_al_terminar_interaccion, CONNECT_ONE_SHOT)


func _ejecutar_interaccion(objetivo: Variant, texto: Variant) -> void:
	if not is_instance_valid(objetivo):
		return
	objetivo.interactuar(_jugador)
	if texto != null and str(texto) != "":
		_mostrar_mensaje(str(texto))


func _al_terminar_interaccion() -> void:
	_ocupado = false
	_actualizar_aviso()


func _buscar_maniqui() -> void:
	if _jugador == null:
		return
	_maniqui = _jugador.find_child(nombre_maniqui, true, false)
	if _maniqui == null or not _maniqui.has_method("reproducir_interaccion"):
		_maniqui = null
		push_warning("interactor.gd: no se encontró el maniquí '%s'. Las interacciones serán sin animación." % nombre_maniqui)


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
	if is_instance_valid(_objetivo) and _tiempo_mensaje <= 0.0 and not _ocupado:
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
