extends Node
# warning-ignore-all:unused_signal
# warning-ignore-all:return_value_discarded

signal asset_ready(dic)
signal load_done(container_id)

const ASSETS_PATH := 'http://127.0.0.1:8080/assets/%s/%s'

var _load_counts := {}

var dwl_dic := {}


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos de Godot ░░░░
func _ready() -> void:
	if OS.has_feature('dwl'):
		get_tree().connect('node_added', self, 'on_node_added')
#	get_tree().connect('tree_changed', self, 'testo') # Puede ser la plena
	
#	load_json()
	
	if OS.has_feature('dwl'):
		var http_request = HTTPRequest.new()
		add_child(http_request)
		
		http_request.connect(
			'request_completed',
			self,
			'_json_request_completed'
		)
		
		var error = http_request.request('http://127.0.0.1:8080/on_demand_assets.json')
		if error != OK:
			push_error("An error occurred in the HTTP request.")



# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos públicos ░░░░
func on_node_added(node: Node) -> void:
	prints('>>>', node.name)
	load_pack(
		node,
		dwl_dic.images[node.name] if dwl_dic.images.has(node.name) else [],
		dwl_dic.audios[node.name] if dwl_dic.audios.has(node.name) else []
	)


func load_pack(container: Node, images := [], audios := []) -> Node:
	_load_counts[container.get_instance_id()] = {
		total_files = 0,
		loaded_files = 0
	}

#	var requesters_container := Node.new()
#	container.add_child(requesters_container)
	
	var assets := []
	
	if not images.empty(): assets.append_array(images)
	if not audios.empty():
		assets.append_array(audios)
#		for s in audios:
#			assets.append(Globals.on_demand_dic.audios[s])
	
	if assets.empty():
		prints('No hay nada para cargar en el nodo', container.name)
		return null
	
	for asset in assets:
		var ext: String = asset.path.get_extension()
		
		var http_request = HTTPRequest.new()
		add_child(http_request)
#		requesters_container.add_child(http_request)
		http_request.connect(
			'request_completed',
			self,
			'_http_request_completed',
			[ext, asset, container]
		)

		var error := OK

		if ext == 'png' or ext == 'jpg':
			error = http_request.request(ASSETS_PATH % ['images', asset.path])
		elif ext == 'ogg' or ext == 'mp3':
			error = http_request.request(ASSETS_PATH % ['audios', asset.path])

		if error != OK:
			push_error('An error occurred in the HTTP request.')

		_load_counts[container.get_instance_id()].total_files += 1

	return null


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos privados ░░░░
func _json_request_completed(\
_result: int,
_response_code: int,
_headers: PoolStringArray,
body: PoolByteArray) -> void:
	var response = parse_json(body.get_string_from_utf8())
	dwl_dic = response
	
	if dwl_dic.images.has(get_tree().current_scene.name):
		load_pack(
			get_tree().current_scene,
			dwl_dic.images[get_tree().current_scene.name],
			dwl_dic.audios[get_tree().current_scene.name]
		)


func _http_request_completed(
	_result: int,
	_response_code: int,
	_headers: PoolStringArray,
	body: PoolByteArray,
	# Parámetros adicionales
	ext: String,
	data: Dictionary,
	mama: Node
):
#	var mama: Node = requesters_container.get_parent()
	var mama_counts: Dictionary = _load_counts[mama.get_instance_id()]
	
	mama_counts.loaded_files += 1
	
	if ext == 'png' or ext == 'jpg':
		# Se cargó una imagen del servidor
		var image: Image = Image.new()
		var error := OK
		
		if ext == 'png':
			error = image.load_png_from_buffer(body)
		elif ext == 'jpg':
			error = image.load_jpg_from_buffer(body)
		
		if error != OK:
			push_error('Couldn\'t load the image.')

		var texture = ImageTexture.new()
		texture.create_from_image(image)
		
		if mama.has_method('set_on_demand_texture'):
			mama.set_on_demand_texture(texture, data.prop)
		else:
			var response := {
				type = 'image',
				res = texture,
				node = data.node,
				mama = mama
			}
			
			if data.has('prop'):
				response.prop = data.prop

			_asset_loaded(response)

#		emit_signal('asset_ready', response)
	else:
		# Se cargó un archivo de audio del servidor
		var audio_stream: AudioStream

		if ext == 'mp3':
			audio_stream = AudioStreamMP3.new()
		else:
			audio_stream = AudioStreamOGGVorbis.new()

		audio_stream.data = body

		_asset_loaded({
			type = 'audio',
			res = audio_stream,
			node = data.node,
			mama = mama,
#			resource_name = data.name
		})
	
	if mama_counts.loaded_files == mama_counts.total_files:
		emit_signal('load_done', mama.get_instance_id())
		# TODO: Eliminar el HttpRequest creado
#		requesters_container.queue_free()


func _asset_loaded(data: Dictionary):
	if data.type == 'image':
		var node := (data.mama as Node).get_node(data.node)
		match node.get_class():
			'TextureRect', 'Sprite':
				node.texture = data.res
			'CheckBox':
				(node as CheckBox).add_icon_override(data.prop, data.res)
			'TextureButton':
				var tb: TextureButton = node
				
				match data.prop:
					'texture_normal':
						tb.texture_normal = data.res
					'texture_pressed':
						tb.texture_pressed = data.res
			'Button':
				var b: Button = node
				
				match data.prop:
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


func load_json():
	var file = File.new()
	
	if not file.file_exists('res://src/Web/on_demand_assets.json'):
		prints('NOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO')
		return
	
	file.open('res://src/Web/on_demand_assets.json', File.READ)
	var data = parse_json(file.get_as_text())
	var file_data = data
	
	prints(file_data)
