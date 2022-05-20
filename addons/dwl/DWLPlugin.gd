tool
extends EditorPlugin
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

const MAIN_DOCK := preload('res://addons/dwl/Editor/MainDock/DWLDock.tscn')
const SRC_PATH := 'res://src/'
const JSON_PATH := 'res://src/Web/on_demand_assets.json'

var main_dock: Panel

var _editor_interface := get_editor_interface()
var _editor_file_system := _editor_interface.get_resource_filesystem()
var _directory := Directory.new()
var _assets_paths := { audios = {}, images = {} }
var _mama: Node = null
var _report := {}


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos de Godot ░░░░
func _enter_tree() -> void:
	prints('Simona la cacalisa')
	
	main_dock = MAIN_DOCK.instance()
	main_dock.focus_mode = Control.FOCUS_ALL
	
	main_dock.connect('json_requested', self, '_create_json')
	
	add_control_to_dock(DOCK_SLOT_RIGHT_BR, main_dock)


func _exit_tree() -> void:
	pass


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos públicos ░░░░
func get_texture_web_path(t: Texture) -> String:
	return t.resource_path.trim_prefix('res://assets/images/')


func get_audio_web_path(t: AudioStream) -> String:
	return t.resource_path.trim_prefix('res://assets/audios/')


func get_key_name(path: String) -> String:
	return path.trim_prefix(SRC_PATH)


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos privados ░░░░
func _create_json() -> void:
	var dir: EditorFileSystemDirectory =\
	_editor_file_system.get_filesystem_path(SRC_PATH)
	
	# Se recorren todas las carpetas para buscar archivos .TSCN y así analizar
	# su estructura en busca de texturas y archivos de sonido.
	_read_path(dir)
	
	# Escribir el resultado en un JSON que se cargará en la versión Web del juego.
	var err: int = _save_json(JSON_PATH, _assets_paths)
	
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

		if not _editor_file_system.get_file_type(path) == "PackedScene":
			continue
		
		var key := get_key_name(path)
		_mama = (ResourceLoader.load(path) as PackedScene).instance()
		
		_report[key] = {images = 0, audios = 0}

		# ---- Obtener las imágenes del nodo y sus hijos -----------------------
		_assets_paths.images[key] = []

		if _mama.has_method('get_on_demand_textures'):
			var textures: Array = _mama.get_on_demand_textures()
			_assets_paths.images[key].append_array(textures)
		else:
			_go_through_nodes(_mama)

		if (_assets_paths.images[key] as Array).empty():
			_assets_paths.images.erase(key)
		else:
			_report[key].images = _assets_paths.images[key].size()
		
		# ---- Obtener los audios del nodo y sus hijos -------------------------
		_assets_paths.audios[key] = []
		
		if _mama.has_method('get_on_demand_audios'):
			var audios: Dictionary = _mama.get_on_demand_audios()
			_assets_paths.audios = audios
		else:
			_get_node_audio(_mama)
		
		if (_assets_paths.audios[key] as Array).empty():
			_assets_paths.audios.erase(key)
		else:
			_report[key].audios = _assets_paths.audios[key].size()
		
		if not _report[key].images and not _report[key].audios:
			_report.erase(key)


func _go_through_nodes(node: Node, tree := '') -> void:
	_save_node_texture(node, '.')
	
	for c in node.get_children():
		if c.filename:
			continue
		
		var node_path := _get_tree_text(tree, c.name)
		_save_node_texture(c, node_path)

		# not c.filename: para ignorar los nodos que sean una instancia de
		# otra escena.
		if not c.filename and not c.get_children().empty():
			_go_through_nodes(c, node_path)


func _save_node_texture(node: Node, node_path: String) -> void:
	match node.get_class():
		'TextureRect', 'Sprite':
			_add_texture(node_path, node.texture)
		'CheckBox':
			var cb: CheckBox = node
			_add_texture(
				node_path,
				cb.get_icon('checked'),
				'checked'
			)
			_add_texture(
				node_path,
				cb.get_icon('unchecked'),
				'unchecked'
			)
		'Button':
			var b: Button = node
			
			_add_texture(
				node_path,
				b.icon,
				'icon'
			)
			
			if b.get_stylebox('normal') is StyleBoxTexture:
				_add_texture(
					node_path,
					(b.get_stylebox('normal') as StyleBoxTexture).texture,
					'stylebox_normal'
				)
			
			if b.get_stylebox('hover') is StyleBoxTexture:
				_add_texture(
					node_path,
					(b.get_stylebox('hover') as StyleBoxTexture).texture,
					'stylebox_hover'
				)
		'TextureButton':
			var tb: TextureButton = node
			_add_texture(
				node_path,
				tb.texture_normal,
				'texture_normal'
			)
			_add_texture(
				node_path,
				tb.texture_pressed,
				'texture_pressed'
			)
		'Label':
			var l: Label = node
			if l.get_stylebox('normal').get_class() == 'StyleBoxTexture':
				_add_texture(
					node_path,
					(l.get_stylebox('normal') as StyleBoxTexture).texture
				)


func _add_texture(node_path: String, texture: Texture, prop := '') -> void:
	if not texture: return
	
	var new_entry := {
		node = node_path,
		mama = _mama.name,
		path = get_texture_web_path(texture)
	}
	
	if prop:
		new_entry['prop'] = prop
	
	_assets_paths.images[get_key_name(_mama.filename)].append(new_entry)


func _get_node_audio(node: Node, tree := '') -> void:
	for c in node.get_children():
		var node_path := _get_tree_text(tree, c.name)

		match c.get_class():
			'AudioStreamPlayer':
				_add_stream(
					node_path,
					(c as AudioStreamPlayer).stream
				)
			'AudioStreamPlayer2D':
				_add_stream(
					node_path,
					(c as AudioStreamPlayer2D).stream
				)
	
		# not c.filename: para ignorar los nodos que sean una instancia de
		# otra escena.
		if not c.filename and not c.get_children().empty():
			_get_node_audio(c, node_path)


func _add_stream(node_path: String, stream: AudioStream) -> void:
	if not stream: return
	
	var new_entry := {
		node = node_path,
		mama = _mama.name,
		path = get_audio_web_path(stream)
	}
	
	_assets_paths.audios[get_key_name(_mama.filename)].append(new_entry)


func _get_tree_text(parent_name: String, node_name: String) -> String:
	if parent_name:
		return parent_name + '/' + node_name
	else:
		return node_name


func _save_json(path: String, data: Dictionary):
	var directory := Directory.new()
	if not directory.dir_exists(JSON_PATH.get_base_dir()):
		var err: int = directory.make_dir_recursive(JSON_PATH.get_base_dir())
		assert(err == OK, "[GDWL] Can't create directory")
	
	var file = File.new()
	var err = file.open(path, File.WRITE)
	if err == OK:
		file.store_line(to_json(data))
		file.close()
	
	return err
