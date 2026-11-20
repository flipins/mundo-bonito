
extends CanvasLayer

# Mundo Bonito: transiciones entre escenas.
# Se registra como Autoload: SceneTransition.

var pending_wakeup: bool = false

var _fade_rect: ColorRect
var _tween: Tween


func _ready() -> void:
	layer = 500
	process_mode = Node.PROCESS_MODE_ALWAYS

	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.color = Color.BLACK
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(_fade_rect)
	_fade_rect.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	_fade_rect.modulate.a = 0.0


func force_black() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()

	_fade_rect.modulate.a = 1.0


func force_clear() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()

	_fade_rect.modulate.a = 0.0


func fade_to_black(duration: float = 1.0) -> void:
	await _fade(1.0, duration)


func fade_from_black(duration: float = 1.0) -> void:
	await _fade(0.0, duration)


func _fade(target_alpha: float, duration: float) -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()

	if duration <= 0.0:
		_fade_rect.modulate.a = target_alpha
		return

	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	_tween.tween_property(
		_fade_rect,
		"modulate:a",
		target_alpha,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)

	await _tween.finished
