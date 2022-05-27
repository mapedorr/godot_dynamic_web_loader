extends Node


# Puede cambiar el nombre (¿o ruta?) de un asset en base a alguna validación.
static func get_asset_path(\
file_path: String, file_name: String, extension: String
) -> Array:
	var fp := file_path
	var fn := file_name
	var ex := extension
#	Podría incluirse una verficicación del dispositivo donde se está ejecutando
#	el juego para así cambiar el nombre (¿o ruta?) del asset y que de esa forma
#	se use uno específico para ese dispositivo. Ejemplo:
	if extension == 'png' and OS.has_feature('mobile'):
#		fn += '_sm'
		fp += '/mobile'
	return [fp, fn, ex]


# Retorna la textura de un nodo que no haga parte de las validaciones que ya
# vienen por defecto en DWLNodeTypes.gd.
static func get_node_texture(node: Node) -> Texture:
	return null


# Retorna el stream de un nodo que no haga parte de las validaciones que ya
# vienen por defecto en DWLNodeTypes.gd.
static func get_node_stream(node: Node) -> AudioStream:
	return null
