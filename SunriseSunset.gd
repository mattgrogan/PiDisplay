extends Node2D

const base_url = "https://www.timeanddate.com/scripts/sunmap.php?iso="


func _ready():
	self._send_http_request()

func _send_http_request():
	var http_request = HTTPRequest.new()
	add_child(http_request)

	http_request.request_completed.connect(_on_request_completed)
	var url = base_url + Time.get_datetime_string_from_system(true, false)
	http_request.request(url)
	
func _on_request_completed(result, response_code, headers, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		print_debug("Request Failed: " + str(result) + " " + str(response_code))
		
	var image = Image.new()
	var error = image.load_jpg_from_buffer(body)
	if error != OK:
		push_error("Couldn't load the image.")

	var texture = ImageTexture.create_from_image(image)

	# Display the image in a TextureRect node.
	$SunlightThumb.texture = texture
	$CanvasLayer/SunlightMaximized.texture = texture

	
	# Reset the timer
	$Timer.start(3600) # Get a new image after 1h


func _on_button_pressed():
	$CanvasLayer.show()


func _on_close_button_pressed():
	$CanvasLayer.hide()


func _on_timer_timeout():
	self._send_http_request()
