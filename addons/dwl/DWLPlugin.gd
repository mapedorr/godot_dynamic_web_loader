tool
extends EditorPlugin
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

const MAIN_DOCK := preload('res://addons/dwl/Editor/MainDock/DWLDock.tscn')
const SetGet := preload('res://addons/dwl/Tools/DWLSetGet.gd')

var main_dock: Control

var _editor_interface := get_editor_interface()
var _editor_file_system := _editor_interface.get_resource_filesystem()
var _directory := Directory.new()
var _assets_paths := { audios = {}, images = {}, grandchilds = {} }
var _mama: Node = null
var _report := {}

onready var _customs := DWLResources.get_customs()


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos de Godot ░░░░
func _init() -> void:
	if Engine.editor_hint:
		DWLResources.init_files()
	
	add_autoload_singleton('DWL', DWLResources.DWL_SINGLETON)


func _enter_tree() -> void:
	main_dock = MAIN_DOCK.instance()
	main_dock.focus_mode = Control.FOCUS_ALL
	main_dock.ei = _editor_interface
	main_dock.efs = _editor_file_system
	
	main_dock.connect('json_requested', self, '_create_json')
	
#	add_control_to_dock(DOCK_SLOT_RIGHT_BR, main_dock)
	add_control_to_bottom_panel(main_dock, 'Dynamic Web Loader')


func _exit_tree() -> void:
	remove_control_from_bottom_panel(main_dock)
	main_dock.queue_free()


func disable_plugin() -> void:
	remove_autoload_singleton('DWL')


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos públicos ░░░░
func get_texture_web_path(t: Texture) -> String:
	return t.resource_path.trim_prefix('res://')


func get_audio_web_path(t: AudioStream) -> String:
	return t.resource_path.trim_prefix('res://')


func get_key_name(path: String) -> String:
	return path.trim_prefix(DWLResources.get_scan_path())


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos privados ░░░░
func _create_json() -> void:
	var dir: EditorFileSystemDirectory =\
	_editor_file_system.get_filesystem_path(DWLResources.get_scan_path())
	
	# Se recorren todas las carpetas para buscar archivos .TSCN y así analizar
	# su estructura en busca de texturas y archivos de sonido.
	_read_path(dir)
	
	# Escribir el resultado en un JSON que se cargará en la versión Web del juego.
	var err: int = _save_json(DWLResources.get_json_path(), _assets_paths)
	
	assert(err == OK, '[DWL] Error creating JSON %d' % err)
	
	main_dock.update_result(OS.get_datetime(), _report)


func _read_path(dir: EditorFileSystemDirectory) -> void:
	if dir.get_subdir_count():
		for d in dir.get_subdir_count():
			# Revisar las subcarpetas
			_read_path(dir.get_subdir(d))

		# Buscar en los archivos de la carpeta
		_read_dir(dir)
	else:
		_read_dir(dir)


func _read_dir(dir: EditorFileSystemDirectory) -> void:
	for f in dir.get_file_count():
		var path = dir.get_file_path(f)

		if not _editor_file_system.get_file_type(path) == 'PackedScene':
			continue
		
		var key: String = path
#		var key := get_key_name(path)
		_mama = (ResourceLoader.load(path) as PackedScene).instance()
		
		_report[key] = {images = [], audios = []}

		# ---- Obtener las imágenes del nodo y sus hijos -----------------------
		_assets_paths.images[key] = []

		if _mama.has_method('get_extra_textures'):
			var props: Array = _mama.get_extra_textures()
			var textures := []
			
			for p in props:
				textures.append({
					prop = p.prop,
					path = get_texture_web_path(p.texture)
				})
				_report[key].images.append(get_texture_web_path(p.texture))
			
			_assets_paths.images[key].append_array(textures)
		elif _mama.has_method('custom_textures_load'):
			_assets_paths.audios[key].append_array([{custom_textures_load = true}])
		
		_get_node_images(_mama)
		
		if (_assets_paths.images[key] as Array).empty():
			_assets_paths.images.erase(key)
#		else:
#			_report[key].images = _assets_paths.images[key].size()
		
		# ---- Obtener los audios del nodo y sus hijos -------------------------
		_assets_paths.audios[key] = []
		
		if _mama.has_method('get_extra_audios'):
			var props: Array = _mama.get_custom_audios()
			var audios := []
			
			for p in props:
				audios.append({
					prop = p.prop,
					path = get_texture_web_path(p.texture)
				})
				_report[key].audios.append(get_texture_web_path(p.texture))
			
			_assets_paths.audios[key].append_array(audios)
		elif _mama.has_method('custom_audios_load'):
			_assets_paths.audios[key].append_array([{custom_audios_load = true}])
		
		_get_node_audios(_mama)
		
		if (_assets_paths.audios[key] as Array).empty():
			_assets_paths.audios.erase(key)
#		else:
#			_report[key].audios = _assets_paths.audios[key].size()
		
		if _report[key].images.empty() and _report[key].audios.empty():
			_report.erase(key)
		
		# ---- Obtener los nietos del nodo -------------------------------------
		_assets_paths.grandchilds[key] = []
		
		_get_node_grandchilds(_mama)
		
		if (_assets_paths.grandchilds[key] as Array).empty():
			_assets_paths.grandchilds.erase(key)


func _get_node_images(node: Node, tree := '', ignore_first := false) -> void:
	if not ignore_first:
		_save_node_texture(node, '.')
	
	for c in node.get_children():
		if c.filename:
			continue
		
		var node_path := _get_tree_text(tree, c.name)
		_save_node_texture(c, node_path)

		# not c.filename: para ignorar los nodos que sean una instancia de
		# otra escena.
		if not c.filename and not c.get_children().empty():
			_get_node_images(c, node_path, true)


func _save_node_texture(node: Node, node_path: String) -> void:
	var data: Array = _customs.get_node_texture(node)
	
	if data.empty():
		data = SetGet.get_node_texture(node)
	
	for d in data:
		if d is Texture:
			_add_texture(node_path, d)
		elif d:
			_add_texture(node_path, d[0], d[1])


func _add_texture(node_path: String, texture: Texture, style := '') -> void:
	if not texture\
	or not is_instance_valid(texture)\
	or not texture.resource_path:
		return
	
	var new_entry := {
		node = node_path,
		mama = _mama.name,
		path = get_texture_web_path(texture),
		flags = texture.flags
	}
	
	if style:
		new_entry['style'] = style
	
	_assets_paths.images[_mama.filename].append(new_entry)
#	_assets_paths.images[get_key_name(_mama.filename)].append(new_entry)

	_report[_mama.filename].images.append(get_texture_web_path(texture))


func _get_node_audios(node: Node, tree := '') -> void:
	_save_node_audio(node, '.')
	
	for c in node.get_children():
		var node_path := _get_tree_text(tree, c.name)
		_save_node_audio(c, node_path)
	
		# not c.filename: para ignorar los nodos que sean una instancia de
		# otra escena.
		if not c.filename and not c.get_children().empty():
			_get_node_audios(c, node_path)


func _save_node_audio(node: Node, node_path: String) -> void:
	var data: Array = _customs.get_node_stream(node)
	
	if data.empty():
		data = SetGet.get_node_stream(node)
	
	for d in data:
		if d is AudioStream:
			_add_stream(node_path, d)
		else:
			_add_stream(node_path, d[0], d[1])


func _add_stream(node_path: String, stream: AudioStream, extra := '') -> void:
	if not stream: return
	
	var new_entry := {
		node = node_path,
		mama = _mama.name,
		path = get_audio_web_path(stream)
	}
	
	if extra:
		new_entry['extra'] = extra
	
	_assets_paths.audios[_mama.filename].append(new_entry)
#	_assets_paths.audios[get_key_name(_mama.filename)].append(new_entry)
	
	_report[_mama.filename].audios.append(get_audio_web_path(stream))


func _get_node_grandchilds(node: Node, tree := '') -> void:
	for c in node.get_children():
		var node_path := _get_tree_text(tree, c.name)
		
		if c.filename:
			_assets_paths.grandchilds[_mama.filename].append({
				res = c.filename,
				path = node_path
			})
		
		if not c.get_children().empty():
			_get_node_grandchilds(c, node_path)


func _get_tree_text(parent_name: String, node_name: String) -> String:
	if parent_name:
		return parent_name + '/' + node_name
	else:
		return node_name


func _save_json(path: String, data: Dictionary):
	var directory := Directory.new()
	var json_dir := path.get_base_dir()
	
	if not directory.dir_exists(json_dir):
		var err: int = directory.make_dir_recursive(json_dir)
		assert(err == OK, "[GDWL] Can't create directory")
	
	var file = File.new()
	var err = file.open(path, File.WRITE)
	if err == OK:
		file.store_line(to_json(data))
		file.close()
	
	return err
