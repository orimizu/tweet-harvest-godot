extends Window

@onready var url_input = $VBoxContainer/URLContainer/URLInput
@onready var test_button = $VBoxContainer/URLContainer/TestButton
@onready var status_value = $VBoxContainer/StatusContainer/StatusValue
@onready var model_select = $VBoxContainer/ModelContainer/ModelSelect
@onready var thinking_select = $VBoxContainer/ThinkingContainer/ThinkingSelect
@onready var ok_button = $VBoxContainer/ButtonContainer/OKButton
@onready var cancel_button = $VBoxContainer/ButtonContainer/CancelButton

var http_request: HTTPRequest
var selected_model: String = ""
var selected_thinking: String = "nothink"
var config_path = "user://ollama_config.json"

signal settings_saved(url: String, model: String, thinking: String)

func _ready():
	# Set window properties (removed ALWAYS_ON_TOP to fix interaction issues)
	# set_flag(Window.FLAG_ALWAYS_ON_TOP, true)
	
	# Debug node references
	print("Node references in _ready:")
	print("  status_value: ", status_value)
	print("  model_select: ", model_select)
	print("  ok_button: ", ok_button)
	print("  test_button: ", test_button)
	
	# Initialize UI state
	model_select.clear()  # Clear any existing items first
	model_select.add_item("-- 接続してください --")
	model_select.disabled = true
	
	# Initialize thinking token control
	thinking_select.clear()
	thinking_select.add_item("nothink")
	thinking_select.add_item("think")
	thinking_select.selected = 0  # Default to nothink
	
	ok_button.disabled = true
	
	# Set initial status color
	status_value.modulate = Color(1, 0.3, 0.3, 1)  # Red for initial state
	
	print("Initial model_select setup - disabled: ", model_select.disabled, " items: ", model_select.get_item_count())
	
	# Connect signals
	test_button.pressed.connect(_on_test_button_pressed)
	ok_button.pressed.connect(_on_ok_button_pressed)
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	model_select.item_selected.connect(_on_model_selected)
	thinking_select.item_selected.connect(_on_thinking_selected)
	close_requested.connect(_on_cancel_button_pressed)
	
	# Add debug signals for OptionButton
	model_select.pressed.connect(_on_model_select_pressed)
	model_select.focus_entered.connect(_on_model_select_focus_entered)
	model_select.mouse_entered.connect(_on_model_select_mouse_entered)
	
	# Load existing settings
	_load_settings()
	
	# Style buttons
	_style_buttons()

func _style_buttons():
	# Test button style
	var test_style = StyleBoxFlat.new()
	test_style.bg_color = Color(0.3, 0.3, 0.5, 1)
	test_style.set_corner_radius_all(8)
	test_button.add_theme_stylebox_override("normal", test_style)
	
	var test_hover = test_style.duplicate()
	test_hover.bg_color = Color(0.35, 0.35, 0.6, 1)
	test_button.add_theme_stylebox_override("hover", test_hover)
	
	# OK button style
	var ok_style = StyleBoxFlat.new()
	ok_style.bg_color = Color(0.2, 0.5, 0.2, 1)
	ok_style.set_corner_radius_all(8)
	ok_button.add_theme_stylebox_override("normal", ok_style)
	
	var ok_hover = ok_style.duplicate()
	ok_hover.bg_color = Color(0.25, 0.6, 0.25, 1)
	ok_button.add_theme_stylebox_override("hover", ok_hover)
	
	var ok_disabled = ok_style.duplicate()
	ok_disabled.bg_color = Color(0.2, 0.2, 0.2, 0.5)
	ok_button.add_theme_stylebox_override("disabled", ok_disabled)
	
	# Cancel button style
	var cancel_style = StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.5, 0.2, 0.2, 1)
	cancel_style.set_corner_radius_all(8)
	cancel_button.add_theme_stylebox_override("normal", cancel_style)
	
	var cancel_hover = cancel_style.duplicate()
	cancel_hover.bg_color = Color(0.6, 0.25, 0.25, 1)
	cancel_button.add_theme_stylebox_override("hover", cancel_hover)

func _load_settings():
	if not FileAccess.file_exists(config_path):
		return
		
	var file = FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		return
		
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("Error parsing Ollama config: ", json.get_error_message())
		return
		
	var config = json.data
	if config.has("url"):
		url_input.text = config.url
	if config.has("model"):
		selected_model = config.model
		print("Loaded saved model: ", selected_model)
	if config.has("thinking"):
		selected_thinking = config.thinking
		# Set thinking select to match loaded setting
		if selected_thinking == "think":
			thinking_select.selected = 1
		else:
			thinking_select.selected = 0
		print("Loaded saved thinking setting: ", selected_thinking)
	
	# Try to connect and populate models
	await get_tree().process_frame  # Wait for UI to be ready
	_on_test_button_pressed()

func _save_settings():
	var config = {
		"url": url_input.text,
		"model": selected_model,
		"thinking": selected_thinking
	}
	
	var file = FileAccess.open(config_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(config, "\t"))
		file.close()
		print("Ollama settings saved")

func _on_test_button_pressed():
	print("Test button pressed")
	status_value.text = "接続中..."
	status_value.modulate = Color(1, 1, 0, 1)  # Yellow
	
	# Create HTTP request
	if http_request:
		http_request.queue_free()
		http_request = null
	
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.timeout = 10.0
	
	# Wait for node to be ready
	await get_tree().process_frame
	
	# Test connection by getting model list
	var url = url_input.text.strip_edges() + "/api/tags"
	print("Requesting URL: ", url)
	
	# Connect signal before making request
	if not http_request.request_completed.is_connected(_on_test_response):
		http_request.request_completed.connect(_on_test_response)
	
	var error = http_request.request(url, [], HTTPClient.METHOD_GET)
	
	if error != OK:
		_on_connection_failed("リクエストエラー: " + str(error))
		return
	
	print("Request sent successfully")

func _on_test_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	print("Response received - result: ", result, " code: ", response_code)
	
	if http_request:
		http_request.queue_free()
		http_request = null
	
	print("HTTP Response code: ", response_code)
	print("Response body: ", body.get_string_from_utf8())
	
	if response_code != 200:
		call_deferred("_update_ui_failed", "HTTPエラー: " + str(response_code))
		return
	
	# Parse response
	var json = JSON.new()
	var response_text = body.get_string_from_utf8()
	var parse_result = json.parse(response_text)
	
	if parse_result != OK:
		call_deferred("_update_ui_failed", "JSONパースエラー: " + json.get_error_message())
		return
		
	var data = json.data
	print("Parsed data: ", data)
	
	if not data.has("models") or data.models.size() == 0:
		call_deferred("_update_ui_failed", "モデルが見つかりません")
		return
	
	# Connection successful - use call_deferred to ensure UI updates
	print("Connection successful! Models found: ", data.models.size())
	call_deferred("_update_ui_success", data.models)

func _update_ui_success(models: Array):
	print("Updating UI with models: ", models)
	print("Window visible: ", visible)
	print("Window is inside tree: ", is_inside_tree())
	print("Status value node: ", status_value)
	print("Model select node: ", model_select)
	print("OK button node: ", ok_button)
	
	# Check if window is still valid
	if not is_inside_tree() or not visible:
		print("ERROR: Window is not visible or not in tree!")
		return
	
	# Check if nodes are valid
	if not status_value or not model_select or not ok_button:
		print("ERROR: UI nodes are not properly initialized!")
		return
	
	# Verify nodes are still in tree
	if not status_value.is_inside_tree() or not model_select.is_inside_tree() or not ok_button.is_inside_tree():
		print("ERROR: UI nodes are not inside tree!")
		return
	
	# Update status - now that theme override is removed, modulate should work
	status_value.text = "接続OK"
	status_value.modulate = Color(0.3, 1, 0.3, 1)  # Green
	print("Status updated to: ", status_value.text, " with color: ", status_value.modulate)
	
	# Clear and populate model dropdown
	print("Current model_select item count before clear: ", model_select.get_item_count())
	print("Model select disabled state before: ", model_select.disabled)
	
	model_select.clear()
	model_select.disabled = false
	print("Model select cleared and enabled")
	print("Model select disabled state after enable: ", model_select.disabled)
	
	# Add default option
	model_select.add_item("-- モデルを選択してください --")
	print("Added default option, count now: ", model_select.get_item_count())
	
	# Add models
	for model_info in models:
		var model_name = model_info.name
		model_select.add_item(model_name)
		print("Added model to dropdown: ", model_name, " count now: ", model_select.get_item_count())
	
	# Explicitly ensure it's enabled and clickable
	model_select.disabled = false
	model_select.focus_mode = Control.FOCUS_ALL
	
	# Try to force refresh the OptionButton
	model_select.reset_size()
	model_select.queue_redraw()
	
	# Make sure the OptionButton is visible and on top
	model_select.show()
	model_select.move_to_front()
	
	print("Final disabled state: ", model_select.disabled)
	print("Final focus mode: ", model_select.focus_mode)
	print("OptionButton visible: ", model_select.visible)
	print("OptionButton size: ", model_select.size)
	
	print("Final items in dropdown: ", model_select.get_item_count())
	for i in range(model_select.get_item_count()):
		print("  Item ", i, ": ", model_select.get_item_text(i))
	
	# Select previously selected model if exists
	if selected_model != "":
		print("Looking for previously selected model: ", selected_model)
		for i in range(1, model_select.get_item_count()):  # Start from 1 to skip default option
			if model_select.get_item_text(i) == selected_model:
				model_select.selected = i
				ok_button.disabled = false
				print("Found and selected previous model at index: ", i)
				break
	else:
		model_select.selected = 0  # Select default option
		ok_button.disabled = true
		print("No previous model, using default selection")
	
	print("Final selected index: ", model_select.selected)
	print("OK button disabled: ", ok_button.disabled)

func _on_connection_failed(error_msg: String):
	call_deferred("_update_ui_failed", error_msg)

func _update_ui_failed(error_msg: String):
	status_value.text = "接続失敗"
	status_value.modulate = Color(1, 0.3, 0.3, 1)  # Red
	print("Ollama connection failed: ", error_msg)
	
	model_select.clear()
	model_select.add_item("-- 接続してください --")
	model_select.disabled = true
	model_select.selected = 0
	ok_button.disabled = true
	selected_model = ""

func _on_model_selected(index: int):
	print("Model selection changed to index: ", index)
	print("Available items: ", model_select.get_item_count())
	
	if index == 0:  # Default option selected
		selected_model = ""
		ok_button.disabled = true
		print("Default option selected, OK button disabled")
	else:
		selected_model = model_select.get_item_text(index)
		ok_button.disabled = false
		print("Model selected: ", selected_model, " OK button enabled")

func _on_thinking_selected(index: int):
	if index == 0:
		selected_thinking = "nothink"
	else:
		selected_thinking = "think"
	print("Thinking token setting changed to: ", selected_thinking)

func _on_ok_button_pressed():
	_save_settings()
	settings_saved.emit(url_input.text, selected_model, selected_thinking)
	hide()

func _on_cancel_button_pressed():
	hide()

# Debug functions for OptionButton
func _on_model_select_pressed():
	print("OptionButton pressed!")
	print("Current disabled state: ", model_select.disabled)
	print("Current item count: ", model_select.get_item_count())

func _on_model_select_focus_entered():
	print("OptionButton focus entered")

func _on_model_select_mouse_entered():
	print("OptionButton mouse entered")

func _recreate_option_button_if_needed():
	print("Attempting to recreate OptionButton...")
	
	var parent = model_select.get_parent()
	var position_in_parent = model_select.get_index()
	
	# Store current settings
	var current_items = []
	for i in range(model_select.get_item_count()):
		current_items.append(model_select.get_item_text(i))
	var current_selected = model_select.selected
	
	# Remove old OptionButton
	model_select.queue_free()
	
	# Create new OptionButton
	var new_option_button = OptionButton.new()
	new_option_button.name = "ModelSelect"
	new_option_button.custom_minimum_size = Vector2(0, 40)
	new_option_button.add_theme_font_size_override("font_size", 20)
	
	# Add to parent at same position
	parent.add_child(new_option_button)
	parent.move_child(new_option_button, position_in_parent)
	
	# Update reference
	model_select = new_option_button
	
	# Restore items
	for item in current_items:
		model_select.add_item(item)
	model_select.selected = current_selected
	
	# Connect signals
	model_select.item_selected.connect(_on_model_selected)
	model_select.pressed.connect(_on_model_select_pressed)
	model_select.focus_entered.connect(_on_model_select_focus_entered)
	model_select.mouse_entered.connect(_on_model_select_mouse_entered)
	
	print("OptionButton recreated successfully")