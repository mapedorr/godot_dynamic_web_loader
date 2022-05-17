extends Node2D

const Player := preload('res://src/Characters/Player.tscn')


func _ready() -> void:
	yield(get_tree().create_timer(3.0), 'timeout')
	
	var player: Sprite = Player.instance()
	player.scale = Vector2.ONE * .5
	player.position = Vector2(1920.0 / 2.0, 1080.0 / 2.0)
	
	add_child(player)
	
