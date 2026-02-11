extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	print_debug($VideoStreamPlayer.stream)
	print_debug($VideoStreamPlayer)
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
	http_request.request_completed.connect(_on_radar_download_completed)

	var err = http_request.request(url)
	if err != OK:
		push_error("Failed to start radar download request")
		$Timer.start(300)  # Try again later

func _on_radar_download_completed(result, response_code, headers, body):
	print_debug("Radar download completed")

	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Radar download failed: " + str(result) + " " + str(response_code))
		$Timer.start(300)  # Try again later
		return

	# Save the downloaded GIF to file
	var file = FileAccess.open("user://KOKX_loop.gif", FileAccess.WRITE)
	if file == null:
		push_error("Failed to open file for writing")
		$Timer.start(300)
		return

	file.store_buffer(body)
	file.close()
	print_debug("GIF saved to user://KOKX_loop.gif")

	# Convert GIF to OGV using ffmpeg (non-blocking)
	print_debug("Running ffmpeg...")
	var output_filename = "tmp_KOKX_loop_" + Time.get_datetime_string_from_system(true) + ".ogv"
	output_filename = output_filename.replace(":", "")
	output_filename = output_filename.replace("-", "")
	print_debug("Output filename: " + output_filename)

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

	# Restart the timer for next update
	$Timer.start(300)


func _on_timer_timeout():
	update_radar()
