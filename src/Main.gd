extends Node2D

export var world_scene: PackedScene = null

onready var _btn_open_world: Button = find_node('BtnOpenWorld')
onready var _btn_load_assets: Button = find_node('BtnLoadAssets')

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_btn_open_world.connect('pressed', self, '_load_world_scene')
	_btn_load_assets.connect('pressed', self, '_load_world_assets')


func _load_world_scene() -> void:
	if not world_scene: return
	
	_btn_open_world.hide()
	_btn_load_assets.hide()
	
	$MapBgSfx.stop()
	$MapMusic.stop()
	$Scenes.add_child(world_scene.instance())


func _load_world_assets() -> void:
	_btn_load_assets.disabled = true
	DWL.preload_assets(world_scene.resource_path)
	DWL.connect('load_done', self, '_goto_world')


func _goto_world(_scene_path: String) -> void:
	prints('Estamos listos para ir al mundo real!!!')
	DWL.disconnect('load_done', self, '_goto_world')
