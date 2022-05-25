extends Node


static func get_asset_name(file_name: String, extension: String) -> String:
	if extension == 'png' and OS.has_feature('mobile'):
		return file_name + '_sm'
	return file_name
