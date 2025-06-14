extends Node

# ユーザーディレクトリの場所を表示するスクリプト

func _ready():
	print("=== Godot User Directory Information ===")
	
	# ユーザーデータディレクトリのパスを取得
	var user_dir = OS.get_user_data_dir()
	print("User Data Directory: ", user_dir)
	
	# その他の便利なディレクトリ情報
	print("Executable Path: ", OS.get_executable_path())
	print("Config Directory: ", OS.get_config_dir())
	print("Data Directory: ", OS.get_data_dir())
	print("Cache Directory: ", OS.get_cache_dir())
	
	# user:// のフルパスを取得
	var dir = DirAccess.open("user://")
	if dir:
		print("user:// Full Path: ", dir.get_current_dir())
	
	print("=======================================")
