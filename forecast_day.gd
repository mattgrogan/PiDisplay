extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func update(period, temp, temp_label, forecast, detail, icon_url):
	get_node("Period").text = period.to_upper()
	get_node("Temp").text = temp
	get_node("TempLabel").text = temp_label
	get_node("Forecast").text = forecast
	
	get_node("ForecastDetailWindow/Period").text = period
	get_node("ForecastDetailWindow/Temp").text = temp
	get_node("ForecastDetailWindow/TempLabel").text = temp_label
	get_node("ForecastDetailWindow/Forecast").text = forecast
	get_node("ForecastDetailWindow/ScrollContainer/ForecastDetail").text = detail
	
	print_debug("DOWNLOADING ICON...")
	print_debug(icon_url)
	download_image(icon_url)
	


func download_image(url):
	# Create an HTTP request node and connect its completion signal.
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(self._http_request_completed)

	# Perform the HTTP request. The URL below returns a PNG image as of writing.
	var error = http_request.request(url)
	if error != OK:
		push_error("An error occurred in the HTTP request.")

# Called when the HTTP request is completed.
func _http_request_completed(result, response_code, headers, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Image couldn't be downloaded. Try a different image.")

	var image = Image.new()
	var error = image.load_png_from_buffer(body)
	if error != OK:
		push_error("Couldn't load the image.")

	var texture = ImageTexture.create_from_image(image)

	# Display the image in a TextureRect node.
	get_node("ForecastDetailWindow/WeatherIcon").texture = texture

func _on_close_button_pressed():
	get_node("ForecastDetailWindow").hide()



func _on_open_detail_pressed():
	get_node("ForecastDetailWindow").show()
