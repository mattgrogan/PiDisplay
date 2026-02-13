extends Node2D

# --- Color Constants (Tailwind palette) ---
const COLOR_CIRCLE = Color("#f4f4f5")          # zinc-100
const COLOR_CARDINAL_LINE = Color("#f4f4f5")   # zinc-100
const COLOR_CARDINAL_LABEL = Color("#f4f4f5")  # zinc-100
const COLOR_HOUSE_FILL = Color("#1e293b")      # slate-800
const COLOR_HOUSE_STROKE = Color("#64748b")    # slate-500
const COLOR_DOOR_FILL = Color("#475569")       # slate-600
const COLOR_DOOR_STROKE = Color("#94a3b8")     # slate-400
const COLOR_SUMMER_ARC = Color("#fb923c")         # orange-400
const COLOR_TODAY_ARC = Color("#fde047")          # yellow-300
const COLOR_WINTER_ARC = Color("#60a5fa")         # blue-400
const COLOR_SUN_BODY = Color("#f4f4f5")        # zinc-100
const COLOR_SUN_CENTER = Color("#ffffff")      # white
const COLOR_SUN_RAYS = Color("#f4f4f5", 0.7)   # zinc-100 @ 70%
const COLOR_SUN_DASHED = Color("#f4f4f5", 0.3) # zinc-100 @ 30%

# --- Layout Constants ---
const ARC_WIDTH = 44.0
const INNER_EDGE = 160.0
const OUTER_EDGE = INNER_EDGE + ARC_WIDTH * 2.0         # 248
const CIRCLE_RADIUS = 250.0
const HOUSE_W = 120.0
const HOUSE_H = 180.0
const VIEW_ROTATION = -83.0

# Arc center radii (2 bands: today inner, summer/winter outer)
const TODAY_CENTER_R = INNER_EDGE + ARC_WIDTH * 0.5      # 177.5
const SUMMER_CENTER_R = INNER_EDGE + ARC_WIDTH * 1.5     # 212.5

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
	# 1. Summer solstice arc (outer band)
	if summer_sunset_az > summer_sunrise_az:
		var start_angle = _az_to_angle(summer_sunrise_az)
		var end_angle = _az_to_angle(summer_sunset_az)
		draw_arc(Vector2.ZERO, SUMMER_CENTER_R, start_angle, end_angle, 128, COLOR_SUMMER_ARC, ARC_WIDTH, false)

	# 2. Winter solstice arc (overlaid on summer — same radius, shorter span)
	if winter_sunset_az > winter_sunrise_az:
		var start_angle = _az_to_angle(winter_sunrise_az)
		var end_angle = _az_to_angle(winter_sunset_az)
		draw_arc(Vector2.ZERO, SUMMER_CENTER_R, start_angle, end_angle, 128, COLOR_WINTER_ARC, ARC_WIDTH, false)

	# 3. Today's arc (inner band)
	if today_sunset_az > today_sunrise_az:
		var start_angle = _az_to_angle(today_sunrise_az)
		var end_angle = _az_to_angle(today_sunset_az)
		draw_arc(Vector2.ZERO, TODAY_CENTER_R, start_angle, end_angle, 128, COLOR_TODAY_ARC, ARC_WIDTH, false)

	# 4. Overall circle (on top of arcs)
	draw_arc(Vector2.ZERO, CIRCLE_RADIUS, 0, TAU, 128, COLOR_CIRCLE, 10.0, true)

	# 5. Cardinal direction lines (extending slightly outside the circle)
	var cardinal_azimuths = [0.0, 90.0, 180.0, 270.0]  # N, E, S, W
	for az in cardinal_azimuths:
		var p1 = _az_to_xy(az, CIRCLE_RADIUS)
		var p2 = _az_to_xy(az, CIRCLE_RADIUS + 25.0)
		draw_line(p1, p2, COLOR_CARDINAL_LINE, 10.0, true)

	# 6. North label (inside circle)
	var font = ThemeDB.fallback_font
	var font_size = 72
	var n_label_pos = _az_to_xy(0.0, CIRCLE_RADIUS - 50.0)
	var text_size = font.get_string_size("N", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, n_label_pos - Vector2(text_size.x / 2.0, -text_size.y / 4.0), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, COLOR_CARDINAL_LABEL)

	# 7. House rectangle (rotated -90 in local space)
	_draw_house()

	# 8. Sun icon (always visible, dimmed at night)
	_draw_sun()


func _draw_house():
	var house_angle = deg_to_rad(-90.0)
	var hw = HOUSE_W / 2.0
	var hh = HOUSE_H / 2.0
	var stroke_half = 5.0  # half of visual stroke width (10.0)

	# Outer polygon (stroke layer) — expanded to create sharp-cornered border
	var outer_local = [
		Vector2(-hw - stroke_half, -hh - stroke_half),
		Vector2(hw + stroke_half, -hh - stroke_half),
		Vector2(hw + stroke_half, hh + stroke_half),
		Vector2(-hw - stroke_half, hh + stroke_half)
	]
	var outer = PackedVector2Array()
	for c in outer_local:
		outer.append(c.rotated(house_angle))
	draw_colored_polygon(outer, COLOR_HOUSE_STROKE)

	# Inner polygon (fill layer)
	var corners_local = [
		Vector2(-hw, -hh),
		Vector2(hw, -hh),
		Vector2(hw, hh),
		Vector2(-hw, hh)
	]
	var corners = PackedVector2Array()
	for c in corners_local:
		corners.append(c.rotated(house_angle))
	draw_colored_polygon(corners, COLOR_HOUSE_FILL)

	# Door: on the west (left in unrotated space) long wall
	var door_local = [
		Vector2(-hw - 7.0, -15.0),
		Vector2(-hw - 7.0 + 10.0, -15.0),
		Vector2(-hw - 7.0 + 10.0, -15.0 + 30.0),
		Vector2(-hw - 7.0, -15.0 + 30.0)
	]
	var door_outer_local = [
		Vector2(-hw - 7.0 - stroke_half, -15.0 - stroke_half),
		Vector2(-hw - 7.0 + 10.0 + stroke_half, -15.0 - stroke_half),
		Vector2(-hw - 7.0 + 10.0 + stroke_half, -15.0 + 30.0 + stroke_half),
		Vector2(-hw - 7.0 - stroke_half, -15.0 + 30.0 + stroke_half)
	]
	var door_outer = PackedVector2Array()
	for c in door_outer_local:
		door_outer.append(c.rotated(house_angle))
	draw_colored_polygon(door_outer, COLOR_DOOR_STROKE)

	var door_corners = PackedVector2Array()
	for c in door_local:
		door_corners.append(c.rotated(house_angle))
	draw_colored_polygon(door_corners, COLOR_DOOR_FILL)


func _draw_sun():
	var sun_pos = _az_to_xy(sun_azimuth, TODAY_CENTER_R)
	var dim = 1.0 if sun_is_up else 0.3

	# Dashed line from center toward sun — 60% of circle radius, fully opaque
	var line_end = sun_pos.normalized() * CIRCLE_RADIUS * 0.5
	var line_color = Color(COLOR_SUN_DASHED, dim)
	_draw_dashed_line(Vector2.ZERO, line_end, line_color, 10.0, 10.0, 6.0)

	# Semi-transparent black circle behind sun for visibility
	draw_circle(sun_pos, 36.0, Color(0, 0, 0, 0.5 * dim))

	# 8 rays at 45 degree intervals
	var ray_color = Color(COLOR_SUN_RAYS, COLOR_SUN_RAYS.a * dim)
	for i in range(8):
		var ray_angle = deg_to_rad(i * 45.0)
		var ray_start = sun_pos + Vector2(cos(ray_angle), sin(ray_angle)) * 20.0
		var ray_end = sun_pos + Vector2(cos(ray_angle), sin(ray_angle)) * 32.0
		draw_line(ray_start, ray_end, ray_color, 10.0, true)

	# Body circle
	var body_color = Color(COLOR_SUN_BODY, dim)
	draw_circle(sun_pos, 16.0, body_color)

	# Center highlight
	var center_color = Color(COLOR_SUN_CENTER, dim)
	draw_circle(sun_pos, 8.0, center_color)


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
