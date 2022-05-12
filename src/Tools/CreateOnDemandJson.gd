tool
extends EditorScript
# Este script recorre la carpeta seleccionada en FileSystem y sus subcarpetas
# en busca de .TSCN y .TRES para crear un diccionario de imágenes y sonidos
# asociados a nodos para crear un diccionario que permita obtenerlos cuando el
# juego se corre en Web cargando recursos por demanda.

const SRC_PATH := 'res://src/'
const JSON_PATH := 'res://src/Web/on_demand_assets.json'

var _filesys: EditorFileSystem
var _assets_paths := { audios = {}, images = {} }
var _papa: Node
var _papa_dependencies: PoolStringArray


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos de Godot ░░░░
func _run():
	var interface: EditorInterface = get_editor_interface()
	_filesys = interface.get_resource_filesystem()
	var dir: EditorFileSystemDirectory = _filesys.get_filesystem_path(SRC_PATH)
#	var dir: EditorFileSystemDirectory = _filesys.get_filesystem_path(interface.get_selected_path())
	
	# Se recorren todas las carpetas para buscar archivos .TSCN y así analizar
	# su estructura en busca de texturas y archivos de sonido.
	_read_path(dir)
	
	# Escribir el resultado en un JSON que se cargará en la versión Web del juego.
	var err: int = _save_json(JSON_PATH, _assets_paths)
	
	assert(err == OK, '[GDWL] Error creating JSON %d' % err)
	
	var time := OS.get_datetime()
	
	prints(
		'░░░░ H E C H O ░░░░',
		'%d/%d/%d %d:%d:%d' % [
			time.day, time.month, time.year,
			time.hour, time.minute, time.second
		],
		'░░░░ O H C E H ░░░░'
	)


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos públicos ░░░░
func get_texture_web_path(t: Texture) -> String:
	return t.resource_path.trim_prefix('res://assets/images/')


func get_audio_web_path(t: AudioStream) -> String:
	return t.resource_path.trim_prefix('res://assets/audio/')


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos privados ░░░░
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

		if not _filesys.get_file_type(path) == "PackedScene":
			continue

		_papa = (ResourceLoader.load(path) as PackedScene).instance()
#		_papa_dependencies = ResourceLoader.get_dependencies(path)

		# ---- Obtener las imágenes del nodo y sus hijos -----------------------
		_assets_paths.images[_papa.name] = []

		if _papa.has_method('get_on_demand_textures'):
			var textures: Array = _papa.get_on_demand_textures()
			_assets_paths.images[_papa.name].append_array(textures)
		else:
			_add_image_paths(_papa)

		if (_assets_paths.images[_papa.name] as Array).empty():
			_assets_paths.images.erase(_papa.name)
		
		# ---- Obtener los audios del nodo y sus hijos -------------------------
		_assets_paths.audios[_papa.name] = []
		
		if _papa.has_method('get_on_demand_audios'):
			var audios: Dictionary = _papa.get_on_demand_audios()
			_assets_paths.audios = audios
		else:
			_add_audio_paths(_papa)
		
		if (_assets_paths.audios[_papa.name] as Array).empty():
			_assets_paths.audios.erase(_papa.name)


func _add_image_paths(node: Node, tree := '') -> void:
	for c in node.get_children():
		var node_path := _get_tree_text(tree, c.name)

		match c.get_class():
			'TextureRect', 'Sprite':
				_add_image(node_path, c.texture)
			'CheckBox':
				var cb: CheckBox = c
				_add_image(
					node_path,
					cb.get_icon('checked'),
					'checked'
				)
				_add_image(
					node_path,
					cb.get_icon('unchecked'),
					'unchecked'
				)
			'Button':
				pass
#				var b: Button = c
#				prints(b.name, b.get_stylebox('normal'))
#				_add_image(
#					node_path,
#					button.normal,
#					'normal'
#				)
			'TextureButton':
				var tb: TextureButton = c
				_add_image(
					node_path,
					tb.texture_normal,
					'texture_normal'
				)
				_add_image(
					node_path,
					tb.texture_pressed,
					'texture_pressed'
				)
			'Label':
				var l: Label = c
				if l.get_stylebox('normal').get_class() == 'StyleBoxTexture':
					_add_image(
						node_path,
						(l.get_stylebox('normal') as StyleBoxTexture).texture
					)

		# not c.filename: para ignorar los nodos que sean una instancia de
		# otra escena.
		if not c.filename and not c.get_children().empty():
			_add_image_paths(c, node_path)


func _add_image(node_path: String, texture: Texture, theme := '') -> void:
	if not texture: return
	
	var new_entry := {
		node = node_path,
		papa = _papa.name,
		path = get_texture_web_path(texture)
	}
	
	if theme:
		new_entry['theme'] = theme
	
	_assets_paths.images[_papa.name].append(new_entry)


func _add_audio_paths(node: Node, tree := '') -> void:
	for c in node.get_children():
		var node_path := _get_tree_text(tree, c.name)

		match c.get_class():
			'AudioStreamPlayer2D':
				_add_audio(
					node_path,
					(c as AudioStreamPlayer2D).stream
				)
	
		# not c.filename: para ignorar los nodos que sean una instancia de
		# otra escena.
		if not c.filename and not c.get_children().empty():
			_add_audio_paths(c, node_path)


func _add_audio(node_path: String, stream: AudioStream) -> void:
	if not stream: return
	
	var new_entry := {
		node = node_path,
		papa = _papa.name,
		path = get_audio_web_path(stream)
	}
	
	_assets_paths.audios[_papa.name].append(new_entry)


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
