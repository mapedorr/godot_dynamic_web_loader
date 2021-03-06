tool
# Establece y obtiene texturas y clips de audio para nodos específicos.
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

const TYPES := {
	# Control
	TEXTURE_RECT = 'TextureRect',
	CHECKBOX = 'CheckBox',
	BUTTON = 'Button',
	TEXTURE_BUTTON = 'TextureButton',
	LABEL = 'Label',
	NINE_PATCH_RECT = 'NinePatchRect',
	TEXTURE_PROGRESS = 'TextureProgress',
	PROGRESS_BAR = 'ProgressBar',
	PANEL_CONTAIER = 'PanelContainer',
	PANEL = 'Panel',
	# 2D
	SPRITE = 'Sprite',
	LIGHT_2D = 'Light2D',
	# 3D
	MESH_INSTANCE = 'MeshInstance',
	# Audio
	AUDIO_STREAM_PLAYER = 'AudioStreamPlayer',
	AUDIO_STREAM_PLAYER_2D = 'AudioStreamPlayer2D',
}


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos públicos ░░░░
static func get_node_texture(node: Node) -> Array:
	var response := []
	
	match node.get_class():
		TYPES.TEXTURE_RECT, TYPES.SPRITE, TYPES.NINE_PATCH_RECT, TYPES.LIGHT_2D:
			response.append(node.texture)
		TYPES.CHECKBOX:
			var cb: CheckBox = node
			response.append([cb.get_icon('checked'), 'checked'])
			response.append([cb.get_icon('unchecked'), 'unchecked'])
		TYPES.BUTTON:
			var b: Button = node
			response.append([b.icon, 'icon'])
			
			for state in ['hover', 'pressed', 'focus', 'disabled', 'normal']:
				if b.get_stylebox(state) is StyleBoxTexture:
					response.append([
						(b.get_stylebox(state) as StyleBoxTexture).texture,
						'stylebox_' + state
					])
		TYPES.TEXTURE_BUTTON:
			var tb: TextureButton = node
			response.append([tb.texture_normal, 'texture_normal'])
			response.append([tb.texture_pressed, 'texture_pressed'])
			response.append([tb.texture_hover, 'texture_hover'])
			response.append([tb.texture_disabled, 'texture_disabled'])
			response.append([tb.texture_focused, 'texture_focused'])
			response.append([tb.texture_click_mask, 'texture_click_mask'])
		TYPES.LABEL:
			var l: Label = node
			if l.get_stylebox('normal').get_class() == 'StyleBoxTexture':
				response.append(
					(l.get_stylebox('normal') as StyleBoxTexture).texture
				)
		TYPES.TEXTURE_PROGRESS:
			var tp: TextureProgress = node
			
			if tp.texture_under:
				response.append([tp.texture_under, 'under'])
			
			if tp.texture_progress:
				response.append([tp.texture_progress, 'progress'])
			
			if tp.texture_over:
				response.append([tp.texture_over, 'over'])
		TYPES.PROGRESS_BAR:
			var pb: ProgressBar = node
			
			if pb.get_stylebox('fg').get_class() == 'StyleBoxTexture':
				response.append([
					(pb.get_stylebox('fg') as StyleBoxTexture).texture,
					'fg'
				])
			
			if pb.get_stylebox('bg').get_class() == 'StyleBoxTexture':
				response.append([
					(pb.get_stylebox('bg') as StyleBoxTexture).texture,
					'bg'
				])
		TYPES.PANEL, TYPES.PANEL_CONTAIER:
			if node.get_stylebox('panel').get_class() == 'StyleBoxTexture':
				response.append(
					(node.get_stylebox('panel') as StyleBoxTexture).texture
				)
		TYPES.MESH_INSTANCE:
			var m: Material = (node as MeshInstance).get_active_material(0)
			
			if not m: continue
			
			match m.get_class():
				'SpatialMaterial':
					var sm := m as SpatialMaterial
					
					for i in sm.TEXTURE_MAX:
						if sm.get_texture(i):
							response.append([sm.get_texture(i), str(i)])
#		_:
#			prints('Textura para nodo %s(%s)' % [node.name, node.get_class()])
	
	return response


static func get_node_stream(node: Node) -> Array:
	var response := []
	
	match node.get_class():
		TYPES.AUDIO_STREAM_PLAYER:
			response.append((node as AudioStreamPlayer).stream)
		TYPES.AUDIO_STREAM_PLAYER_2D:
			response.append((node as AudioStreamPlayer2D).stream)
	
	return response


static func set_node_texture(node: Node, texture: Texture, data := {}) -> void:
	var style: String = data.style if data.has('style') else ''
	
	match node.get_class():
		TYPES.TEXTURE_RECT, TYPES.SPRITE, TYPES.NINE_PATCH_RECT, TYPES.LIGHT_2D:
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
		TYPES.TEXTURE_PROGRESS:
			var tp: TextureProgress = node
			
			match style:
				'under':
					tp.texture_under = texture
				'progress':
					tp.texture_progress = texture
				'over':
					tp.texture_over = texture
		TYPES.PROGRESS_BAR:
			var pb: ProgressBar = node
			
			match style:
				'fg':
					(pb.get_stylebox('fg') as StyleBoxTexture).texture = texture
				'bg':
					(pb.get_stylebox('bg') as StyleBoxTexture).texture = texture
		TYPES.PANEL, TYPES.PANEL_CONTAIER:
			(node.get_stylebox('panel') as StyleBoxTexture).texture = texture
		TYPES.MESH_INSTANCE:
			var m: Material = (node as MeshInstance).get_active_material(0)
			
			if not m: continue
			
			match m.get_class():
				'SpatialMaterial':
					(m as SpatialMaterial).set_texture(int(style), texture)


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
