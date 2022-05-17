extends Node2D

export var world_scene: PackedScene = null

onready var _btn_open_world: Button = find_node('BtnOpenWorld')

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_btn_open_world.connect('pressed', self, '_load_world_scene')


func _load_world_scene() -> void:
	if not world_scene: return
	
	_btn_open_world.hide()
	$MapBgSfx.stop()
	$MapMusic.stop()
	$Scenes.add_child(world_scene.instance())
