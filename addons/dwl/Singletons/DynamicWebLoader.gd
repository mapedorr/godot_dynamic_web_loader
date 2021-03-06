extends Node
# warning-ignore-all:unused_signal
# warning-ignore-all:return_value_discarded

signal asset_ready(dic)
signal load_started(total_files)
signal load_progress(loaded_files, total_files)
signal load_done(scene_path)
signal json_loaded

const SetGet := preload('res://addons/dwl/Tools/DWLSetGet.gd')

var _load_counts := {}
var _loaded_files := 0
var _total_files := 0
# Si la llave existe y tiene null, entonces se está cargando el asset
# Si la llave existe y tiene el asset, entonces ya se cargó el asset
# Si la llave no existe, entonces se tiene que descargar el asset
var _loaded_assets := {}
# Diccionario con la información de los nodos (value) que están esperando a que
# se termine de cargar un asset (key)
var _waiting_for_asset := {}

var dwl_dic := {}

onready var _customs := DWLResources.get_customs()


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos de Godot ░░░░
func _ready() -> void:
#	get_tree().connect('tree_changed', self, 'testo') # Puede ser la plena
	if OS.has_feature('dwl'):
		# _load_json() # Para cargar el JSON si está en el .pck
		
		var http_request = HTTPRequest.new()
		$HTTPRequestContainers.add_child(http_request)
		
		http_request.connect(
			'request_completed',
			self,
			'_json_request_completed',
			[http_request]
		)
		
		var error = http_request.request(DWLResources.get_json_url())
		if error != OK:
			prints('[DWL] Ocurrió un error con la petición HTTP.')


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos públicos ░░░░
func on_node_added(node: Node) -> void:
	load_node_assets(node)


# Carga los assets (imágenes y audios) en base al nombre del nodo.
# Útil para pre-cargar los assets de un nodo que aún no se ha añadido al árbol.
func preload_assets(scene_path: String, load_grandchilds := false) -> void:
	_load_assets(scene_path)
	
	if load_grandchilds:
		var grandchilds: Array = dwl_dic.grandchilds[scene_path]\
		if dwl_dic.grandchilds.has(scene_path)\
		else []
		
		for gc in grandchilds:
			var node: Node = load(scene_path).instance()
			_load_assets(node.get_node(gc.path), scene_path)


# Carga los assets (imágenes y audios) para un nodo y se los asigna a este y a
# sus hijos.
func load_node_assets(node: Node, load_grandchilds := false) -> void:
	_load_assets(node)
	
	if load_grandchilds:
		var grandchilds: Array = dwl_dic.grandchilds[node.filename]\
		if dwl_dic.grandchilds.has(node.filename)\
		else []
		
		for gc in grandchilds:
			_load_assets(node.get_node(gc.path), node.filename)


func get_asset(path: String) -> Resource:
	if _loaded_assets.has(path):
		return _loaded_assets[path]
	return null


func custom_load_finished(id: String, assets_count := 0) -> void:
	_loaded_files += assets_count
	
	if _load_counts.has(id):
		_load_counts[id].loaded_files += assets_count
		_check_load_count(id)


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos privados ░░░░
#func _load_json():
#	var file = File.new()
#
#	if not file.file_exists('res://dwl/dwl.json'):
#		return
#
#	file.open('res://dwl/dwl.json', File.READ)
#	var data = parse_json(file.get_as_text())
#	var file_data = data


func _json_request_completed(
	_result: int,
	_response_code: int,
	_headers: PoolStringArray,
	body: PoolByteArray,
	# extra params
	http_request: HTTPRequest
) -> void:
	http_request.queue_free()
	
	# Sólo conectarse a esta señal cuando el JSON ya esté listo para decirnos
	# si un nodo añadido al árbol tiene assets asociados.
	get_tree().connect('node_added', self, 'on_node_added')
	
	var response = parse_json(body.get_string_from_utf8())
	dwl_dic = response
	
	for c in get_tree().root.get_children():
		load_node_assets(c)
		
		# TODO: ¿Será obligatorio hacer algo para que recorra todos los hijos
		# de todos los nodos en la escena en busca de assets para cargar?
		# Puede ser que sólo recorra hijos de nodos que tengan filename (o sea,
		# que sean instancias de .tscn).
		for c2 in c.get_children():
			load_node_assets(c2)
	
	emit_signal('json_loaded')


# src puede ser un String o un Node
func _load_assets(src, grandma := '') -> void:
	var id: String = src if typeof(src) == TYPE_STRING else src.filename
	
	if not _load_counts.has(id):
		_load_counts[id] = {
			total_files = 0,
			loaded_files = 0
		}
	
	if grandma:
		_load_counts[id].grandma = grandma
		
		if not _load_counts.has(grandma):
			_load_counts[grandma] = {
				total_files = 0,
				loaded_files = 0
			}
	
	for asset in _get_assets_data(id):
		if asset.has('custom_textures_load') or asset.has('custom_audios_load'):
			if typeof(src) == TYPE_STRING:
				# Si se está haciendo una precarga hay que asegurar que también
				# se cargarán los assets que hacen parte de la carga personalizada
				src = load(src).instance()
			
			var assets_count := 0
			
			if src.has_method('custom_textures_load'):
				assets_count = src.custom_textures_load(asset)
			elif src.has_method('custom_audios_load'):
				assets_count = src.custom_audios_load(asset)
			
			_load_counts[id].total_files += assets_count
			_total_files += assets_count
			
			if grandma:
				_load_counts[grandma].total_files += assets_count
			
			continue
		
		var ext: String = asset.path.get_extension()
		var asset_copy := (asset as Dictionary).duplicate()
		# Obtener la ruta del asset en base a posibles reglas definidas por la
		# desarrolladora
		asset_copy.path = _get_asset_path(asset_copy)
		
		# Verificar si el path del asset no ha sido ya cargado o no está siendo
		# cargado
		if _loaded_assets.has(asset_copy.path):
			# Si el path del asset ya está en el diccionario de assets cargados
			# entonces no hay que hacer ninguna petición
			if typeof(src) == TYPE_STRING:
				# Se está haciendo una pre-carga -> No hay que hacer nada más.
				continue
			
			if is_instance_valid(_loaded_assets[asset_copy.path]):
				# Si la llave existe y tiene el asset, entonces se puede asignar
				_assign_asset(ext, _loaded_assets[asset_copy.path], asset_copy, src)
			else:
				# Si la llave existe y tiene null, entonces se está cargando el
				# asset
				# TODO: Hacer algo para que cuando se cargue el asset se asigne
				# a todos los nodos que lo están esperando.
				if not _waiting_for_asset.has(asset_copy.path):
					_waiting_for_asset[asset_copy.path] = []
				
				_waiting_for_asset[asset_copy.path].append({
					data = asset_copy,
					mama = src
				})
			
			continue
		
		_request_asset(asset_copy.path.get_extension(), asset_copy, src)
	
	if _total_files == 0:
		return
	
	emit_signal('load_started', _total_files)


func _get_assets_data(scene_path: String) -> Array:
	if not scene_path:
		return []
	
	var data := []
	var images: Array = dwl_dic.images[scene_path]\
		if dwl_dic.images.has(scene_path)\
		else []
	var audios: Array = dwl_dic.audios[scene_path]\
		if dwl_dic.audios.has(scene_path)\
		else []
	
	if not images.empty():
		data.append_array(images)
	if not audios.empty():
		data.append_array(audios)
	
	if data.empty():
		prints('[DWL] No hay assets para ' + scene_path)
		return []
	
	return data


func _get_asset_path(asset: Dictionary) -> String:
	return '%s/%s.%s' % _customs.get_asset_path(
		asset.path.get_base_dir(),
		Array(asset.path.get_basename().split('/')).pop_back(),
		asset.path.get_extension()
	)


func _request_asset(ext: String, data: Dictionary, target) -> void:
	var id: String = target\
		if typeof(target) == TYPE_STRING\
		else target.filename
	var cb := '_lazy_load_completed'\
		if typeof(target) == TYPE_STRING\
		else '_load_completed'
	
	var http_request = HTTPRequest.new()
	$HTTPRequestContainers.add_child(http_request)
	http_request.connect(
		'request_completed',
		self,
		'_asset_downloaded',
		[ext, data, target, http_request]
	)
	
	var error := OK
	
	if ext == 'png' or ext == 'jpg':
		error = http_request.request(
			DWLResources.get_assets_url() % data.path
		)
	elif ext == 'ogg' or ext == 'mp3':
		error = http_request.request(
			DWLResources.get_assets_url() % data.path
		)
	
	if error != OK:
		prints('[DWL] Ocurrió un error con la petición HTTP.')
	
	# Al poner esto en null, el sistema sabrá que el asset se está descargando
	# en caso de que otro de los elementos en el JSON pida el mismo asset.
	_loaded_assets[data.path] = null
	
	_load_counts[id].total_files += 1
	_total_files += 1
	
	if _load_counts[id].has('grandma'):
		_load_counts[_load_counts[id].grandma].total_files += 1


func _asset_downloaded(
	_result: int,
	_response_code: int,
	_headers: PoolStringArray,
	body: PoolByteArray,
	# Parámetros adicionales
	ext: String,
	data: Dictionary,
	# Puede ser un String (si se hizo pre-carga) o un Node (si se descarga el
	# asset cuando el nodo entra al árbol)
	target,
	http_request: HTTPRequest
) -> void:
	var id: String = target\
		if typeof(target) == TYPE_STRING\
		else target.filename
	var node: Node = null if typeof(target) == TYPE_STRING else target
	var mama_counts: Dictionary = _load_counts[id]
	var res = null # Va a guardar la imagen o el stream de audio del asset
	
	mama_counts.loaded_files += 1
	_loaded_files += 1
	
	if ext == 'png' or ext == 'jpg':
		# Se cargó una imagen del servidor
		var image: Image = Image.new()
		var error := OK
		
		if ext == 'png':
			error = image.load_png_from_buffer(body)
		elif ext == 'jpg':
			error = image.load_jpg_from_buffer(body)
		
		if error != OK:
			prints('[DWL] No se puo cargar la imagen.', error)

		res = ImageTexture.new()
		res.create_from_image(image, data.flags)
	else:
		# Se cargó un archivo de audio del servidor
		if ext == 'mp3':
			res = AudioStreamMP3.new()
		else:
			res = AudioStreamOGGVorbis.new()
		
		res.data = body
	
	_loaded_assets[data.path] = res
	if node:
		_assign_asset(ext, res, data, node)
	
	http_request.queue_free()
	
	emit_signal('load_progress', _loaded_files, _total_files)
	
	_check_load_count(id)


func _check_load_count(id: String) -> void:
	var load_counts: Dictionary = _load_counts[id]
	
	if load_counts.loaded_files == load_counts.total_files:
		yield(get_tree(), 'idle_frame')
		
		if $HTTPRequestContainers.get_child_count() == 0:
			_total_files = 0
			_loaded_files = 0
		
		emit_signal('load_done', id)
		
		if load_counts.has('grandma'):
			_load_counts[load_counts.grandma].loaded_files +=\
			load_counts.total_files
			
			_check_load_count(load_counts.grandma)


func _assign_asset(ext: String, res, data: Dictionary, mama: Node):
	if ext == 'png' or ext == 'jpg':
		if data.has('prop'):
			if mama.has_method('set_extra_texture'):
				mama.set_extra_texture(data.prop, res)
			return
		
		if not _customs.set_node_texture(mama.get_node(data.node), res, data):
			SetGet.set_node_texture(mama.get_node(data.node), res, data)
		
		if _waiting_for_asset.has(data.path):
			for dic in _waiting_for_asset[data.path]:
				if not _customs.set_node_texture(\
				dic.mama.get_node(dic.data.node), res, dic.data):
					SetGet.set_node_texture(
						dic.mama.get_node(dic.data.node),
						res,
						dic.data
					)
			_waiting_for_asset.erase(data.path)
		
	else:
		if data.has('prop'):
			if mama.has_method('set_prop_stream'):
				mama.set_prop_stream(data.prop, res)
			return
		
		if not _customs.set_node_stream(\
		mama.get_node(data.node), res, data.extra if data.has('extra') else ''):
			SetGet.set_node_stream(
				mama.get_node(data.node),
				res,
				data.extra if data.has('extra') else ''
			)
