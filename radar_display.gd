extends Node2D

# Track the current video filename so we can delete it later
var current_ogv_filename = ""

# Called when the node enters the scene tree for the first time.
func _ready():
	print_debug($VideoStreamPlayer.stream)
	print_debug($VideoStreamPlayer)
	# Clean up any existing .ogv files on startup
	_cleanup_old_ogv_files()
	update_radar()

func _on_button_pressed():
	$CanvasLayer.hide()


func _on_open_button_pressed():
	$CanvasLayer.show()

func update_radar():
	# Download the latest radar image using async HTTPRequest
	print_debug("Downloading radar image...")
	var url = "https://radar.weather.gov/ridge/standard/KOKX_loop.gif"

	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_radar_download_completed.bind(http_request))

	var err = http_request.request(url)
	if err != OK:
		push_error("Failed to start radar download request")
		http_request.queue_free()
		$Timer.start(300)  # Try again later

func _on_radar_download_completed(result, response_code, _headers, body, http_request):
	print_debug("Radar download completed")

	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Radar download failed: " + str(result) + " " + str(response_code))
		http_request.queue_free()
		$Timer.start(300)  # Try again later
		return

	# Save the downloaded GIF to file
	var file = FileAccess.open("user://KOKX_loop.gif", FileAccess.WRITE)
	if file == null:
		push_error("Failed to open file for writing")
		http_request.queue_free()
		$Timer.start(300)
		return

	file.store_buffer(body)
	file.close()
	print_debug("GIF saved to user://KOKX_loop.gif")

	# Delete the previous .ogv file if it exists
	if current_ogv_filename != "":
		var old_file_path = "user://" + current_ogv_filename
		var delete_err = DirAccess.remove_absolute(old_file_path)
		if delete_err == OK:
			print_debug("Deleted previous file: " + current_ogv_filename)
		else:
			push_error("Failed to delete previous file: " + current_ogv_filename)

	# Convert GIF to OGV using ffmpeg (non-blocking)
	print_debug("Running ffmpeg...")
	var output_filename = "tmp_KOKX_loop_" + Time.get_datetime_string_from_system(true) + ".ogv"
	output_filename = output_filename.replace(":", "")
	output_filename = output_filename.replace("-", "")
	print_debug("Output filename: " + output_filename)

	# Store the new filename for cleanup next time
	current_ogv_filename = output_filename

	var input_path = ProjectSettings.globalize_path("user://KOKX_loop.gif")
	var output_path = ProjectSettings.globalize_path("user://") + output_filename

	# Run ffmpeg without blocking (wait = false)
	var err = OS.execute("ffmpeg", ["-i", input_path, "-q:v", "10", "-codec:v", "libtheora", "-y", output_path], [], false)
	print_debug("ffmpeg started with code: " + str(err))

	# Give ffmpeg a moment to process, then load the video
	# Note: This is a simple approach. For production, you'd want to monitor the process
	await get_tree().create_timer(2.0).timeout

	var stream = VideoStreamTheora.new()
	stream.file = "user://" + output_filename

	$VideoStreamPlayer.stream = stream
	$VideoStreamPlayer.play()
	$CanvasLayer/VideoStreamPlayer2.stream = stream
	$CanvasLayer/VideoStreamPlayer2.play()

	# Clean up the HTTPRequest node
	http_request.queue_free()

	# Restart the timer for next update
	$Timer.start(300)


func _on_timer_timeout():
	update_radar()

func _cleanup_old_ogv_files():
	# Clean up any existing tmp_KOKX_loop_*.ogv files in user:// directory
	print_debug("Cleaning up old .ogv files...")
	var user_dir = DirAccess.open("user://")
	if user_dir == null:
		push_error("Failed to open user:// directory")
		return

	user_dir.list_dir_begin()
	var file_name = user_dir.get_next()
	var deleted_count = 0

	while file_name != "":
		if file_name.begins_with("tmp_KOKX_loop_") and file_name.ends_with(".ogv"):
			var file_path = "user://" + file_name
			var err = DirAccess.remove_absolute(file_path)
			if err == OK:
				print_debug("Deleted old file: " + file_name)
				deleted_count += 1
			else:
				push_error("Failed to delete file: " + file_name)
		file_name = user_dir.get_next()

	user_dir.list_dir_end()
	print_debug("Cleanup complete. Deleted " + str(deleted_count) + " old .ogv files")
