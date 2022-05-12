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
#	get_tree().connect('node_added', self, 'testo')
#	get_tree().connect('tree_changed', self, 'testo') # Puede ser la plena
	
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
func testo() -> void:
	prints()


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
	papa: Node
):
#	var papa: Node = requesters_container.get_parent()
	var papa_counts: Dictionary = _load_counts[papa.get_instance_id()]
	
	papa_counts.loaded_files += 1
	
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
		
		if papa.has_method('set_on_demand_texture'):
			papa.set_on_demand_texture(texture, data.prop)
		else:
			var response := {
				type = 'image',
				res = texture,
				node = data.node,
				papa = papa
			}
			
			if data.has('theme'):
				response.theme = data.theme

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
			papa = papa,
#			resource_name = data.name
		})
	
	if papa_counts.loaded_files == papa_counts.total_files:
		emit_signal('load_done', papa.get_instance_id())
		# TODO: Eliminar el HttpRequest creado
#		requesters_container.queue_free()


func _asset_loaded(data: Dictionary):
	if data.type == 'image':
		var node := (data.papa as Node).get_node(data.node)
		match node.get_class():
			'TextureRect', 'Sprite':
				node.texture = data.res
			'CheckBox':
				(node as CheckBox).add_icon_override(data.theme, data.res)
			'TextureButton':
				match data.theme:
					'texture_normal':
						(node as TextureButton).texture_normal = data.res
					'texture_pressed':
						(node as TextureButton).texture_pressed = data.res
			'Label':
				(node.get_stylebox('normal') as StyleBoxTexture).texture = data.res
	else:
		var node := (data.papa as Node).get_node(data.node)
		match node.get_class():
			'AudioStreamPlayer2D':
				node.stream = data.res
				prints('>>>>', node.name)
				(node as AudioStreamPlayer2D).play()
#		A.set_on_demand_audio(data.res, data.resource_name)
