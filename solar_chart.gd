extends Node2D

# --- Location & Orientation Constants ---
const LATITUDE = 40.85        # degrees north
const LONGITUDE = -73.32      # degrees west
const UTC_OFFSET = -5         # EST
const HOUSE_ROTATION = -7.0   # degrees from true north

# --- Solstice day-of-year values ---
const SUMMER_SOLSTICE_DOY = 172
const WINTER_SOLSTICE_DOY = 356

# --- State ---
var current_date: Dictionary
var current_doy: int

var today_sunrise_az: float
var today_sunset_az: float
var summer_sunrise_az: float
var summer_sunset_az: float
var winter_sunrise_az: float
var winter_sunset_az: float
var sun_azimuth: float
var sun_is_up: bool = false

var today_sun_path: PackedFloat64Array

# --- Stats sidebar data ---
var sunrise_clock_hour: float
var sunset_clock_hour: float
var daylight_hours: float
var sunrise_delta_min: float
var sunset_delta_min: float
var daylight_delta_min: float
var next_event_name: String
var next_event_days: int


func _ready():
	_compute_all()
	$SubViewport/ChartRenderer.queue_redraw()
	# Wait for the SubViewport to render before capturing
	await get_tree().process_frame
	await get_tree().process_frame
	_capture_and_assign_texture()
	$Timer.start(300)


func _compute_all():
	var now = Time.get_datetime_dict_from_system(false)
	current_date = now
	current_doy = _day_of_year(now.year, now.month, now.day)

	# Today's declination and arcs
	var today_decl = _declination(current_doy)
	today_sunrise_az = _sunrise_azimuth(LATITUDE, today_decl)
	today_sunset_az = 360.0 - today_sunrise_az

	# Summer solstice
	var summer_decl = _declination(SUMMER_SOLSTICE_DOY)
	summer_sunrise_az = _sunrise_azimuth(LATITUDE, summer_decl)
	summer_sunset_az = 360.0 - summer_sunrise_az

	# Winter solstice
	var winter_decl = _declination(WINTER_SOLSTICE_DOY)
	winter_sunrise_az = _sunrise_azimuth(LATITUDE, winter_decl)
	winter_sunset_az = 360.0 - winter_sunrise_az

	# Today's sun path (array of azimuths)
	today_sun_path = _compute_sun_path(LATITUDE, today_decl)

	# Current sun position
	_update_sun_position(now, today_decl)

	# Push data to the renderer
	_update_renderer()

	# Compute and push stats sidebar data
	_compute_stats()
	_update_stats_renderer()


func _update_sun_position(now: Dictionary, decl: float):
	var clock_hour = now.hour + now.minute / 60.0 + now.second / 3600.0
	var solar_hour = _clock_to_solar(clock_hour, current_doy)

	# Compute hour angle and azimuth for any time of day
	var hour_angle = (solar_hour - 12.0) * 15.0
	sun_azimuth = _solar_azimuth_at_hour_angle(LATITUDE, decl, hour_angle)

	# Determine if sun is above the horizon
	var h0 = _hour_angle_sunrise(LATITUDE, decl)
	var sunrise_solar = 12.0 - h0 / 15.0
	var sunset_solar = 12.0 + h0 / 15.0
	sun_is_up = solar_hour >= sunrise_solar and solar_hour <= sunset_solar


func _update_renderer():
	var renderer = $SubViewport/ChartRenderer
	renderer.summer_sunrise_az = summer_sunrise_az
	renderer.summer_sunset_az = summer_sunset_az
	renderer.today_sunrise_az = today_sunrise_az
	renderer.today_sunset_az = today_sunset_az
	renderer.winter_sunrise_az = winter_sunrise_az
	renderer.winter_sunset_az = winter_sunset_az
	renderer.sun_azimuth = sun_azimuth
	renderer.sun_is_up = sun_is_up


func _capture_and_assign_texture():
	var image = $SubViewport.get_texture().get_image()
	var texture = ImageTexture.create_from_image(image)
	$ChartThumb.texture = texture
	$CanvasLayer/ChartMaximized.texture = texture


# --- Solar Math ---

func _day_of_year(year: int, month: int, day: int) -> int:
	var days_in_month = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	# Leap year check
	if (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0):
		days_in_month[1] = 29
	var doy = 0
	for i in range(month - 1):
		doy += days_in_month[i]
	doy += day
	return doy


func _declination(doy: int) -> float:
	# Returns solar declination in degrees
	return -23.44 * cos(deg_to_rad(360.0 / 365.0 * (doy + 10)))


func _sunrise_azimuth(lat: float, decl: float) -> float:
	# Returns sunrise azimuth in degrees from north (clockwise)
	var lat_rad = deg_to_rad(lat)
	var decl_rad = deg_to_rad(decl)
	var cos_val = sin(decl_rad) / cos(lat_rad)
	cos_val = clampf(cos_val, -1.0, 1.0)
	return rad_to_deg(acos(cos_val))


func _hour_angle_sunrise(lat: float, decl: float) -> float:
	# Returns hour angle at sunrise in degrees
	var lat_rad = deg_to_rad(lat)
	var decl_rad = deg_to_rad(decl)
	var cos_val = -tan(lat_rad) * tan(decl_rad)
	cos_val = clampf(cos_val, -1.0, 1.0)
	return rad_to_deg(acos(cos_val))


func _equation_of_time(doy: int) -> float:
	# Returns equation of time correction in minutes
	var b = deg_to_rad(360.0 / 365.0 * (doy - 81))
	return 9.87 * sin(2.0 * b) - 7.53 * cos(b) - 1.5 * sin(b)


func _clock_to_solar(clock_hour: float, doy: int) -> float:
	# Converts clock time (hours) to solar time (hours)
	var std_meridian = UTC_OFFSET * 15.0  # -75 for EST
	var long_correction = 4.0 * (std_meridian - LONGITUDE)  # minutes
	var eot = _equation_of_time(doy)
	return clock_hour + (long_correction + eot) / 60.0


func _solar_to_clock(solar_hour: float, doy: int) -> float:
	# Converts solar time (hours) back to clock time (hours)
	var std_meridian = UTC_OFFSET * 15.0
	var long_correction = 4.0 * (std_meridian - LONGITUDE)
	var eot = _equation_of_time(doy)
	return solar_hour - (long_correction + eot) / 60.0


func _solar_azimuth_at_hour_angle(lat: float, decl: float, h: float) -> float:
	# Returns solar azimuth in degrees (0-360, from north clockwise)
	var lat_rad = deg_to_rad(lat)
	var decl_rad = deg_to_rad(decl)
	var h_rad = deg_to_rad(h)

	var sin_alt = sin(lat_rad) * sin(decl_rad) + cos(lat_rad) * cos(decl_rad) * cos(h_rad)
	var cos_alt = sqrt(maxf(0.0, 1.0 - sin_alt * sin_alt))

	if cos_alt < 0.001:
		return 180.0  # Sun at zenith, azimuth undefined

	var sin_az = -sin(h_rad) * cos(decl_rad) / cos_alt
	var cos_az = (sin(decl_rad) - sin(lat_rad) * sin_alt) / (cos(lat_rad) * cos_alt)

	var azimuth = rad_to_deg(atan2(sin_az, cos_az))

	# Normalize to 0-360
	if azimuth < 0.0:
		azimuth += 360.0
	return azimuth


func _compute_sun_path(lat: float, decl: float) -> PackedFloat64Array:
	# Returns array of azimuths sampled across the day
	var h0 = _hour_angle_sunrise(lat, decl)
	var num_points = 128
	var path = PackedFloat64Array()
	path.resize(num_points)

	for i in range(num_points):
		var fraction = float(i) / float(num_points - 1)
		var h = -h0 + fraction * 2.0 * h0  # from -H0 to +H0
		path[i] = _solar_azimuth_at_hour_angle(lat, decl, h)

	return path


# --- Stats Computation ---

func _compute_stats():
	# Today's sunrise/sunset clock times and daylight
	var today_decl = _declination(current_doy)
	var h0_today = _hour_angle_sunrise(LATITUDE, today_decl)
	var sunrise_solar = 12.0 - h0_today / 15.0
	var sunset_solar = 12.0 + h0_today / 15.0
	sunrise_clock_hour = _solar_to_clock(sunrise_solar, current_doy)
	sunset_clock_hour = _solar_to_clock(sunset_solar, current_doy)
	daylight_hours = 2.0 * h0_today / 15.0

	# Yesterday's values for deltas
	var yesterday_doy = current_doy - 1
	if yesterday_doy < 1:
		yesterday_doy = 365
	var yest_decl = _declination(yesterday_doy)
	var h0_yest = _hour_angle_sunrise(LATITUDE, yest_decl)
	var yest_sunrise_solar = 12.0 - h0_yest / 15.0
	var yest_sunset_solar = 12.0 + h0_yest / 15.0
	var yest_sunrise_clock = _solar_to_clock(yest_sunrise_solar, yesterday_doy)
	var yest_sunset_clock = _solar_to_clock(yest_sunset_solar, yesterday_doy)
	var yest_daylight = 2.0 * h0_yest / 15.0

	# Deltas in minutes (positive = gaining)
	sunrise_delta_min = (yest_sunrise_clock - sunrise_clock_hour) * 60.0
	sunset_delta_min = (sunset_clock_hour - yest_sunset_clock) * 60.0
	daylight_delta_min = (daylight_hours - yest_daylight) * 60.0

	# Next solar event
	var events = [
		{"name": "Equinox", "doy": 79},
		{"name": "Solstice", "doy": 172},
		{"name": "Equinox", "doy": 265},
		{"name": "Solstice", "doy": 355},
	]
	var best_name = ""
	var best_days = 366
	for ev in events:
		var diff = ev.doy - current_doy
		if diff < 0:
			diff += 365
		if diff < best_days:
			best_days = diff
			best_name = ev.name
	next_event_name = best_name
	next_event_days = best_days


func _update_stats_renderer():
	var stats = $CanvasLayer/StatsRenderer
	stats.sunrise_clock_hour = sunrise_clock_hour
	stats.sunset_clock_hour = sunset_clock_hour
	stats.daylight_hours = daylight_hours
	stats.sunrise_delta_min = sunrise_delta_min
	stats.sunset_delta_min = sunset_delta_min
	stats.daylight_delta_min = daylight_delta_min
	stats.next_event_name = next_event_name
	stats.next_event_days = next_event_days
	stats.queue_redraw()


# --- Timer & Click Handlers ---

func _on_timer_timeout():
	var now = Time.get_datetime_dict_from_system(false)
	var new_doy = _day_of_year(now.year, now.month, now.day)

	if new_doy != current_doy:
		# Date changed — full recompute
		_compute_all()
	else:
		# Just update sun position
		var today_decl = _declination(current_doy)
		_update_sun_position(now, today_decl)
		_update_renderer()
		_update_stats_renderer()

	$SubViewport/ChartRenderer.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	_capture_and_assign_texture()
	$Timer.start(300)


func _on_button_pressed():
	$CanvasLayer.show()


func _on_close_button_pressed():
	$CanvasLayer.hide()
