extends Node
# warning-ignore-all:unused_signal
# warning-ignore-all:return_value_discarded

signal asset_ready(dic)
signal load_started(total_files)
signal load_progress(loaded_files, total_files)
signal load_done(scene_path)

var _load_counts := {}
var _loaded_files := 0
var _total_files := 0
# Si la llave existe y tiene null, entonces se está cargando el asset
# Si la llave existe y tiene el asset, entonces ya se cargó el asset
# Si la llave no existe, entonces se tiene que descargar el asset
var _loaded_assets := {}

var dwl_dic := {}

onready var _customs := DWLResources.get_customs()


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos de Godot ░░░░
func _ready() -> void:
	if OS.has_feature('dwl'):
		get_tree().connect('node_added', self, 'on_node_added')
#	get_tree().connect('tree_changed', self, 'testo') # Puede ser la plena
	
	if OS.has_feature('dwl'):
		# load_json() # Para cargar el JSON si está en el .pck
		
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
	load_and_assign(
		node,
		dwl_dic.images[node.filename] if dwl_dic.images.has(node.filename) else [],
		dwl_dic.audios[node.filename] if dwl_dic.audios.has(node.filename) else []
	)


# Carga los assets (imágenes y audios) en base al nombre del nodo.
# ... también podría ser lazy_load(...)
func load_assets(scene_path: String) -> void:
	_load_counts[scene_path] = {
		total_files = 0,
		loaded_files = 0
	}
	
	var assets := []
	var images: Array = dwl_dic.images[scene_path]\
		if dwl_dic.images.has(scene_path)\
		else []
	var audios: Array = dwl_dic.audios[scene_path]\
		if dwl_dic.audios.has(scene_path)\
		else []
	
	if not images.empty():
		assets.append_array(images)
	if not audios.empty():
		assets.append_array(audios)
	
	if assets.empty():
		prints('[DWL] No hay assets para ' + scene_path)
		return
	
	for asset in assets:
		var ext: String = asset.path.get_extension()
		asset.path = '%s.%s' % [
			_customs.get_asset_name(asset.path.get_basename(), ext),
			ext
		]
		
		# Verificar si el path del asset no ha sido ya cargado o no está siendo
		# cargado
		if _loaded_assets.has(asset.path):
			continue
		
		var http_request = HTTPRequest.new()
		$HTTPRequestContainers.add_child(http_request)
		http_request.connect(
			'request_completed',
			self,
			'_lazy_load_completed',
			[ext, asset, scene_path, http_request]
		)
		
		var error := OK
		
		if ext == 'png' or ext == 'jpg':
			error = http_request.request(
				DWLResources.get_assets_url() % ['images', asset.path]
			)
		elif ext == 'ogg' or ext == 'mp3':
			error = http_request.request(
				DWLResources.get_assets_url() % ['audios', asset.path]
			)
		
		if error != OK:
			prints('[DWL] Ocurrió un error con la petición HTTP.')
		
		_load_counts[scene_path].total_files += 1
		_total_files += 1
	
	prints('Archivos a cargar', _total_files)
	emit_signal('load_started', _total_files)


# Carga los assets (imágenes y audios) para un nodo y se los asigna a este y a
# sus hijos.
func load_and_assign(node: Node, images := [], audios := []) -> Node:
	_load_counts[node.filename] = {
		total_files = 0,
		loaded_files = 0
	}
	var assets := []
	
	if not images.empty():
		assets.append_array(images)
	if not audios.empty():
		assets.append_array(audios)
	
	if assets.empty():
		return null
	
	for asset in assets:
		var ext: String = asset.path.get_extension()
		
		# Verificar si el path del asset no ha sido ya cargado o no está siendo
		# cargado
		if _loaded_assets.has(asset.path):
			# Si la llave existe y tiene null, entonces se está cargando el asset
			# Si la llave existe y tiene el asset, entonces ya se cargó el asset
			if is_instance_valid(_loaded_assets[asset.path]):
				if asset.has('prop'):
					if node.has_method('set_prop_texture'):
						node.set_prop_texture(asset.prop, _loaded_assets[asset.path])
				else:
					_assign_asset({
						type = 'image' if (ext == 'png' or ext == 'jpg') else 'audio',
						res = _loaded_assets[asset.path],
						node = asset.node,
						mama = node
					})
			else:
				# TODO: Hacer algo para que cuando se cargue el asset se asigne
				# a todos los nodos que lo están esperando.
				pass
			continue
		# Si la llave no existe, entonces se tiene que descargar el asset
		
		var http_request = HTTPRequest.new()
		$HTTPRequestContainers.add_child(http_request)
		http_request.connect(
			'request_completed',
			self,
			'_http_request_completed',
			[ext, asset, node, http_request]
		)
		
		var error := OK
		
		if ext == 'png' or ext == 'jpg':
			error = http_request.request(
				DWLResources.get_assets_url() % ['images', asset.path]
			)
		elif ext == 'ogg' or ext == 'mp3':
			error = http_request.request(
				DWLResources.get_assets_url() % ['audios', asset.path]
			)
		
		if error != OK:
			prints('[DWL] Ocurrió un error con la petición HTTP.')
		
		_load_counts[node.filename].total_files += 1
		_total_files += 1
	
	prints('Archivos a cargar', _total_files)
	emit_signal('load_started', _total_files)
	
	return node


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos privados ░░░░
func _json_request_completed(\
_result: int,
_response_code: int,
_headers: PoolStringArray,
body: PoolByteArray,
# extra params
http_request: HTTPRequest
) -> void:
	http_request.queue_free()
	
	var response = parse_json(body.get_string_from_utf8())
	dwl_dic = response
	
	if dwl_dic.images.has(get_tree().current_scene.filename):
		load_and_assign(
			get_tree().current_scene,
			dwl_dic.images[get_tree().current_scene.filename],
			dwl_dic.audios[get_tree().current_scene.filename]
		)


func _http_request_completed(\
_result: int,
_response_code: int,
_headers: PoolStringArray,
body: PoolByteArray,
# Parámetros adicionales
ext: String,
data: Dictionary,
mama: Node,
http_request: HTTPRequest
) -> void:
	var mama_counts: Dictionary = _load_counts[mama.filename]
	
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
			prints('[DWL] No se puo cargar la imagen.')

		var texture = ImageTexture.new()
		texture.create_from_image(image)
		_loaded_assets[data.path] = texture
		
		if data.has('prop'):
			if mama.has_method('set_prop_texture'):
				mama.set_prop_texture(data.prop, texture)
		else:
			var response := {
				type = 'image',
				res = texture,
				node = data.node,
				mama = mama
			}
			
			if data.has('style'):
				response.style = data.style
			
			_assign_asset(response)
		
#		emit_signal('asset_ready', response)
	else:
		# Se cargó un archivo de audio del servidor
		var audio_stream: AudioStream
		
		if ext == 'mp3':
			audio_stream = AudioStreamMP3.new()
		else:
			audio_stream = AudioStreamOGGVorbis.new()
		
		audio_stream.data = body
		_loaded_assets[data.path] = audio_stream
		
		_assign_asset({
			type = 'audio',
			res = audio_stream,
			node = data.node,
			mama = mama,
#			resource_name = data.name
		})
	
	prints('Archivo cargado:', data.path.get_file())
	http_request.queue_free()
	
	emit_signal('load_progress', _loaded_files, _total_files)
	
	if mama_counts.loaded_files == mama_counts.total_files:
		yield(get_tree(), 'idle_frame')
		
		if $HTTPRequestContainers.get_child_count() == 0:
			_total_files = 0
			_loaded_files = 0
		
		emit_signal('load_done', mama.filename)


func _assign_asset(data: Dictionary):
	if data.type == 'image':
		var node := (data.mama as Node).get_node(data.node)
		match node.get_class():
			'TextureRect', 'Sprite':
				node.texture = data.res
			'CheckBox':
				(node as CheckBox).add_icon_override(data.style, data.res)
			'TextureButton':
				var tb: TextureButton = node
				
				match data.style:
					'texture_normal':
						tb.texture_normal = data.res
					'texture_pressed':
						tb.texture_pressed = data.res
			'Button':
				var b: Button = node
				
				match data.style:
					'icon':
						b.icon = data.res
					'stylebox_normal':
						(b.get_stylebox('normal') as StyleBoxTexture).texture =\
						data.res
					'stylebox_hover':
						(b.get_stylebox('hover') as StyleBoxTexture).texture =\
						data.res
			'Label':
				(node.get_stylebox('normal') as StyleBoxTexture).texture =\
				data.res
	else:
		var node := (data.mama as Node).get_node(data.node)
		match node.get_class():
			'AudioStreamPlayer':
				node.stream = data.res
				(node as AudioStreamPlayer).play()
			'AudioStreamPlayer2D':
				node.stream = data.res
				(node as AudioStreamPlayer2D).play()
#		A.set_on_demand_audio(data.res, data.resource_name)


func _lazy_load_completed(\
_result: int,
_response_code: int,
_headers: PoolStringArray,
body: PoolByteArray,
# Parámetros adicionales
ext: String,
data: Dictionary,
target_scene: String,
http_request: HTTPRequest
) -> void:
	var mama_counts: Dictionary = _load_counts[target_scene]
	
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
			prints('[DWL] No se puo cargar la imagen.')

		var texture = ImageTexture.new()
		texture.create_from_image(image)
		_loaded_assets[data.path] = texture
	else:
		# Se cargó un archivo de audio del servidor
		var audio_stream: AudioStream
		
		if ext == 'mp3':
			audio_stream = AudioStreamMP3.new()
		else:
			audio_stream = AudioStreamOGGVorbis.new()
		
		audio_stream.data = body
		_loaded_assets[data.path] = audio_stream
	
	prints('Archivo cargado:', data.path.get_file())
	http_request.queue_free()
	
	emit_signal('load_progress', _loaded_files, _total_files)
	
	if mama_counts.loaded_files == mama_counts.total_files:
		yield(get_tree(), 'idle_frame')
		
		if $HTTPRequestContainers.get_child_count() == 0:
			_total_files = 0
			_loaded_files = 0
		
		emit_signal('load_done', target_scene)


func load_json():
	var file = File.new()
	
	if not file.file_exists('res://dwl/dwl.json'):
		prints('NOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO')
		return
	
	file.open('res://dwl/dwl.json', File.READ)
	var data = parse_json(file.get_as_text())
	var file_data = data
	
	prints(file_data)
