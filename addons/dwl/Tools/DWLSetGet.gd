tool
# Establece y obtiene texturas y clips de audio para nodos específicos.
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

const TYPES := {
	TEXTURE_RECT = 'TextureRect',
	SPRITE = 'Sprite',
	CHECKBOX = 'CheckBox',
	BUTTON = 'Button',
	TEXTURE_BUTTON = 'TextureButton',
	LABEL = 'Label',
	PROGRESS_BAR = 'ProgressBar',
	TEXTURE_PROGRESS = 'TextureProgress',
	# Audio
	AUDIO_STREAM_PLAYER = 'AudioStreamPlayer',
	AUDIO_STREAM_PLAYER_2D = 'AudioStreamPlayer2D',
}


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos públicos ░░░░
static func get_node_texture(node: Node) -> Array:
	var response := []
	
	match node.get_class():
		TYPES.TEXTURE_RECT, TYPES.SPRITE:
			response.append(node.texture)
		TYPES.CHECKBOX:
			var cb: CheckBox = node
			response.append([cb.get_icon('checked'), 'checked'])
			response.append([cb.get_icon('unchecked'), 'unchecked'])
		TYPES.BUTTON:
			var b: Button = node
			response.append([b.icon, 'icon'])
			
			if b.get_stylebox('normal') is StyleBoxTexture:
				response.append([
					(b.get_stylebox('normal') as StyleBoxTexture).texture,
					'stylebox_normal'
				])
			
			if b.get_stylebox('hover') is StyleBoxTexture:
				response.append([
					(b.get_stylebox('hover') as StyleBoxTexture).texture,
					'stylebox_hover'
				])
		TYPES.TEXTURE_BUTTON:
			var tb: TextureButton = node
			response.append([tb.texture_normal, 'texture_normal'])
			response.append([tb.texture_pressed, 'texture_pressed'])
		TYPES.LABEL:
			var l: Label = node
			if l.get_stylebox('normal').get_class() == 'StyleBoxTexture':
				response.append(
					(l.get_stylebox('normal') as StyleBoxTexture).texture
				)
	
	return response


static func get_node_stream(node: Node) -> Array:
	var response := []
	
	match node.get_class():
		TYPES.AUDIO_STREAM_PLAYER:
			response.append((node as AudioStreamPlayer).stream)
		TYPES.AUDIO_STREAM_PLAYER_2D:
			response.append((node as AudioStreamPlayer2D).stream)
	
	return response


static func set_node_texture(node: Node, texture: Texture, style := '') -> void:
	match node.get_class():
		TYPES.TEXTURE_RECT, TYPES.SPRITE:
			node.texture = texture
		TYPES.CHECKBOX:
			(node as CheckBox).add_icon_override(style, texture)
		TYPES.TEXTURE_BUTTON:
			var tb: TextureButton = node
			
			match style:
				'texture_normal':
					tb.texture_normal = texture
				'texture_pressed':
					tb.texture_pressed = texture
		TYPES.BUTTON:
			var b: Button = node
			
			match style:
				'icon':
					b.icon = texture
				'stylebox_normal':
					(b.get_stylebox('normal') as StyleBoxTexture).texture =\
					texture
				'stylebox_hover':
					(b.get_stylebox('hover') as StyleBoxTexture).texture =\
					texture
		TYPES.LABEL:
			(node.get_stylebox('normal') as StyleBoxTexture).texture =\
			texture


static func set_node_stream(node: Node, stream: AudioStream, extra := '') -> void:
	match node.get_class():
		TYPES.AUDIO_STREAM_PLAYER:
			node.stream = stream
			if (node as AudioStreamPlayer).autoplay:
				(node as AudioStreamPlayer).play()
		TYPES.AUDIO_STREAM_PLAYER_2D:
			node.stream = stream
			if (node as AudioStreamPlayer2D).autoplay:
				(node as AudioStreamPlayer2D).play()