extends Timer

const url = "https://api.weather.gov/stations/KFRG/observations/latest"
const header = "accept: application/geo+json"

# Called when the node enters the scene tree for the first time.
func _ready():
	# Run the timeout immediately
	self._on_timeout()



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
func _on_timeout():
	print_debug("timer called")
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	http_request.request(url, [header])
	self.start()
	print_debug("started")
	print_debug(self.time_left)

func _on_request_completed(result, response_code, headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())
	var temp_c = float(json["properties"]["temperature"]["value"])
	var temp_f = (temp_c * 9.0 / 5.0) + 32
	
	var temp_label = get_node("%Temp")
	temp_label.text = "%d" % temp_f
	print(temp_f)
