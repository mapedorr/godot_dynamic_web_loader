tool
extends Node2D

const Player := preload('res://src/Characters/Player.tscn')

export var txt: Texture
export(Array, Texture) var texturitas = []


func _ready() -> void:
	$Button.connect('pressed', self, '_add_cosos')


func _add_cosos() -> void:
	if not txt: return
	
	$Button.disabled = true
	var s := Sprite.new()
	s.texture = txt
	
	add_child(s)
	
	for t in texturitas:
		var s2 := Sprite.new()
		s2.texture = t
		add_child(s2)


func get_prop_textures() -> Array:
	var textures := [
		{
			prop = 'txt',
			texture = txt
		}
	]
	
	for t in texturitas:
		textures.append({
			prop = 'texturitas',
			texture = t
		})
	
	return textures


func set_prop_texture(prop: String, texture: Texture) -> void:
	if prop == 'txt':
		txt = texture
	elif prop == 'texturitas':
		texturitas.append(texture)
