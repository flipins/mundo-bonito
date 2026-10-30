extends Node
## Volúmenes de Ambiente y Efectos (se registra como Autoload con el nombre "AjustesAudio").
## El volumen general sigue en el autoload "Ajustes" (bus Master); este solo maneja los otros dos.
## Los buses se crean por código si no existen, así no hace falta tocar el panel Audio.

const RUTA_ARCHIVO := "user://ajustes_audio.cfg"
const BUS_AMBIENTE := "Ambiente"
const BUS_EFECTOS := "Efectos"

## Volumen de cada bus, de 0.0 (silencio) a 1.0 (máximo).
var volumenes := {"Ambiente": 1.0, "Efectos": 1.0}


func _ready() -> void:
	for bus: String in volumenes:
		_asegurar_bus(bus)
	cargar()
	for bus: String in volumenes:
		aplicar(bus)


func get_volumen(bus: String) -> float:
	return float(volumenes.get(bus, 1.0))


func set_volumen(bus: String, valor: float) -> void:
	volumenes[bus] = valor
	aplicar(bus)


func aplicar(bus: String) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i == -1:
		return
	var v := get_volumen(bus)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(i, v <= 0.001)


func guardar() -> void:
	var cfg := ConfigFile.new()
	for bus: String in volumenes:
		cfg.set_value("audio", bus, get_volumen(bus))
	cfg.save(RUTA_ARCHIVO)


func cargar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RUTA_ARCHIVO) != OK:
		return # Primera vez que se abre el juego: se quedan los valores por defecto.
	for bus: String in volumenes:
		volumenes[bus] = float(cfg.get_value("audio", bus, 1.0))


# Si se cierra la ventana con la X, también se guardan los volúmenes.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		guardar()


func _asegurar_bus(nombre: String) -> void:
	if AudioServer.get_bus_index(nombre) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, nombre)
	AudioServer.set_bus_send(i, "Master")
