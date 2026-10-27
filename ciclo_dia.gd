extends AnimationPlayer
@export_range(0.0, 24.0, 0.25) var hora_en_inicio: float = 6.0
var _reloj: Node = null
func _ready() -> void:
	_reloj = get_node_or_null("/root/Reloj")
	if _reloj == null:
		push_warning("ciclo_dia.gd: no se encontró el Autoload 'Reloj'.")
		return
	_reloj.registrar(self, hora_en_inicio)
func _exit_tree() -> void:
	if is_instance_valid(_reloj):
		_reloj.desregistrar(self)
