tool
extends Panel

signal json_requested

onready var _btn_generate_json: Button = find_node('BtnGenerateJSON')
onready var _generation_result: Label = find_node('GenerationResult')


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos de Godot ░░░░
func _ready() -> void:
	_btn_generate_json.connect('pressed', self, '_generate_json')


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos públicos ░░░░
func update_result(time: Dictionary, report: Dictionary) -> void:
	_generation_result.text = 'Se creó el archivo JSON en %s/%s/%d > %s:%s:%s'\
	% [
		str(time.day).pad_zeros(2),
		str(time.month).pad_zeros(2),
		time.year,
		# >
		str(time.hour).pad_zeros(2),
		str(time.minute).pad_zeros(2),
		str(time.second).pad_zeros(2)
	]
	
	_generation_result.text += '\n\n'
	
	for d in report:
		_generation_result.text += '%s [images (%d), audios (%d)]' % [
			d, report[d].images, report[d].audios
		]
		_generation_result.text += '\n'


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos privados ░░░░
func _generate_json() -> void:
	emit_signal('json_requested')
