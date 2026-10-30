extends CanvasLayer
## Pantalla de inventario: se abre y se cierra con la tecla I (o Esc para cerrar).
## Muestra lo que haya en el Autoload "Inventario" (ver inventario.gd).
## Se instancia como hijo de la escena del mundo, igual que el menú de pausa.
## Mientras está abierta el juego queda en pausa y el mouse se muestra.

const Tema = preload("res://tema_pergamino.gd")

## Nombre de la acción de entrada. Si no existe, se crea con la tecla I.
@export var accion: StringName = &"inventario"

var _lista: VBoxContainer


func _ready() -> void:
	# Debe seguir funcionando con el juego en pausa, si no no podría cerrarse.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	_asegurar_accion()
	_crear_interfaz()
	hide()


# Se usa _input (y no _unhandled_input) para recibir Esc ANTES que el menú de pausa:
# así, con el inventario abierto, Esc solo cierra el inventario.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(accion):
		if visible:
			cerrar()
		elif not get_tree().paused:
			abrir()
		else:
			return # Hay otro menú abierto (por ejemplo la pausa): no se hace nada.
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		cerrar()
		get_viewport().set_input_as_handled()


func abrir() -> void:
	_reconstruir_lista()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()


func cerrar() -> void:
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _asegurar_accion() -> void:
	if InputMap.has_action(accion):
		return
	InputMap.add_action(accion)
	var tecla := InputEventKey.new()
	tecla.physical_keycode = KEY_I
	InputMap.action_add_event(accion, tecla)


func _crear_interfaz() -> void:
	# Control de pantalla completa que lleva el tema (un CanvasLayer no puede llevarlo).
	var raiz := Control.new()
	raiz.theme = Tema.crear()
	add_child(raiz)
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Velo oscuro sobre el juego.
	var velo := ColorRect.new()
	velo.color = Color(Tema.NOCHE.r, Tema.NOCHE.g, Tema.NOCHE.b, 0.7)
	raiz.add_child(velo)
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var centro := CenterContainer.new()
	raiz.add_child(centro)
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	centro.add_child(panel)

	var caja := VBoxContainer.new()
	caja.custom_minimum_size = Vector2(620, 0)
	caja.add_theme_constant_override("separation", 14)
	panel.add_child(caja)

	var titulo := Label.new()
	titulo.text = "Inventario"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 44)
	caja.add_child(titulo)

	caja.add_child(HSeparator.new())

	# La lista va dentro de un ScrollContainer por si algún día hay muchos objetos.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	caja.add_child(scroll)

	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 6)
	scroll.add_child(_lista)

	var boton_cerrar := Button.new()
	boton_cerrar.text = "Cerrar  [I]"
	boton_cerrar.custom_minimum_size = Vector2(200, 44)
	boton_cerrar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	boton_cerrar.pressed.connect(cerrar)
	caja.add_child(boton_cerrar)


# Vuelve a dibujar la lista con lo que haya en el Inventario en este momento.
func _reconstruir_lista() -> void:
	for hijo in _lista.get_children():
		hijo.queue_free()

	var objetos: Dictionary = Inventario.todos()
	if objetos.is_empty():
		var vacio := Label.new()
		vacio.text = "No llevas nada contigo."
		vacio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vacio.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		vacio.custom_minimum_size = Vector2(0, 120)
		vacio.add_theme_color_override("font_color", Tema.TINTA_SUAVE)
		_lista.add_child(vacio)
		return

	# Orden alfabético por nombre, para que la lista no cambie de lugar sola.
	var filas: Array = objetos.values()
	filas.sort_custom(func(a, b): return str(a["nombre"]) < str(b["nombre"]))

	for i in range(filas.size()):
		if i > 0:
			_lista.add_child(HSeparator.new())
		_lista.add_child(_crear_fila(str(filas[i]["nombre"]), int(filas[i]["cantidad"])))


func _crear_fila(nombre: String, cantidad: int) -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 20)

	var etiqueta_nombre := Label.new()
	etiqueta_nombre.text = nombre
	etiqueta_nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	etiqueta_nombre.add_theme_font_size_override("font_size", 26)
	fila.add_child(etiqueta_nombre)

	var etiqueta_cantidad := Label.new()
	etiqueta_cantidad.text = "×%d" % cantidad
	etiqueta_cantidad.add_theme_font_size_override("font_size", 26)
	etiqueta_cantidad.add_theme_color_override("font_color", Tema.TINTA_SUAVE)
	fila.add_child(etiqueta_cantidad)

	return fila
