extends RefCounted
class_name FileManager

func generate_filename() -> Dictionary:
	# Get current date in yyyymmdd format
	var datetime = Time.get_datetime_dict_from_system()
	var yyyymmdd = "%04d%02d%02d" % [datetime.year, datetime.month, datetime.day]
	
	# Create base filename
	var base_filename = "bookmark_%s" % yyyymmdd
	var filename = "%s.json" % base_filename
	var file_path = "user://out/bookmark/%s" % filename
	
	var nn = ""
	
	# Check if file already exists and add number if needed
	if FileAccess.file_exists(file_path):
		var count = 1
		while true:
			nn = "_%02d" % count
			filename = "%s%s.json" % [base_filename, nn]
			file_path = "user://out/bookmark/%s" % filename
			if not FileAccess.file_exists(file_path):
				break
			count += 1
	
	return {
		"filename": filename,
		"file_path": file_path,
		"yyyymmdd": yyyymmdd,
		"nn": nn
	}

func ensure_directory_exists(path: String) -> void:
	var dir = DirAccess.open("user://")
	if dir:
		dir.make_dir_recursive(path)

func save_json(path: String, data: Variant) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
		
	var json_string = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()
	return true

func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return {}
		
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
		
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("Error parsing JSON: ", json.get_error_message())
		return {}
		
	return json.data
