extends AnimationPlayer
## Se adjunta al AnimationPlayer que mueve el ciclo de día y noche.
## Le avisa al Autoload "Reloj" de dónde leer la hora.

## Qué hora del día es cuando la animación está en su segundo 0.
## Referencia: 0.0 = medianoche, 6.0 = amanecer, 12.0 = mediodía, 18.0 = tarde.
## Si el reloj no coincide con lo que se ve, cambia este número.
@export_range(0.0, 24.0, 0.25) var hora_en_inicio: float = 6.0


func _ready() -> void:
	Reloj.registrar(self, hora_en_inicio)


func _exit_tree() -> void:
	Reloj.desregistrar(self)
