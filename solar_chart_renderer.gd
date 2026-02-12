extends Node2D

# --- Color Constants (Tailwind palette) ---
const COLOR_CIRCLE = Color("#f4f4f5")          # zinc-100
const COLOR_CARDINAL_LINE = Color("#f4f4f5")   # zinc-100
const COLOR_CARDINAL_LABEL = Color("#f4f4f5")  # zinc-100
const COLOR_HOUSE_FILL = Color("#1e293b")      # slate-800
const COLOR_HOUSE_STROKE = Color("#64748b")    # slate-500
const COLOR_DOOR_FILL = Color("#475569")       # slate-600
const COLOR_DOOR_STROKE = Color("#94a3b8")     # slate-400
const COLOR_SUMMER_ARC = Color("#fb923c", 0.7)    # orange-400 @ 70%
const COLOR_TODAY_ARC = Color("#fde047", 0.9)     # yellow-300 @ 90%
const COLOR_WINTER_ARC = Color("#60a5fa", 0.6)    # blue-400 @ 60%
const COLOR_SUN_BODY = Color("#f4f4f5")        # zinc-100
const COLOR_SUN_CENTER = Color("#ffffff")      # white
const COLOR_SUN_RAYS = Color("#f4f4f5", 0.7)   # zinc-100 @ 70%
const COLOR_SUN_DASHED = Color("#f4f4f5", 0.3) # zinc-100 @ 30%

# --- Layout Constants ---
const ARC_WIDTH = 20.0
const INNER_EDGE = 155.0
const WINTER_RADIUS = INNER_EDGE + ARC_WIDTH * 0.5   # 165
const TODAY_RADIUS = INNER_EDGE + ARC_WIDTH * 1.5     # 175
const SUMMER_RADIUS = INNER_EDGE + ARC_WIDTH * 2.5    # 185 (note: spec says 205 but this follows the formula)
const OUTER_EDGE = INNER_EDGE + ARC_WIDTH * 3.0       # 215
const CIRCLE_RADIUS = 220.0
const HOUSE_W = 120.0
const HOUSE_H = 180.0
const VIEW_ROTATION = -83.0

# Recalculate using spec values directly
# winter center = 155 + 10 = 165
# today center = 155 + 30 = 185
# summer center = 155 + 50 = 205
# outer_edge = 155 + 60 = 215

# Override with exact spec values
const WINTER_CENTER_R = 165.0
const TODAY_CENTER_R = 185.0
const SUMMER_CENTER_R = 205.0

# --- Data (set by parent solar_chart.gd) ---
var summer_sunrise_az: float = 0.0
var summer_sunset_az: float = 0.0
var today_sunrise_az: float = 0.0
var today_sunset_az: float = 0.0
var winter_sunrise_az: float = 0.0
var winter_sunset_az: float = 0.0
var sun_azimuth: float = 0.0
var sun_is_up: bool = false


func _az_to_angle(az_deg: float) -> float:
	return deg_to_rad(az_deg - 90.0 + VIEW_ROTATION)


func _az_to_xy(az_deg: float, radius: float) -> Vector2:
	var angle = _az_to_angle(az_deg)
	return Vector2(cos(angle), sin(angle)) * radius


func _draw():
	# 1. Overall circle
	draw_arc(Vector2.ZERO, CIRCLE_RADIUS, 0, TAU, 128, COLOR_CIRCLE, 1.0, true)

	# 2. Cardinal direction lines (behind arcs)
	var cardinal_azimuths = [0.0, 90.0, 180.0, 270.0]  # N, E, S, W
	var line_inner = INNER_EDGE - 5.0
	var line_outer = OUTER_EDGE + 5.0
	for az in cardinal_azimuths:
		var p1 = _az_to_xy(az, line_inner)
		var p2 = _az_to_xy(az, line_outer)
		draw_line(p1, p2, COLOR_CARDINAL_LINE, 1.0, true)

	# 3. Summer solstice arc (outermost)
	if summer_sunset_az > summer_sunrise_az:
		var start_angle = _az_to_angle(summer_sunrise_az)
		var end_angle = _az_to_angle(summer_sunset_az)
		draw_arc(Vector2.ZERO, SUMMER_CENTER_R, start_angle, end_angle, 128, COLOR_SUMMER_ARC, ARC_WIDTH, false)

	# 4. Today's arc (middle)
	if today_sunset_az > today_sunrise_az:
		var start_angle = _az_to_angle(today_sunrise_az)
		var end_angle = _az_to_angle(today_sunset_az)
		draw_arc(Vector2.ZERO, TODAY_CENTER_R, start_angle, end_angle, 128, COLOR_TODAY_ARC, ARC_WIDTH, false)

	# 5. Winter solstice arc (innermost)
	if winter_sunset_az > winter_sunrise_az:
		var start_angle = _az_to_angle(winter_sunrise_az)
		var end_angle = _az_to_angle(winter_sunset_az)
		draw_arc(Vector2.ZERO, WINTER_CENTER_R, start_angle, end_angle, 128, COLOR_WINTER_ARC, ARC_WIDTH, false)

	# 6. Cardinal direction labels
	var labels = ["N", "E", "S", "W"]
	var label_radius = CIRCLE_RADIUS + 16.0
	for i in range(4):
		var az = cardinal_azimuths[i]
		var pos = _az_to_xy(az, label_radius)
		var font = ThemeDB.fallback_font
		var font_size = 22
		var text_size = font.get_string_size(labels[i], HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, pos - Vector2(text_size.x / 2.0, -text_size.y / 4.0), labels[i], HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, COLOR_CARDINAL_LABEL)

	# 7. House rectangle (rotated -90 in local space)
	_draw_house()

	# 8. Sun icon (if sun is up)
	if sun_is_up:
		_draw_sun()


func _draw_house():
	# The house is rotated -90 degrees in local space
	# Combined with view_rotation, the west wall ends up horizontal
	var house_angle = deg_to_rad(-90.0)
	var hw = HOUSE_W / 2.0
	var hh = HOUSE_H / 2.0

	# House corners (before rotation)
	var corners_local = [
		Vector2(-hw, -hh),
		Vector2(hw, -hh),
		Vector2(hw, hh),
		Vector2(-hw, hh)
	]

	# Rotate corners
	var corners = PackedVector2Array()
	for c in corners_local:
		corners.append(c.rotated(house_angle))

	# Fill
	draw_colored_polygon(corners, COLOR_HOUSE_FILL)

	# Stroke (draw edges)
	for i in range(4):
		draw_line(corners[i], corners[(i + 1) % 4], COLOR_HOUSE_STROKE, 2.0, true)

	# Door: on the west (left in unrotated space) long wall, scaled with house
	var door_local = [
		Vector2(-hw - 7.0, -15.0),
		Vector2(-hw - 7.0 + 10.0, -15.0),
		Vector2(-hw - 7.0 + 10.0, -15.0 + 30.0),
		Vector2(-hw - 7.0, -15.0 + 30.0)
	]
	var door_corners = PackedVector2Array()
	for c in door_local:
		door_corners.append(c.rotated(house_angle))

	draw_colored_polygon(door_corners, COLOR_DOOR_FILL)
	for i in range(4):
		draw_line(door_corners[i], door_corners[(i + 1) % 4], COLOR_DOOR_STROKE, 1.0, true)


func _draw_sun():
	var sun_pos = _az_to_xy(sun_azimuth, TODAY_CENTER_R)

	# Dashed line from house center to sun
	_draw_dashed_line(Vector2.ZERO, sun_pos, COLOR_SUN_DASHED, 0.75, 6.0, 4.0)

	# 8 rays at 45 degree intervals
	for i in range(8):
		var ray_angle = deg_to_rad(i * 45.0)
		var ray_start = sun_pos + Vector2(cos(ray_angle), sin(ray_angle)) * 9.0
		var ray_end = sun_pos + Vector2(cos(ray_angle), sin(ray_angle)) * 14.0
		draw_line(ray_start, ray_end, COLOR_SUN_RAYS, 1.5, true)

	# Body circle
	draw_circle(sun_pos, 7.0, COLOR_SUN_BODY)

	# Center highlight
	draw_circle(sun_pos, 3.5, COLOR_SUN_CENTER)


func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash_length: float, gap_length: float):
	var direction = (to - from).normalized()
	var total_length = from.distance_to(to)
	var current = 0.0

	while current < total_length:
		var dash_end = minf(current + dash_length, total_length)
		var p1 = from + direction * current
		var p2 = from + direction * dash_end
		draw_line(p1, p2, color, width, true)
		current = dash_end + gap_length
