extends RefCounted
class_name AIClient

var http_request: HTTPRequest
var current_model: String = ""
var api_keys: Dictionary = {}

func _init():
	# Load API keys from environment or config file
	_load_api_keys()

func _load_api_keys():
	# In Godot, we'll need to load these from a config file or project settings
	# For now, using placeholders - in production, load from user://api_keys.cfg
	var config = ConfigFile.new()
	var config_path = "user://api_keys.cfg"
	
	print("Loading API keys from: ", config_path)
	print("Absolute path: ", ProjectSettings.globalize_path(config_path))
	
	var error = config.load(config_path)
	if error == OK:
		api_keys["openai"] = config.get_value("api_keys", "openai", "")
		api_keys["anthropic"] = config.get_value("api_keys", "anthropic", "")
		api_keys["google"] = config.get_value("api_keys", "google", "")
		print("API keys loaded successfully")
		print("Anthropic key length: ", api_keys["anthropic"].length())
		print("OpenAI key length: ", api_keys["openai"].length())
		print("Google key length: ", api_keys["google"].length())
	else:
		print("Error loading API keys config: ", error)
		print("Warning: API keys configuration not found. Please create api_keys.cfg")

func set_model(model_name: String):
	current_model = model_name

func _get_thinking_setting() -> String:
	# Load thinking setting from Ollama config
	var config_path = "user://ollama_config.json"
	
	if not FileAccess.file_exists(config_path):
		print("No Ollama config file found, using default 'nothink'")
		return "nothink"
		
	var file = FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		print("Failed to open Ollama config file, using default 'nothink'")
		return "nothink"
		
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("Error parsing Ollama config for thinking setting, using default 'nothink'")
		return "nothink"
		
	var config = json.data
	if config.has("thinking"):
		print("Loaded thinking setting from config: ", config.thinking)
		return config.thinking
	else:
		print("No thinking setting in config, using default 'nothink'")
		return "nothink"

func _remove_thinking_tokens(text: String) -> String:
	# Remove <think>...</think> blocks and clean up the result
	var result = text
	
	print("Original text length: ", text.length())
	print("Original text preview: ", text.substr(0, 100).replace("\n", "\\n"))
	
	# Find and remove thinking tokens manually to handle multiline content
	var start_tag = "<think>"
	var end_tag = "</think>"
	
	while true:
		var start_pos = result.find(start_tag)
		if start_pos == -1:
			break
		
		var end_pos = result.find(end_tag, start_pos)
		if end_pos == -1:
			# If we find start but no end, remove from start to end of string
			result = result.substr(0, start_pos)
			break
		
		# Remove the entire thinking block including tags
		var before = result.substr(0, start_pos)
		var after = result.substr(end_pos + end_tag.length())
		result = before + after
		
		print("Found thinking block from ", start_pos, " to ", end_pos + end_tag.length())
	
	# Clean up extra whitespace and newlines
	result = result.strip_edges()
	
	print("Cleaned thinking tokens. Original length: ", text.length(), " New length: ", result.length())
	print("Final result preview: ", result.substr(0, 100).replace("\n", "\\n"))
	return result

func generate_title(text: String) -> String:
	# Build prompt
	var prompt = "<tweet>\n%s\n</tweet>\n\n" % text
	prompt += "上記のツイート内容を要約して、５０字以内の見出しを作成してください。以下、３つの条件に適合するよう作成をお願いします。\n"
	prompt += "* 日本語で出力してください。内容が英語であっても日本語に翻訳して出力するようにしてください。\n"
	prompt += "* 見出しの中に改行を含めないように注意してください。\n"
	prompt += "* 回答は、見出しのみを出力し、それ以外の説明等は出力しないようにしてください。\n\n"
	
	# Add thinking token prefix for qwen3: models based on settings
	if current_model.begins_with("ollama-") and current_model.replace("ollama-", "").begins_with("qwen3:"):
		var thinking_setting = _get_thinking_setting()
		prompt = thinking_setting + " " + prompt
		print("Added '", thinking_setting, " ' prefix for qwen3 model: ", current_model)
	
	# Make API call based on model
	match current_model:
		"openai-gpt-4.1-mini":
			return await _call_openai_api(prompt)
		"anthropic-sonnet-4":
			return await _call_anthropic_api(prompt)
		"google-gemini-2.5-flash":
			return await _call_google_api(prompt)
		"ollama-未設定":
			print("Error: Ollama is not configured")
			return text
		_:
			if current_model.begins_with("ollama-"):
				var model_name = current_model.replace("ollama-", "")
				print("Using Ollama model: ", model_name)
				return await _call_ollama_api(prompt, model_name)
			else:
				print("Error: Unsupported model: ", current_model)
				return text

func _call_openai_api(prompt: String) -> String:
	if api_keys.get("openai", "") == "":
		print("Error: OpenAI API key not configured")
		return ""
		
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % api_keys["openai"]
	]
	
	var body = {
		"model": "gpt-4o-mini",
		"messages": [{"role": "user", "content": prompt}],
		"max_tokens": 200,
		"temperature": 0.7
	}
	
	var response = await _make_http_request(
		"https://api.openai.com/v1/chat/completions",
		headers,
		JSON.stringify(body)
	)
	
	if response.has("choices") and response.choices.size() > 0:
		var content = response.choices[0].message.content.strip_edges()
		return _remove_thinking_tokens(content)
	
	return ""

func _call_anthropic_api(prompt: String) -> String:
	if api_keys.get("anthropic", "") == "":
		print("Error: Anthropic API key not configured")
		return ""
		
	var headers = [
		"Content-Type: application/json",
		"x-api-key: %s" % api_keys["anthropic"],
		"anthropic-version: 2023-06-01"
	]
	
	var body = {
		"model": "claude-sonnet-4-20250514",
		"messages": [{"role": "user", "content": prompt}],
		"max_tokens": 60,
		"temperature": 0.7
	}
	
	var response = await _make_http_request(
		"https://api.anthropic.com/v1/messages",
		headers,
		JSON.stringify(body)
	)
	
	if response.has("content") and response.content.size() > 0:
		var content = response.content[0].text.strip_edges()
		return _remove_thinking_tokens(content)
	
	return ""

func _call_google_api(prompt: String) -> String:
	if api_keys.get("google", "") == "":
		print("Error: Google API key not configured")
		return ""
		
	# Google Gemini API implementation
	# Note: This is a simplified version - actual implementation may vary
	var headers = [
		"Content-Type: application/json"
	]
	
	var url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=%s" % api_keys["google"]
	
	var body = {
		"contents": [{
			"parts": [{
				"text": prompt
			}]
		}],
		"generationConfig": {
			"maxOutputTokens": 200,
			"temperature": 0.6
		}
	}
	
	var response = await _make_http_request(url, headers, JSON.stringify(body))
	
	if response.has("candidates") and response.candidates.size() > 0:
		if response.candidates[0].has("content") and response.candidates[0].content.has("parts"):
			var content = response.candidates[0].content.parts[0].text.strip_edges()
			return _remove_thinking_tokens(content)
	
	return ""

func _call_ollama_api(prompt: String, model_name: String = "qwq:32b") -> String:
	# Load Ollama settings
	var ollama_url = "http://localhost:11434"
	var config_path = "user://ollama_config.json"
	
	if FileAccess.file_exists(config_path):
		var file = FileAccess.open(config_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			
			if parse_result == OK and json.data.has("url"):
				ollama_url = json.data.url
	
	var headers = [
		"Content-Type: application/json"
	]
	
	var body = {
		"model": model_name,
		"prompt": prompt,
		"stream": false
	}
	
	var response = await _make_http_request(
		ollama_url + "/api/generate",
		headers,
		JSON.stringify(body)
	)
	
	if response.has("response"):
		var content = response.response.strip_edges()
		return _remove_thinking_tokens(content)
	
	return ""

func _make_http_request(url: String, headers: Array, body: String) -> Dictionary:
	# Create HTTP request node
	http_request = HTTPRequest.new()
	var tree = Engine.get_main_loop() as SceneTree
	if not tree or not tree.root:
		print("Error: Cannot access scene tree")
		return {}
	
	# Add to scene tree first
	tree.root.add_child(http_request)
	
	# Configure HTTP request
	http_request.timeout = 30.0
	
	# Wait a frame to ensure the node is ready
	await tree.process_frame
	
	# Make request
	print("Making HTTP request to: ", url)
	var error = http_request.request(url, PackedStringArray(headers), HTTPClient.METHOD_POST, body)
	if error != OK:
		print("HTTP Request failed with error code: ", error)
		print("Error details: ", error_string(error))
		http_request.queue_free()
		return {}
	
	# Wait for response
	var result = await http_request.request_completed
	
	print("HTTP Response code: ", result[1])
	
	# Clean up
	http_request.queue_free()
	
	if result[1] != 200:
		print("HTTP Error: ", result[1])
		print("Response body: ", result[3].get_string_from_utf8())
		return {}
	
	# Parse JSON response
	var response_text = result[3].get_string_from_utf8()
	var json = JSON.new()
	var parse_result = json.parse(response_text)
	
	if parse_result != OK:
		print("JSON Parse Error: ", json.get_error_message())
		print("Response text: ", response_text)
		return {}
	
	return json.data
