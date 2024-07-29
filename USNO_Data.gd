extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	_send_http_request()

func get_tz_offset_in_hours():
	var tz = Time.get_time_zone_from_system()
	#var offset = Time.get_offset_string_from_offset_minutes(tz.bias)
	var offset = float(tz.bias) / 60.0
	return offset
	
func build_url():
	var date = Time.get_date_string_from_system(true)
	var tz_offset = get_tz_offset_in_hours()
	var url = "https://aa.usno.navy.mil/api/rstt/oneday?date=" + date + \
	"&coords=40.899761,-73.367905&tz=" + str(tz_offset) + "&dst=false"
	return url
	
func _send_http_request():
	var http_request = HTTPRequest.new()
	add_child(http_request)

	http_request.request_completed.connect(_on_request_completed)
	http_request.request(build_url())
	
func _on_request_completed(result, response_code, headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())
	$Timer.start(3600) # Restart every hour
	parse_usno_oneday(json)
	
func parse_usno_oneday(json):
	var moon_phase = json["properties"]["data"]["curphase"]
	var moon_frac = json["properties"]["data"]["fracillum"]
	
	var moonrise = ""
	var moonset = ""
	for d in json.properties.data.moondata:
		if d.phen == "Rise":
			moonrise = d.time
		if d.phen == "Set":
			moonset = d.time
	
	var sunrise = ""
	var sunset = ""
	for s in json.properties.data.sundata:
		if s.phen == "Rise":
			sunrise = s.time
		if s.phen == "Set":
			sunset = s.time

	_update_fields(moon_phase, moon_frac, moonrise, moonset, sunrise, sunset)
				

func mil_time_to_12hr(military_time):
	var split_time = military_time.split(":", false, 1)
	var hour = int(split_time[0])
	var min = int(split_time[1])
	
	var ampm = "AM"
	if hour > 12:
		hour = hour - 12
	if hour >= 12:
		ampm = "PM"
	if hour == 0:
		hour = 12
	
	return "%d:%d %s" % [hour, min, ampm]
	
func _update_fields(moon_phase, moon_frac, moonrise, moonset, sunrise, sunset):
	$Sunrise.text = mil_time_to_12hr(sunrise)
	$Sunset.text = mil_time_to_12hr(sunset)
	$Moonrise.text = mil_time_to_12hr(moonrise)
	$Moonset.text = mil_time_to_12hr(moonset)
	$Moonphase.text = moon_phase + " (" + moon_frac + ")"


func _on_timer_timeout():
	_send_http_request()
