extends Node2D

# --- Color Constants (Tailwind palette) ---
const COLOR_ICON = Color("#fde047")        # yellow-300
const COLOR_LABEL = Color("#94a3b8")       # slate-400
const COLOR_VALUE = Color("#e2e8f0")       # slate-200
const COLOR_DELTA_GAIN = Color("#34d399")  # emerald-400
const COLOR_DELTA_LOSE = Color("#fb7185")  # rose-400
const COLOR_EVENT = Color("#94a3b8")       # slate-400

# --- Layout Constants ---
const PANEL_W = 320.0
const PANEL_H = 480.0
const LEFT_MARGIN = 20.0
const RIGHT_MARGIN = 20.0
const ROW_HEIGHT = 72.0
const ICON_SIZE = 20
const LABEL_SIZE = 18
const VALUE_SIZE = 26
const DELTA_SIZE = 16
const EVENT_SIZE = 18

# --- Data (set by parent solar_chart.gd) ---
var sunrise_clock_hour: float = 6.5
var sunset_clock_hour: float = 17.5
var daylight_hours: float = 11.0
var sunrise_delta_min: float = 0.0
var sunset_delta_min: float = 0.0
var daylight_delta_min: float = 0.0
var next_event_name: String = "Equinox"
var next_event_days: int = 0


func _format_clock_time(decimal_hours: float) -> String:
	var total_minutes = int(round(decimal_hours * 60.0))
	if total_minutes < 0:
		total_minutes += 1440
	var hours = total_minutes / 60
	var minutes = total_minutes % 60
	var period = "AM" if hours < 12 else "PM"
	var display_hour = hours % 12
	if display_hour == 0:
		display_hour = 12
	return "%d:%02d %s" % [display_hour, minutes, period]


func _format_duration(hours_val: float) -> String:
	var total_minutes = int(round(hours_val * 60.0))
	var h = total_minutes / 60
	var m = total_minutes % 60
	return "%dh %02dm" % [h, m]


func _format_delta(delta_min: float) -> Dictionary:
	var abs_min = int(round(abs(delta_min)))
	if abs_min == 0:
		return {"text": "", "color": COLOR_LABEL}
	var arrow = "\u25b2" if delta_min > 0 else "\u25bc"
	var color = COLOR_DELTA_GAIN if delta_min > 0 else COLOR_DELTA_LOSE
	return {"text": "%s %dm" % [arrow, abs_min], "color": color}


func _draw():
	var font = ThemeDB.fallback_font

	# Vertical centering: 3 data rows + event row
	var content_height = 3.0 * ROW_HEIGHT + 40.0
	var y_start = (PANEL_H - content_height) / 2.0

	var rows = [
		{
			"icon": "\u2600",
			"label": "SUNRISE",
			"value": _format_clock_time(sunrise_clock_hour),
			"delta": _format_delta(sunrise_delta_min),
		},
		{
			"icon": "\u263d",
			"label": "SUNSET",
			"value": _format_clock_time(sunset_clock_hour),
			"delta": _format_delta(sunset_delta_min),
		},
		{
			"icon": "\u25d0",
			"label": "DAYLIGHT",
			"value": _format_duration(daylight_hours),
			"delta": _format_delta(daylight_delta_min),
		},
	]

	# Draw rows 1-3
	for i in range(3):
		var row = rows[i]
		var row_y = y_start + i * ROW_HEIGHT

		# Line 1: icon + label
		var icon_pos = Vector2(LEFT_MARGIN, row_y + 22)
		draw_string(font, icon_pos, row.icon, HORIZONTAL_ALIGNMENT_LEFT, -1, ICON_SIZE, COLOR_ICON)

		var icon_width = font.get_string_size(row.icon, HORIZONTAL_ALIGNMENT_LEFT, -1, ICON_SIZE).x
		var label_pos = Vector2(LEFT_MARGIN + icon_width + 8.0, row_y + 22)
		draw_string(font, label_pos, row.label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, COLOR_LABEL)

		# Line 2: value + delta (right-aligned)
		var value_y = row_y + 52
		var value_pos = Vector2(LEFT_MARGIN + 4.0, value_y)
		draw_string(font, value_pos, row.value, HORIZONTAL_ALIGNMENT_LEFT, -1, VALUE_SIZE, COLOR_VALUE)

		if row.delta.text != "":
			var delta_text = row.delta.text
			var delta_width = font.get_string_size(delta_text, HORIZONTAL_ALIGNMENT_LEFT, -1, DELTA_SIZE).x
			var delta_pos = Vector2(PANEL_W - RIGHT_MARGIN - delta_width, value_y)
			draw_string(font, delta_pos, delta_text, HORIZONTAL_ALIGNMENT_LEFT, -1, DELTA_SIZE, row.delta.color)

	# Row 4: next solar event (centered)
	var event_y = y_start + 3.0 * ROW_HEIGHT + 20.0
	var event_text: String
	if next_event_days == 0:
		event_text = "%s today" % next_event_name
	else:
		event_text = "%s in %d days" % [next_event_name, next_event_days]

	var event_width = font.get_string_size(event_text, HORIZONTAL_ALIGNMENT_LEFT, -1, EVENT_SIZE).x
	var event_x = (PANEL_W - event_width) / 2.0
	draw_string(font, Vector2(event_x, event_y), event_text, HORIZONTAL_ALIGNMENT_LEFT, -1, EVENT_SIZE, COLOR_EVENT)
