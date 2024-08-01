extends Timer

const THREE_HOURS = 3 * 60 * 60

const host = "https://www.bing.com"
const url = host + "/" + "HPImageArchive.aspx?format=xml&idx=0&n=1&mkt=en-US"

# Called when the node enters the scene tree for the first time.
func _ready():
	# Run the timeout immediately
	self._on_timeout()

func _on_timeout():
	print_debug("Background Timer Called")
	print_debug("connecting to " + url)
	$HTTPRequest.request_completed.connect(_on_request_completed)
	$HTTPRequest.request(url)

func _on_request_completed(result, response_code, headers, body):
	print_debug("PARSING")
	var parser = XMLParser.new()
	var err = parser.open_buffer(body)
	
	var image_url = ""
	var is_url_node = false
	
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			var node_name = parser.get_node_name()
			is_url_node = node_name == "url"
		if parser.get_node_type() == XMLParser.NODE_TEXT:
			if is_url_node:
				image_url = parser.get_node_data()
				
	print_debug("The image URL is: " + host + image_url)
	self.download_image(host + image_url)
			
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
	print_debug("Downloaded image")
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Image couldn't be downloaded. Try a different image.")

	var image = Image.new()
	var error = image.load_jpg_from_buffer(body)
	if error != OK:
		push_error("Couldn't load the image.")

	var texture = ImageTexture.create_from_image(image)

	# Display the image in a TextureRect node.
	get_node("%BackgroundTexture").texture = texture

	self.start(THREE_HOURS)
	print_debug("Background Timer Restarted")
	print_debug(self.time_left)
