# Solar Position Chart — Godot Implementation Spec

## Overview

A top-down 2D visualization showing the sun's arc around a house from sunrise to sunset, rendered as a **transparent overlay** on top of existing scene content. Three concentric arcs represent the winter solstice range (innermost), today's sun path (middle), and the summer solstice range (outermost). A sun icon shows the current real-time position of the sun. The whole diagram is rotated so the house's west wall is horizontal (as if viewed from the street).

This is image-only — no UI controls, no stats panel, no legend, no text other than the 4 cardinal letters.

---

## Scene Structure

Single Godot scene using `Node2D` with `_draw()` for the chart. This is a transparent overlay widget embedded in a larger scene. Use a `Timer` child node (5 minute interval) for periodic sun position updates.

**Target screen: 800×400 pixels.** All layout values below are defined in a 600×600 logical coordinate space centered at (300, 300). To fit the 400px height, apply a uniform scale of `0.667` to the node (i.e. `scale = Vector2(0.667, 0.667)`) and position it centered horizontally on screen (`position = Vector2(400, 200)`). This keeps the chart circular at ~400×400, centered in the 800px width.

---

## Constants & Configuration

```
# Location: East Northport, NY
latitude  = 40.85   # degrees north
longitude = -73.32  # degrees west
utc_offset = -5     # EST

# House orientation
house_rotation = -7.0  # degrees from true north (counterclockwise)

# View rotation: the entire diagram is rotated so the house west wall is horizontal
# This equals -(90 + house_rotation) = -83 degrees
view_rotation = -83.0

# Layout (relative to center of widget)
arc_width      = 20.0   # pixels, all three arcs use the same width
inner_edge     = 155.0   # inside edge of winter arc
# winter center = inner_edge + arc_width/2 = 165
# today center  = inner_edge + arc_width * 1.5 = 185
# summer center = inner_edge + arc_width * 2.5 = 205
# outer_edge    = inner_edge + arc_width * 3 = 215
circle_radius  = 220.0   # overall circle, just outside the arcs

house_width    = 80.0    # short side (N/S faces)
house_height   = 120.0   # long side (E/W faces)
```

---

## Solar Math

All angles are in degrees unless noted. Convert to radians for trig.

### Solar Declination
```
declination(day_of_year) = -23.44 * cos(radians(360/365 * (day_of_year + 10)))
```

### Sunrise Azimuth (from north, clockwise)
```
sunrise_az(lat, decl) = acos(sin(decl) / cos(lat))   # in degrees
sunset_az(lat, decl)  = 360 - sunrise_az(lat, decl)
```

### Hour Angle at Sunrise
```
H0(lat, decl) = acos(-tan(lat) * tan(decl))   # in degrees
```

### Equation of Time (minutes)
```
B = radians(360/365 * (day_of_year - 81))
EoT = 9.87 * sin(2*B) - 7.53 * cos(B) - 1.5 * sin(B)
```

### Clock Time → Solar Time (hours)
```
std_meridian = utc_offset * 15   # e.g. -75 for EST
long_correction = 4 * (std_meridian - longitude)   # minutes
solar_hour = clock_hour + (long_correction + EoT) / 60
```

### Solar Azimuth at Hour Angle h
```
sin_alt = sin(lat)*sin(decl) + cos(lat)*cos(decl)*cos(h)
cos_alt = sqrt(1 - sin_alt^2)

sin_az = -sin(h) * cos(decl) / cos_alt
cos_az = (sin(decl) - sin(lat) * sin_alt) / (cos(lat) * cos_alt)

azimuth = atan2(sin_az, cos_az)   # normalize to 0-360
```

### Sun Path (array of azimuths for a given day)
Sample 100+ points from hour angle `-H0` to `+H0`. Each point yields an azimuth via the formula above.

### Current Sun Position
1. Get current clock hour (e.g. 15.5 for 3:30 PM)
2. Convert to solar hour via `clockToSolar()`
3. Compute sunrise/sunset solar hours: `12 ± H0/15`
4. If solar hour is between sunrise and sunset, compute fraction `(solar - sunrise) / (sunset - sunrise)`
5. Index into the sun path array to get current azimuth
6. Plot on the "today" arc radius

---

## Coordinate Mapping

Convert azimuth (degrees from north, clockwise) to 2D position:

```
func az_to_xy(az_deg: float, radius: float, center: Vector2) -> Vector2:
    var angle = deg_to_rad(az_deg - 90.0 + view_rotation)
    return center + Vector2(cos(angle), sin(angle)) * radius
```

The `-90` converts from "north = 0°" to standard math angle. The `view_rotation` of `-83°` rotates everything so the house west wall is horizontal.

---

## Drawing Order (back to front)

1. **Overall circle** — thin stroke, color slate-600 `#475569`, radius = `circle_radius`

2. **Cardinal direction lines** — 4 lines (N/E/S/W) drawn from `inner_edge - 5` to `outer_edge + 5` at their respective azimuths (0°, 90°, 180°, 270°). Color slate-600 `#475569`, 1px. These go BEHIND the arcs.

3. **Summer solstice arc** (outermost) — center radius = `inner_edge + arc_width * 2.5`, stroke width = `arc_width`, butt/flat end caps. Color yellow-300 `#fde047` at 25% opacity. Spans from `sunrise_az(lat, summer_decl)` to `sunset_az(lat, summer_decl)` where `summer_decl = declination(172)`.

4. **Today's arc** (middle) — center radius = `inner_edge + arc_width * 1.5`, stroke width = `arc_width`, butt end caps. Color yellow-300 `#fde047` at 85% opacity. Spans from today's sunrise azimuth to today's sunset azimuth.

5. **Winter solstice arc** (innermost) — center radius = `inner_edge + arc_width * 0.5`, stroke width = `arc_width`, butt end caps. Color blue-400 `#60a5fa` at 35% opacity. Spans from `sunrise_az(lat, winter_decl)` to `sunset_az(lat, winter_decl)` where `winter_decl = declination(356)`.

6. **Cardinal direction labels** — N, E, S, W text at `circle_radius + 16` from center at their respective azimuths. Color slate-400 `#94a3b8`, bold, ~14px equivalent.

7. **House rectangle** — centered, `80 × 120` pixels, rotated `-90°` in local space (which, combined with the view rotation, makes the west wall horizontal with the door facing down/toward the viewer). Fill slate-800 `#1e293b`, stroke slate-500 `#64748b`, 2px, slight corner radius.
   - **Door** — small rectangle on the west (left in local unrotated space) long wall: offset `x = -house_w/2 - 5`, `y = -10`, size `7 × 20`. Fill slate-600 `#475569`, stroke slate-400 `#94a3b8`.

8. **Sun icon** (if sun is up) — placed on the today arc at the current azimuth. No glow effect.
   - Body: circle r=7, fill yellow-300 `#fde047`
   - Center: circle r=3.5, fill yellow-100 `#fef9c3`
   - 8 rays at 45° intervals, lines from r=9 to r=14 from sun center, yellow-300 `#fde047`, 1.5px, 70% opacity
   - Dashed line from house center to sun, yellow-300 `#fde047`, 0.75px, 30% opacity

---

## Arc Drawing in Godot

Godot's `draw_arc()` takes center, radius, start_angle, end_angle, point_count, color, width. To draw the arcs:

1. Convert sunrise/sunset azimuths to canvas angles: `deg_to_rad(az - 90 + view_rotation)`
2. Use `draw_arc()` with enough points (64+) for smooth curves
3. Use flat/butt line ends (Godot default)

Important: the three arcs must visually touch with no gaps. Using the same `arc_width` for all three and spacing their center radii exactly `arc_width` apart achieves this.

---

## Color Palette (Tailwind colors, transparent overlay)

This is rendered as an overlay on top of existing scene content. The background should be **transparent** (`Color(0, 0, 0, 0)`). If legibility is poor against the scene background, fall back to a single semi-transparent slate fill: `slate-800` (`#1e293b`) at ~50% opacity behind the whole widget. Do NOT use separate background and chart background — keep it simple, one layer at most.

| Element | Tailwind | Hex | Opacity |
|---|---|---|---|
| Background | transparent | — | 0% |
| Fallback bg (if needed) | slate-800 | `#1e293b` | 50% |
| Circle / cardinal lines | slate-600 | `#475569` | 100% |
| Cardinal labels | slate-400 | `#94a3b8` | 100% |
| House fill | slate-800 | `#1e293b` | 100% |
| House stroke | slate-500 | `#64748b` | 100% |
| Door fill | slate-600 | `#475569` | 100% |
| Summer arc | yellow-300 | `#fde047` | 25% |
| Today arc | yellow-300 | `#fde047` | 85% |
| Winter arc | blue-400 | `#60a5fa` | 35% |
| Sun body | yellow-300 | `#fde047` | 100% |
| Sun center | yellow-100 | `#fef9c3` | 100% |
| Sun rays | yellow-300 | `#fde047` | 70% |
| Sun dashed line | yellow-300 | `#fde047` | 30% |

---

## Behavior

- On `_ready()`: compute today's date, day of year, and all solar positions. Call `queue_redraw()`.
- Use a `Timer` node set to 300 seconds (5 minutes), connected to a handler that recomputes the current sun position and calls `queue_redraw()`.
- The chart should auto-update at midnight if running continuously (recompute all arcs on date change).
- No UI controls needed — hardcoded to the constants above.
- No legend, labels, stats, or text overlays other than the 4 cardinal direction letters.

---

## Key Reference Values for Testing

For Feb 12, latitude 40.85°N:
- Solar declination ≈ -13.5°
- Sunrise azimuth ≈ ~108° (ESE)
- Sunset azimuth ≈ ~252° (WSW)
- Summer solstice sunrise ≈ ~59° (ENE), sunset ≈ ~301° (WNW)
- Winter solstice sunrise ≈ ~121° (ESE), sunset ≈ ~239° (WSW)

The winter arc should be the shortest (narrowest angular span), today's arc wider, and summer arc the widest.

---

## Reference Implementation

See `sun-position-reference.jsx` for a working React/SVG version of this chart. The Godot implementation should produce visually identical output.