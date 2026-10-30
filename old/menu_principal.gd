extends Control
@export_file("*.tscn") var escena_juego: String = "res://desierto.tscn"

@export_file("*.tscn") var escena_pruebas: String = "res://node_3d.tscn"
@onready var panel_principal: Control = %Principal
@onready var panel_opciones: Control = %Opciones
@onready var boton_jugar: Button = %BotonJugar
@onready var boton_opciones: Button = %BotonOpciones
@onready var boton_salir: Button = %BotonSalir
@onready var boton_volver: Button = %BotonVolver
@onready var slider_volumen: HSlider = %SliderVolumen
@onready var slider_sensibilidad: HSlider = %SliderSensibilidad

var boton_pruebas: Button


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


	boton_jugar.text = "Nueva partida"
	boton_pruebas = Button.new()
	boton_pruebas.text = "Zona de pruebas"
	boton_pruebas.custom_minimum_size = boton_jugar.custom_minimum_size
	var contenedor: Node = boton_jugar.get_parent()
	contenedor.add_child(boton_pruebas)
	contenedor.move_child(boton_pruebas, boton_jugar.get_index() + 1)

	slider_volumen.min_value = 0.0
	slider_volumen.max_value = 1.0
	slider_volumen.step = 0.05
	slider_volumen.value = Ajustes.volumen

	slider_sensibilidad.min_value = 0.2
	slider_sensibilidad.max_value = 3.0
	slider_sensibilidad.step = 0.1
	slider_sensibilidad.value = Ajustes.sensibilidad

	boton_jugar.pressed.connect(_on_jugar)
	boton_pruebas.pressed.connect(_on_pruebas)
	boton_opciones.pressed.connect(_mostrar_opciones)
	boton_salir.pressed.connect(_on_salir)
	boton_volver.pressed.connect(_on_volver)
	slider_volumen.value_changed.connect(_on_volumen_cambiado)
	slider_sensibilidad.value_changed.connect(_on_sensibilidad_cambiada)

	_mostrar_principal()


func _unhandled_input(event: InputEvent) -> void:
	if panel_opciones.visible and event.is_action_pressed("ui_cancel"):
		_on_volver()
		get_viewport().set_input_as_handled()


func _mostrar_principal() -> void:
	panel_opciones.hide()
	panel_principal.show()
	boton_jugar.grab_focus()


func _mostrar_opciones() -> void:
	panel_principal.hide()
	panel_opciones.show()
	slider_volumen.grab_focus()


func _on_jugar() -> void:
	Inventario.vaciar()
	_cargar_escena(escena_juego)

func _on_pruebas() -> void:
	_cargar_escena(escena_pruebas)


func _cargar_escena(ruta: String) -> void:
	if ruta.is_empty() or not ResourceLoader.exists(ruta):
		push_error("MenuPrincipal: no existe la escena '%s'. ¿Ya la creaste?" % ruta)
		return
	get_tree().change_scene_to_file(ruta)


func _on_salir() -> void:
	get_tree().quit()


func _on_volver() -> void:
	Ajustes.guardar()
	_mostrar_principal()


func _on_volumen_cambiado(valor: float) -> void:
	Ajustes.volumen = valor
	Ajustes.aplicar_volumen()


func _on_sensibilidad_cambiada(valor: float) -> void:
	Ajustes.sensibilidad = valor
