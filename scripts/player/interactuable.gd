class_name Interactuable
extends StaticBody3D
signal interactuado(quien: Node)
## Texto del aviso que aparece al mirar el objeto, por ejemplo "Leer nota" o "Abrir puerta".
@export var texto_prompt: String = "Examinar"
## Mensaje que se muestra en pantalla al interactuar (déjalo vacío si no hace falta).
@export_multiline var mensaje: String = ""
func interactuar(quien: Node) -> void:
	interactuado.emit(quien)
