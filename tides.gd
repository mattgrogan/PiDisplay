extends Node2D

const base_url = "https://wave.marineweather.net/itide/tides/png/ny_northport_long_island.png"

func _ready():
	self._send_http_request()

func _send_http_request():
	var http_request = HTTPRequest.new()
	add_child(http_request)

	http_request.request_completed.connect(_on_request_completed.bind(http_request))
	#var url = base_url + Time.get_datetime_string_from_system(true, false)
	var error = http_request.request(base_url)
	if error != OK:
		push_error("Failed to start HTTP request")
		http_request.queue_free()
	
func _on_request_completed(result, response_code, _headers, body, http_request):
	if result != HTTPRequest.RESULT_SUCCESS:
		print_debug("Request Failed: " + str(result) + " " + str(response_code))
		http_request.queue_free()
		$Timer.start(900)  # Try again later
		return

	var image = Image.new()
	var error = image.load_png_from_buffer(body)
	if error != OK:
		push_error("Couldn't load the image.")
		http_request.queue_free()
		$Timer.start(900)
		return

	var texture = ImageTexture.create_from_image(image)

	# Display the image in a TextureRect node.
	$TidesThumb.texture = texture
	$CanvasLayer/TidesMaximized.texture = texture

	# Clean up the HTTPRequest node
	http_request.queue_free()

	# Reset the timer
	$Timer.start(900) # Get a new image after 15m


func _on_button_pressed():
	$CanvasLayer.show()


func _on_close_button_pressed():
	$CanvasLayer.hide()


func _on_timer_timeout():
	self._send_http_request()
