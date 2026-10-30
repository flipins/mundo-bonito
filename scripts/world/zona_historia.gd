extends Area3D
## Zona de historia (escena 3, la caminata): un lugar del camino que muestra un texto
## la primera vez que el jugador lo pisa.
##
## Cómo se usa:
##  - Se coloca (como hijo de "CaminataDesierto") en el punto del camino donde quieres el hallazgo.
##  - Se escribe el texto en el Inspector y se ajusta el tamaño de la caja de colisión.
##  - No hace nada hasta que el gestor de la caminata la "arma" (al terminar el tutorial),
##    así que el jugador no activa textos antes de tiempo.

## Se emite la primera (y única) vez que el jugador pisa la zona ya armada.
signal activada(zona: Area3D)

## Lo que se muestra en pantalla al pisar la zona. Déjalo vacío para una zona muda.
@export_multiline var texto: String = "Escribe aquí lo que descubre el jugador."
## Marca la última zona del camino (junto a la espada): al pisarla, el gestor emite "llego_a_la_espada".
@export var es_final: bool = false

var _armada: bool = false
var _usada: bool = false


func _ready() -> void:
	# Hasta que la armen no detecta a nadie.
	monitoring = false
	body_entered.connect(_al_entrar)


## La deja lista para detectar al jugador (la llama el gestor de la caminata).
func armar() -> void:
	if _armada or _usada:
		return
	_armada = true
	set_deferred("monitoring", true)


func desarmar() -> void:
	_armada = false
	set_deferred("monitoring", false)


func fue_usada() -> bool:
	return _usada


func _al_entrar(cuerpo: Node3D) -> void:
	if not _armada or _usada:
		return
	# Solo el jugador (el único CharacterBody3D del mundo) activa la zona.
	if not cuerpo is CharacterBody3D:
		return
	_usada = true
	set_deferred("monitoring", false)
	activada.emit(self)
