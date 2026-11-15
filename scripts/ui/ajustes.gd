extends Node
## Ajustes globales del juego (se registra como Autoload con el nombre "Ajustes").
## Guarda y carga el volumen y la sensibilidad del mouse en un archivo del usuario.
## También crea el nodo de rendimiento (FPS y opciones gráficas), disponible como Ajustes.rendimiento.

const RUTA_ARCHIVO := "user://ajustes.cfg"
const RendimientoScript := preload("res://scripts/ui/rendimiento.gd")

## Volumen general, de 0.0 (silencio) a 1.0 (máximo).
var volumen: float = 1.0

## Multiplicador de sensibilidad del mouse. 1.0 = la sensibilidad normal del jugador.
var sensibilidad: float = 1.0

## Opciones de rendimiento y contador de FPS (ver rendimiento.gd). Se crea en _ready().
var rendimiento: Variant = null


func _ready() -> void:
	cargar()
	aplicar_volumen()
	rendimiento = RendimientoScript.new()
	rendimiento.name = "Rendimiento"
	add_child(rendimiento)


func aplicar_volumen() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volumen, 0.0001)))
	AudioServer.set_bus_mute(bus, volumen <= 0.001)


func guardar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volumen", volumen)
	cfg.set_value("controles", "sensibilidad", sensibilidad)
	cfg.save(RUTA_ARCHIVO)


func cargar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RUTA_ARCHIVO) != OK:
		return # Primera vez que se abre el juego: se quedan los valores por defecto.
	volumen = cfg.get_value("audio", "volumen", 1.0)
	sensibilidad = cfg.get_value("controles", "sensibilidad", 1.0)
