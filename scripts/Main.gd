extends Control

# UI elements
@onready var drop_area = $VBoxContainer/DropArea
@onready var filename_label = $VBoxContainer/FilenameLabel
@onready var model_select = $VBoxContainer/FormContainer/ModelSelect
@onready var oembed_select = $VBoxContainer/FormContainer/OembedSelect
@onready var convert_button = $VBoxContainer/FormContainer/ConvertButton
@onready var status_label = $VBoxContainer/StatusLabel
@onready var user_dir_label = $VBoxContainer/UserDirLabel
@onready var open_folder_button = $VBoxContainer/ButtonsContainer/OpenFolderButton
@onready var settings_button = $VBoxContainer/ButtonsContainer/SettingsButton

# Data
var file_manager: FileManager
var ai_client: AIClient
var converter: BookmarkConverter

var current_file_data: Dictionary = {}
var uploaded_content: String = ""
var ollama_settings_scene = preload("res://scenes/OllamaSettings.tscn")
var ollama_settings_window: Window = null
var ollama_url: String = "http://localhost:11434"
var ollama_model: String = ""
var ollama_thinking: String = "nothink"

func _ready():
	# Initialize components
	file_manager = FileManager.new()
	ai_client = AIClient.new()
	converter = BookmarkConverter.new()
	
	# Set up UI
	filename_label.hide()
	convert_button.disabled = true
	
	# Set background color
	var background = ColorRect.new()
	background.color = Color(0.15, 0.15, 0.15, 1)  # Dark gray background
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	move_child(background, 0)  # Move to back
	
	# Style the UI elements
	_style_drop_area()
	_style_buttons()
	_style_option_buttons()
	
	# Show user directory
	var user_dir = OS.get_user_data_dir()
	user_dir_label.text = "出力先: " + user_dir
	user_dir_label.show()
	
	# Check for API keys configuration
	await _check_api_keys_config()
	
	# Load Ollama settings first, then populate dropdown
	await _load_ollama_settings()
	_populate_model_select()
	
	# Connect signals
	convert_button.pressed.connect(_on_convert_button_pressed)
	open_folder_button.pressed.connect(_on_open_folder_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	
	# Enable file dropping
	get_window().files_dropped.connect(_on_files_dropped)
	
	# Populate dropdowns
	_populate_oembed_select()

func _populate_model_select():
	print("_populate_model_select called - ollama_model: '", ollama_model, "' ollama_url: '", ollama_url, "'")
	
	model_select.clear()
	model_select.add_item("anthropic-sonnet-4")
	model_select.add_item("google-gemini-2.5-flash")
	model_select.add_item("openai-gpt-4.1-mini")
	
	if ollama_model != "":
		model_select.add_item("ollama-" + ollama_model)
		print("Added Ollama model to dropdown: ollama-" + ollama_model)
	else:
		model_select.add_item("ollama-未設定")
		print("Added placeholder Ollama option")
	
	model_select.selected = 0
	print("Final dropdown items count: ", model_select.get_item_count())

func _populate_oembed_select():
	oembed_select.add_item("oembed あり")
	oembed_select.add_item("oembed なし")
	oembed_select.selected = 0

func _on_files_dropped(files: PackedStringArray):
	if files.size() == 0:
		return
		
	var file_path = files[0]
	
	# Check if it's a JSON file
	if not file_path.ends_with(".json"):
		status_label.text = "エラー: JSONファイルをドロップしてください"
		status_label.modulate = Color(1, 0.3, 0.3, 1)  # Red color for error
		return
	
	# Reset status color
	status_label.modulate = Color(1, 1, 1, 1)
	
	# Read the file
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		status_label.text = "エラー: ファイルを読み込めません"
		return
		
	uploaded_content = file.get_as_text()
	file.close()
	
	# Generate filename
	current_file_data = file_manager.generate_filename()
	filename_label.text = "生成されたファイル名: " + current_file_data.filename
	filename_label.show()
	
	# Save the file
	var save_path = current_file_data.file_path
	file_manager.ensure_directory_exists("user://out/bookmark/")
	
	var save_file = FileAccess.open(save_path, FileAccess.WRITE)
	if save_file != null:
		save_file.store_string(uploaded_content)
		save_file.close()
		convert_button.disabled = false
		status_label.text = "ファイルがアップロードされました"
	else:
		status_label.text = "エラー: ファイルの保存に失敗しました"

func _on_convert_button_pressed():
	if current_file_data.is_empty():
		return
		
	convert_button.disabled = true
	status_label.text = "変換処理中..."
	
	# Get selected options
	var model_index = model_select.selected
	var selected_model = model_select.get_item_text(model_index)
	
	print("Convert button pressed - selected model: ", selected_model, " at index: ", model_index)
	
	# Check if Ollama is selected but not configured
	if selected_model == "ollama-未設定":
		status_label.text = "エラー: Ollamaが設定されていません。設定ボタンから設定してください。"
		status_label.modulate = Color(1, 0.3, 0.3, 1)  # Red
		convert_button.disabled = false
		return
	
	var use_oembed = oembed_select.selected == 0
	
	# Set up converter parameters
	var params = {
		"yyyymmdd": current_file_data.yyyymmdd,
		"nn": current_file_data.nn,
		"model": selected_model,
		"oembed": use_oembed,
		"file_path": current_file_data.file_path,
		"base_dict_file": "user://out/tweet_url_dict.json"
	}
	
	# Start conversion without thread for now (HTTP requests need main thread)
	await _convert_async(params)

func _convert_async(params: Dictionary):
	# Initialize AI client with selected model
	ai_client.set_model(params.model)
	
	# Convert bookmark JSON to intermediate format
	var output2_file = converter.convert_bookmark_json_to_markdown(
		params.yyyymmdd,
		params.nn,
		params.model,
		params.oembed,
		params.file_path,
		params.base_dict_file
	)
	
	# Convert to markdown
	var markdown_file = "user://out/markdown/twitter_summary_%s%s.md" % [params.yyyymmdd, params.nn]
	await converter.convert_tweets_to_markdown(output2_file, markdown_file, params.oembed, params.model, ai_client)
	
	# Update tweet URL dictionary
	converter.update_tweet_url_dict(params.base_dict_file, output2_file)
	
	# Update UI
	_conversion_complete()

func _conversion_complete():
	convert_button.disabled = false
	status_label.text = "変換が完了しました"

func _on_open_folder_button_pressed():
	# ユーザーディレクトリを開く
	var user_dir = OS.get_user_data_dir()
	OS.shell_open(user_dir)

func _style_drop_area():
	# Add visual styling to the drop area
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.2, 0.2, 1)
	style_box.border_color = Color(0.4, 0.4, 0.4, 1)
	style_box.set_border_width_all(2)
	style_box.set_corner_radius_all(8)
	drop_area.add_theme_stylebox_override("panel", style_box)

func _style_buttons():
	# Style for convert button
	var convert_style = StyleBoxFlat.new()
	convert_style.bg_color = Color(0.2, 0.35, 0.5, 1)  # Dark blue
	convert_style.set_corner_radius_all(12)
	convert_style.set_expand_margin_all(4)
	convert_button.add_theme_stylebox_override("normal", convert_style)
	
	var convert_hover = convert_style.duplicate()
	convert_hover.bg_color = Color(0.25, 0.4, 0.6, 1)  # Lighter blue on hover
	convert_button.add_theme_stylebox_override("hover", convert_hover)
	
	var convert_pressed = convert_style.duplicate()
	convert_pressed.bg_color = Color(0.15, 0.3, 0.45, 1)  # Darker blue when pressed
	convert_button.add_theme_stylebox_override("pressed", convert_pressed)
	
	var convert_disabled = convert_style.duplicate()
	convert_disabled.bg_color = Color(0.2, 0.2, 0.2, 0.5)  # Gray when disabled
	convert_button.add_theme_stylebox_override("disabled", convert_disabled)
	
	# Style for open folder button
	var folder_style = StyleBoxFlat.new()
	folder_style.bg_color = Color(0.25, 0.4, 0.25, 1)  # Dark green
	folder_style.set_corner_radius_all(12)
	folder_style.set_expand_margin_all(4)
	open_folder_button.add_theme_stylebox_override("normal", folder_style)
	
	var folder_hover = folder_style.duplicate()
	folder_hover.bg_color = Color(0.3, 0.5, 0.3, 1)  # Lighter green on hover
	open_folder_button.add_theme_stylebox_override("hover", folder_hover)
	
	var folder_pressed = folder_style.duplicate()
	folder_pressed.bg_color = Color(0.2, 0.35, 0.2, 1)  # Darker green when pressed
	open_folder_button.add_theme_stylebox_override("pressed", folder_pressed)
	
	# Style for settings button
	var settings_style = StyleBoxFlat.new()
	settings_style.bg_color = Color(0.4, 0.25, 0.4, 1)  # Dark purple
	settings_style.set_corner_radius_all(12)
	settings_style.set_expand_margin_all(4)
	settings_button.add_theme_stylebox_override("normal", settings_style)
	
	var settings_hover = settings_style.duplicate()
	settings_hover.bg_color = Color(0.5, 0.3, 0.5, 1)  # Lighter purple on hover
	settings_button.add_theme_stylebox_override("hover", settings_hover)
	
	var settings_pressed = settings_style.duplicate()
	settings_pressed.bg_color = Color(0.35, 0.2, 0.35, 1)  # Darker purple when pressed
	settings_button.add_theme_stylebox_override("pressed", settings_pressed)

func _style_option_buttons():
	# Style for option buttons
	var option_style = StyleBoxFlat.new()
	option_style.bg_color = Color(0.25, 0.25, 0.35, 1)  # Dark purple
	option_style.set_corner_radius_all(8)
	option_style.set_expand_margin_all(4)
	
	var option_hover = option_style.duplicate()
	option_hover.bg_color = Color(0.3, 0.3, 0.4, 1)  # Lighter purple on hover
	
	var option_pressed = option_style.duplicate()
	option_pressed.bg_color = Color(0.2, 0.2, 0.3, 1)  # Darker purple when pressed
	
	# Apply to model select
	model_select.add_theme_stylebox_override("normal", option_style)
	model_select.add_theme_stylebox_override("hover", option_hover)
	model_select.add_theme_stylebox_override("pressed", option_pressed)
	model_select.add_theme_stylebox_override("focus", option_style)
	
	# Apply to oembed select
	oembed_select.add_theme_stylebox_override("normal", option_style)
	oembed_select.add_theme_stylebox_override("hover", option_hover)
	oembed_select.add_theme_stylebox_override("pressed", option_pressed)
	oembed_select.add_theme_stylebox_override("focus", option_style)

func _check_api_keys_config() -> void:
	var config_path = "user://api_keys.cfg"
	if not FileAccess.file_exists(config_path):
		print("API keys config not found. Creating template...")
		status_label.text = "APIキー設定ファイルを作成しています..."
		
		# Create a template config file with proper format
		var file = FileAccess.open(config_path, FileAccess.WRITE)
		if file:
			file.store_line("[api_keys]")
			file.store_line("# OpenAI API Key (for GPT-4o Mini)")
			file.store_line("openai=your-openai-key-here")
			file.store_line("")
			file.store_line("# Anthropic API Key (for Claude 3 Sonnet)")
			file.store_line("anthropic=your-anthropic-key-here")
			file.store_line("")
			file.store_line("# Google API Key (for Gemini 2.5 Flash)")
			file.store_line("google=your-google-key-here")
			file.store_line("")
			file.store_line("# Note: Do NOT use quotes around the API keys")
			file.store_line("# Correct: anthropic=sk-ant-api123456")
			file.store_line("# Wrong: anthropic=\"sk-ant-api123456\"")
			file.close()
			
			status_label.text = "APIキー設定ファイルが作成されました。設定後、アプリを再起動してください。"
			print("Created api_keys.cfg template at: ", ProjectSettings.globalize_path(config_path))
		else:
			status_label.text = "APIキー設定ファイルの作成に失敗しました。"
	
	# Load Ollama settings
	await _load_ollama_settings()

func _load_ollama_settings() -> void:
	var config_path = "user://ollama_config.json"
	print("Loading Ollama settings from: ", config_path)
	print("File exists: ", FileAccess.file_exists(config_path))
	
	if not FileAccess.file_exists(config_path):
		print("No Ollama config file found")
		return
		
	var file = FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		print("Failed to open Ollama config file")
		return
		
	var json_string = file.get_as_text()
	file.close()
	print("Config file content: ", json_string)
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("Error parsing Ollama config: ", json.get_error_message())
		return
		
	var config = json.data
	print("Parsed config: ", config)
	
	if config.has("url"):
		ollama_url = config.url
	if config.has("model"):
		ollama_model = config.model
	if config.has("thinking"):
		ollama_thinking = config.thinking
		
	print("Final Ollama settings: URL=", ollama_url, " Model=", ollama_model, " Thinking=", ollama_thinking)

func _on_settings_button_pressed():
	if ollama_settings_window != null:
		ollama_settings_window.queue_free()
	
	ollama_settings_window = ollama_settings_scene.instantiate()
	get_tree().root.add_child(ollama_settings_window)
	ollama_settings_window.settings_saved.connect(_on_ollama_settings_saved)
	ollama_settings_window.show()

func _on_ollama_settings_saved(url: String, model: String, thinking: String):
	print("_on_ollama_settings_saved called with URL: '", url, "' Model: '", model, "' Thinking: '", thinking, "'")
	
	ollama_url = url
	ollama_model = model
	ollama_thinking = thinking
	
	print("Updated internal variables - ollama_url: '", ollama_url, "' ollama_model: '", ollama_model, "' ollama_thinking: '", ollama_thinking, "'")
	
	# Update model select dropdown
	print("About to call _populate_model_select() from settings saved")
	_populate_model_select()
	
	status_label.text = "Ollama設定が保存されました: " + model + " (" + thinking + ")"
	status_label.modulate = Color(0.3, 1, 0.3, 1)  # Green
