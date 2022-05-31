tool
extends Control

signal json_requested
signal config_file_opened

var ei: EditorInterface
var efs: EditorFileSystem

onready var directory := Directory.new()
onready var _btn_generate_json: Button = find_node('BtnGenerateJSON')
onready var _btn_open_config: Button = find_node('BtnOpenConfig')
onready var _btn_copy_files: Button = find_node('BtnCopyFiles')
onready var _generation_result: Label = find_node('GenerationResult')
onready var _result_tree: Tree = find_node('ResultTree')


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos de Godot ░░░░
func _ready() -> void:
	_result_tree.hide_root = true
	
	_btn_generate_json.connect('pressed', self, '_generate_json')
	_btn_open_config.connect('pressed', self, '_open_config_file')
	_btn_copy_files.connect('pressed', self, '_copy_files')


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos públicos ░░░░
func update_result(time: Dictionary, report: Dictionary) -> void:
	_generation_result.text = 'Se creó el archivo JSON a las %s:%s:%s' %\
	[
		str(time.hour).pad_zeros(2),
		str(time.minute).pad_zeros(2),
		str(time.second).pad_zeros(2)
	]
	
	if _result_tree.get_root():
		_result_tree.get_root().free()
	
	var _tree_root := _result_tree.create_item()
	for d in report:
		var item := _result_tree.create_item(_tree_root)
		item.set_text(0, d)
		
		if not report[d].audios.empty():
			var audios := _result_tree.create_item(item)
			audios.set_text(0, 'audios (%d)' % report[d].audios.size())
			
			for a in report[d].audios:
				var audio_item := _result_tree.create_item(audios)
				audio_item.set_text(0, a)
		
		if not report[d].images.empty():
			var images := _result_tree.create_item(item)
			images.set_text(0, 'images (%d)' % report[d].images.size())
			
			for i in report[d].images:
				var image_item := _result_tree.create_item(images)
				image_item.set_text(0, i)


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos privados ░░░░
func _generate_json() -> void:
	emit_signal('json_requested')


func _open_config_file() -> void:
	ei.edit_resource(load('res://dwl/dwl_config.tres'))


func _copy_files() -> void:
	var dir: EditorFileSystemDirectory =\
	efs.get_filesystem_path('res://')
	
	# Se recorren las carpetas en busca de archivos de imagen y de audio
	_read_path(dir)


func _read_path(dir: EditorFileSystemDirectory) -> void:
	if dir.get_subdir_count():
		for d in dir.get_subdir_count():
			if dir.get_subdir(d).get_name() == 'addons':
				continue
			
			# Revisar las subcarpetas
			_read_path(dir.get_subdir(d))

		# Buscar en los archivos de la carpeta
		_read_dir(dir)
	else:
		_read_dir(dir)


func _read_dir(dir: EditorFileSystemDirectory) -> void:
	for f in dir.get_file_count():
		var path = dir.get_file_path(f)
		var file_type := efs.get_file_type(path)
		
		match file_type:
			'StreamTexture', 'AudioStreamOGGVorbis':
				var target_path: String = path.replace(
					'res://', DWLResources.WORKING_DIR
				)
				
				if not directory.dir_exists(target_path):
					directory.make_dir_recursive(target_path.get_base_dir())
					var err: int = directory.copy(path, target_path)
					
					if err != OK:
						prints('[DWL] Could not copy %s' % path)
