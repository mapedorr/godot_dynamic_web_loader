extends Resource

# Propiedades que usa el plugin
export var json_name := 'dwl'
export(String, DIR) var json_folder := 'user://dwl/assets/'
export(String, DIR) var scan_folder := 'res://'

# Propiedades que usa el singleton DWL
export var assets_url := 'http://127.0.0.1:8080/assets'
export var json_url := 'http://127.0.0.1:8080/assets'
