extends Timer

const HALF_HOUR = 30 * 60

const url = "https://forecast.weather.gov/MapClick.php?lat=40.73443&lon=-73.41639&FcstType=json"
# const header = "accept: application/geo+json"

# Called when the node enters the scene tree for the first time.
func _ready():
	# Run the timeout immediately
	self._on_timeout()
	
func _on_timeout():
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed.bind(http_request))
	var error = http_request.request(url)
	if error != OK:
		push_error("Failed to start HTTP request")
		http_request.queue_free()

func _on_request_completed(result, response_code, _headers, body, http_request):
	if result != HTTPRequest.RESULT_SUCCESS:
		print_debug("Forecast request failed: " + str(result) + " " + str(response_code))
		http_request.queue_free()
		self.start(HALF_HOUR)  # Try again later
		return

	var json = JSON.parse_string(body.get_string_from_utf8())

	if json == null:
		print_debug("Failed to parse forecast JSON")
		http_request.queue_free()
		self.start(HALF_HOUR)
		return

	self._update_forecast(json, 0, "%ForecastPeriod0")
	self._update_forecast(json, 1, "%ForecastPeriod1")
	self._update_forecast(json, 2, "%ForecastPeriod2")
	self._update_forecast(json, 3, "%ForecastPeriod3")
	self._update_forecast(json, 4, "%ForecastPeriod4")

	# Clean up the HTTPRequest node
	http_request.queue_free()

	# Restart timer after all updates are complete
	self.start(HALF_HOUR)

func _update_forecast(json, index, node):
	var forecast_node = get_node_or_null(node)
	if forecast_node == null:
		print_debug("Forecast node not found: " + node)
		return

	var period =(json["time"]["startPeriodName"][index])
	var temp = json["data"]["temperature"][index]
	var temp_label = json["time"]["tempLabel"][index]
	var weather = json["data"]["weather"][index]
	var detail = json["data"]["text"][index]
	var icon_url = json["data"]["iconLink"][index]

	forecast_node.update(period, temp, temp_label, weather, detail, icon_url)
	
#func download_image(url):
	## Create an HTTP request node and connect its completion signal.
	#var http_request = HTTPRequest.new()
	#add_child(http_request)
	#http_request.request_completed.connect(self._http_request_completed)
#
	## Perform the HTTP request. The URL below returns a PNG image as of writing.
	#var error = http_request.request(url)
	#if error != OK:
		#push_error("An error occurred in the HTTP request.")
#
## Called when the HTTP request is completed.
#func _http_request_completed(result, response_code, headers, body):
	#if result != HTTPRequest.RESULT_SUCCESS:
		#push_error("Image couldn't be downloaded. Try a different image.")
#
	#var image = Image.new()
	#var error = image.load_png_from_buffer(body)
	#if error != OK:
		#push_error("Couldn't load the image.")
#
	#var texture = ImageTexture.create_from_image(image)
#
	## Display the image in a TextureRect node.
	#get_node("%TextureRect").texture = texture
