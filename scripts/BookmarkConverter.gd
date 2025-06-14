extends RefCounted
class_name BookmarkConverter

var file_manager: FileManager

func _init():
	file_manager = FileManager.new()

func convert_bookmark_json_to_markdown(yyyymmdd: String, nn: String, model: String, oembed: bool, file_path: String, base_dict_file: String) -> String:
	print("Converting bookmark JSON to intermediate format...")
	print("yyyymmdd: ", yyyymmdd)
	print("nn: ", nn)
	print("model: ", model)
	print("oembed: ", oembed)
	print("file_path: ", file_path)
	
	var output2_file = "user://out/output2/output_%s%s.json" % [yyyymmdd, nn]
	print("output2_file: ", output2_file)
	
	# Ensure output directory exists
	file_manager.ensure_directory_exists("user://out/output2/")
	
	# Load tweet URL dictionary
	var tweet_url_dict = file_manager.load_json(base_dict_file)
	if tweet_url_dict.is_empty():
		tweet_url_dict = {}
		file_manager.ensure_directory_exists("user://out/")
		file_manager.save_json(base_dict_file, tweet_url_dict)
	
	# Load bookmarks JSON
	var bookmarks = file_manager.load_json(file_path)
	if typeof(bookmarks) != TYPE_ARRAY:
		print("Error: bookmarks file is not an array")
		return ""
	
	# Calculate time range (16 days ago)
	var current_time = Time.get_unix_time_from_system()
	var past_time = current_time - (16 * 24 * 60 * 60)  # 16 days in seconds
	
	# Process bookmarks
	var output_data = []
	
	for bookmark in bookmarks:
		if not bookmark is Dictionary:
			continue
			
		# Parse tweeted_at timestamp
		var tweeted_at = bookmark.get("tweeted_at", "")
		if tweeted_at == "":
			continue
			
		var tweet_time = _parse_iso_timestamp(tweeted_at)
		
		# Check if tweet is within the time range
		if tweet_time > past_time:
			# Create output bookmark without excluded fields
			var output_bookmark = {}
			for key in bookmark:
				if key not in ["profile_image_url_https", "extended_media"]:
					output_bookmark[key] = bookmark[key]
			
			# Check if tweet URL is not already processed
			var tweet_url = output_bookmark.get("tweet_url", "")
			if tweet_url != "" and not tweet_url_dict.has(tweet_url):
				output_data.append(output_bookmark)
	
	# Sort by tweeted_at in descending order
	output_data.sort_custom(_sort_by_tweet_time)
	
	# Save output data
	file_manager.save_json(output2_file, output_data)
	
	print("Data processing completed.")
	return output2_file

func _parse_iso_timestamp(timestamp: String) -> float:
	# Parse ISO timestamp format: "2024-05-21T10:30:00.000Z"
	# This is a simplified parser
	var parts = timestamp.split("T")
	if parts.size() < 2:
		return 0.0
		
	var date_parts = parts[0].split("-")
	var time_parts = parts[1].rstrip("Z").split(":")
	
	if date_parts.size() < 3 or time_parts.size() < 3:
		return 0.0
		
	var datetime = {
		"year": int(date_parts[0]),
		"month": int(date_parts[1]),
		"day": int(date_parts[2]),
		"hour": int(time_parts[0]),
		"minute": int(time_parts[1]),
		"second": int(float(time_parts[2]))
	}
	
	return Time.get_unix_time_from_datetime_dict(datetime)

func _sort_by_tweet_time(a: Dictionary, b: Dictionary) -> bool:
	var time_a = _parse_iso_timestamp(a.get("tweeted_at", ""))
	var time_b = _parse_iso_timestamp(b.get("tweeted_at", ""))
	return time_a > time_b  # Descending order

func convert_tweets_to_markdown(input_file: String, output_file: String, use_oembed: bool, model_name: String, ai_client: AIClient):
	print("Converting tweets to markdown...")
	
	# Ensure output directory exists
	file_manager.ensure_directory_exists("user://out/markdown/")
	
	# Load tweets
	var tweets = file_manager.load_json(input_file)
	if typeof(tweets) != TYPE_ARRAY:
		print("Error: input file is not an array")
		return
	
	# Open output file
	var file = FileAccess.open(output_file, FileAccess.WRITE)
	if file == null:
		print("Error: Cannot create output file")
		return
	
	# Process each tweet
	for tweet in tweets:
		if not tweet is Dictionary:
			continue
			
		var full_text = tweet.get("full_text", "")
		var tweeted_at = tweet.get("tweeted_at", "")
		var screen_name = tweet.get("screen_name", "").rstrip(" _")
		var tweet_url = tweet.get("tweet_url", "").replace("https://x.com", "https://twitter.com")
		
		print("Processing: ", tweet_url)
		
		# Generate title
		var title = full_text
		if model_name != "":
			var generated_title = await ai_client.generate_title(full_text)
			if generated_title != "":
				title = generated_title
			else:
				print("Failed to generate title, using original text")
		
		# Write to markdown
		file.store_line("## " + title)
		file.store_line("%s %s" % [tweeted_at, screen_name])
		
		# Write URL
		if use_oembed:
			file.store_line("[oembed %s]" % tweet_url)
		else:
			file.store_line(tweet_url)
		
		file.store_line("")  # Empty line
	
	file.close()
	print("Markdown conversion completed.")

func update_tweet_url_dict(base_dict_file: String, input_file: String):
	print("Updating tweet URL dictionary...")
	
	# Load input tweets
	var tweets = file_manager.load_json(input_file)
	if typeof(tweets) != TYPE_ARRAY:
		return
		
	# Load existing dictionary
	var tweets_dict = file_manager.load_json(base_dict_file)
	if tweets_dict.is_empty():
		tweets_dict = {}
	
	# Add new URLs to dictionary
	for tweet in tweets:
		if not tweet is Dictionary:
			continue
		var tweet_url = tweet.get("tweet_url", "")
		if tweet_url != "":
			tweets_dict[tweet_url] = true
	
	# Save updated dictionary
	file_manager.save_json(base_dict_file, tweets_dict)
	print("Tweet URL dictionary updated.")
