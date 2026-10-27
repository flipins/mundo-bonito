extends CanvasLayer
## Menú de pausa: se abre y se cierra con Esc dentro del juego.
## Se instancia como hijo de la escena del mundo (node_3d.tscn).

## Escena a la que se vuelve con "Menú principal".
@export_file("*.tscn") var escena_menu: String = "res://menu_principal.tscn"

@onready var panel_principal: Control = %Principal
@onready var panel_opciones: Control = %Opciones
@onready var boton_continuar: Button = %BotonContinuar
@onready var boton_opciones: Button = %BotonOpciones
@onready var boton_menu: Button = %BotonMenu
@onready var boton_volver: Button = %BotonVolver
@onready var slider_volumen: HSlider = %SliderVolumen
@onready var slider_sensibilidad: HSlider = %SliderSensibilidad


func _ready() -> void:
	# Este nodo debe seguir funcionando mientras el juego está en pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

	slider_volumen.min_value = 0.0
	slider_volumen.max_value = 1.0
	slider_volumen.step = 0.05

	slider_sensibilidad.min_value = 0.2
	slider_sensibilidad.max_value = 3.0
	slider_sensibilidad.step = 0.1

	boton_continuar.pressed.connect(continuar)
	boton_opciones.pressed.connect(_mostrar_opciones)
	boton_menu.pressed.connect(_on_menu_principal)
	boton_volver.pressed.connect(_on_volver_opciones)
	slider_volumen.value_changed.connect(_on_volumen_cambiado)
	slider_sensibilidad.value_changed.connect(_on_sensibilidad_cambiada)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if not get_tree().paused:
		pausar()
	elif panel_opciones.visible:
		_on_volver_opciones()
	else:
		continuar()
	get_viewport().set_input_as_handled()


func pausar() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Los sliders muestran siempre el valor actual de los ajustes.
	slider_volumen.set_value_no_signal(Ajustes.volumen)
	slider_sensibilidad.set_value_no_signal(Ajustes.sensibilidad)
	_mostrar_principal()
	show()


func continuar() -> void:
	Ajustes.guardar()
	get_viewport().gui_release_focus()
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _mostrar_principal() -> void:
	panel_opciones.hide()
	panel_principal.show()
	boton_continuar.grab_focus()


func _mostrar_opciones() -> void:
	panel_principal.hide()
	panel_opciones.show()
	slider_volumen.grab_focus()


func _on_volver_opciones() -> void:
	Ajustes.guardar()
	_mostrar_principal()


func _on_menu_principal() -> void:
	Ajustes.guardar()
	# Hay que quitar la pausa antes de cambiar de escena,
	# si no el menú principal se cargaría congelado.
	get_tree().paused = false
	get_tree().change_scene_to_file(escena_menu)


func _on_volumen_cambiado(valor: float) -> void:
	Ajustes.volumen = valor
	Ajustes.aplicar_volumen()


func _on_sensibilidad_cambiada(valor: float) -> void:
	Ajustes.sensibilidad = valor
