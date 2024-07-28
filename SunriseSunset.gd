extends Node2D

const url = "https://api.sunrise-sunset.org/json"
const mylat = "40.7127837"
const mylng = "-74.0059413"

# Called when the node enters the scene tree for the first time.
func _ready():
	self._send_http_request()
	pass # Replace with function body.


func _send_http_request():
	print_debug("sending http request")
	var http_request = HTTPRequest.new()
	add_child(http_request)
	var header = ["lat: " + mylat, "lng: " + mylng, "date: today", "formatted: 0"]

	http_request.request_completed.connect(_on_request_completed)
	http_request.request(url, header)
	
func _on_request_completed(result, response_code, headers, body):
	print_debug("Request completed")
	if result != HTTPRequest.RESULT_SUCCESS:
		print_debug("Request Failed: " + str(result) + " " + str(response_code))
	self._parse_sunrise_sunset(body)
	
func _parse_sunrise_sunset(body):
	var json = JSON.parse_string(body.get_string_from_utf8())
	print_debug(json)
	
	
