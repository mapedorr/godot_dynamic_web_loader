tool
extends EditorExportPlugin

var efs: EditorFileSystem


func _export_begin(\
features: PoolStringArray, is_debug: bool, path: String, flags: int) -> void:
	var fa := Array(features)
	if not fa.has('web') and not fa.has('dwl'):
		return
	
	_check_json(true)


func _export_end() -> void:
	_check_json()


func _check_json(is_begin := false) -> void:
	var file: File = File.new()
	
	var src := '' if is_begin else '.dwl'
	var tar := '.dwl' if is_begin else ''
	
	if file.open(DWLResources.get_json_path(), File.READ) != OK: return
	
	var content = file.get_as_text()
	file.close()
	
	var json: Dictionary = JSON.parse(content).result
	
	for g in ['images', 'audios']:
		_rename_files(json, g, src, tar)


func _rename_files(\
dic: Dictionary, group: String, src: String, tar: String) -> void:
	var directory: Directory = Directory.new()
	
	for scene in dic[group]:
		for f in dic[group][scene]:
			if not f.has('path'): continue
			
			if directory.file_exists('res://' + f.path + src):
				var err := directory.rename(
					'res://' + f.path + src,
					'res://' + f.path + tar
				)
