extends Timer

const url = "https://forecast.weather.gov/MapClick.php?lat=40.73443&lon=-73.41639&FcstType=json"
# const header = "accept: application/geo+json"

# Called when the node enters the scene tree for the first time.
func _ready():
	# Run the timeout immediately
	self._on_timeout()



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
func _on_timeout():
	print_debug("Forecast Timer Called")
	$HTTPRequest.request_completed.connect(_on_request_completed)
	$HTTPRequest.request(url)
	self.start()
	print_debug("Forecast Timer Restarted")
	print_debug(self.time_left)

func _on_request_completed(result, response_code, headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())
	
	self._update_forecast(json, 0, "%ForecastPeriod0")
	self._update_forecast(json, 1, "%ForecastPeriod1")
	self._update_forecast(json, 2, "%ForecastPeriod2")
	self._update_forecast(json, 3, "%ForecastPeriod3")
	self._update_forecast(json, 4, "%ForecastPeriod4")
	
	self.download_image(json["data"]["iconLink"][0])

func _update_forecast(json, index, node):
	var period =(json["time"]["startPeriodName"][index])
	var temp = json["data"]["temperature"][index]
	var temp_label = json["time"]["tempLabel"][index]
	var weather = json["data"]["weather"][index]
	var detail = json["data"]["text"][index]
	
	get_node(node).update(period, temp, temp_label, weather, detail)

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
	get_node("%TextureRect").texture = texture
