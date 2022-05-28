tool
extends Panel

signal json_requested
signal config_file_opened

var ei: EditorInterface
var efs: EditorFileSystem

onready var directory := Directory.new()
onready var _btn_generate_json: Button = find_node('BtnGenerateJSON')
onready var _btn_open_config: Button = find_node('BtnOpenConfig')
onready var _btn_copy_files: Button = find_node('BtnCopyFiles')
onready var _generation_result: Label = find_node('GenerationResult')


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos de Godot ░░░░
func _ready() -> void:
	_btn_generate_json.connect('pressed', self, '_generate_json')
	_btn_open_config.connect('pressed', self, '_open_config_file')
	_btn_copy_files.connect('pressed', self, '_copy_files')


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
					directory.copy(path, target_path)

#		if not _editor_file_system.get_file_type(path) == 'PackedScene':
#			continue
#
#		var key: String = path
##		var key := get_key_name(path)
#		_mama = (ResourceLoader.load(path) as PackedScene).instance()
#
#		_report[key] = {images = 0, audios = 0}
#
#		# ---- Obtener las imágenes del nodo y sus hijos -----------------------
#		_assets_paths.images[key] = []
#
#		if _mama.has_method('get_prop_textures'):
#			var props: Array = _mama.get_prop_textures()
#			var textures := []
#
#			for p in props:
#				textures.append({
#					prop = p.prop,
#					path = get_texture_web_path(p.texture)
#				})
#
#			_assets_paths.images[key].append_array(textures)
#
#		_get_node_images(_mama)
#
#		if (_assets_paths.images[key] as Array).empty():
#			_assets_paths.images.erase(key)
#		else:
#			_report[key].images = _assets_paths.images[key].size()
#
#		# ---- Obtener los audios del nodo y sus hijos -------------------------
#		_assets_paths.audios[key] = []
#
#		if _mama.has_method('get_on_demand_audios'):
#			var audios: Dictionary = _mama.get_on_demand_audios()
#			_assets_paths.audios = audios
#
#		_get_node_audios(_mama)
#
#		if (_assets_paths.audios[key] as Array).empty():
#			_assets_paths.audios.erase(key)
#		else:
#			_report[key].audios = _assets_paths.audios[key].size()
#
#		if not _report[key].images and not _report[key].audios:
#			_report.erase(key)
