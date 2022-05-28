tool
class_name DWLResources

const RESOURCES_DIR: String = 'res://dwl'
const DWL_SINGLETON := 'res://addons/dwl/Singletons/DynamicWebLoader.tscn'
const WORKING_DIR := 'user://dwl/assets/'


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos públicos ░░░░
static func init_files() -> void:
	var directory := Directory.new()
	if not directory.dir_exists(RESOURCES_DIR):
		directory.make_dir_recursive(RESOURCES_DIR)
		directory.copy(
			'res://addons/dwl/Config/dwl_config.tres',
			str(RESOURCES_DIR, '/dwl_config.tres')
		)


static func get_settings() -> Resource:
	return load(RESOURCES_DIR + '/dwl_config.tres')


static func get_scan_path() -> String:
	return get_settings().scan_folder


static func get_json_path() -> String:
	var settings := get_settings()
	return '%s/%s.json' % [settings.json_folder, settings.json_name]


static func get_json_url() -> String:
	var settings := get_settings()
	return '%s/%s.json' % [settings.json_url, settings.json_name]


static func get_assets_url() -> String:
	return get_settings().assets_url + '/%s'


static func get_customs() -> Node:
	return load(RESOURCES_DIR + '/DWLCustoms.gd').new()
