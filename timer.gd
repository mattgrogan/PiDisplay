extends Node2D

enum TimerState { IDLE, RUNNING, PAUSED, COMPLETE, OVERTIME }

# Hold timing constants
const HOLD_INITIAL_DELAY = 0.5  # Seconds before auto-repeat starts
const HOLD_REPEAT_SLOW = 0.2    # Initial repeat interval (5/sec)
const HOLD_REPEAT_FAST = 0.05   # Fast repeat interval (20/sec)
const HOLD_ACCEL_THRESHOLD = 2.0  # Seconds until max speed

var current_state = TimerState.IDLE
var time_remaining = 0  # In seconds
var original_time = 0   # Store for reset
var overtime_elapsed = 0
var alert_playing = false
var alert_beeps_remaining = 0  # Number of beeps left to play
var alert_beep_timer = 0.0  # Time until next beep
var alert_tween: Tween = null  # Store tween reference to kill it when needed
var alert_tween_main: Tween = null  # Tween for main screen alert flash

# Time picker values
var hours = 0
var minutes = 0
var seconds = 0

# Hold-to-increment state
var button_hold_state = {
	"active": false,
	"button_type": "",  # "hours_up", "hours_down", etc.
	"hold_time": 0.0,
	"last_increment": 0.0
}

func _ready():
	# Hide overlay and main display initially
	$TimerOverlay.hide()
	$MainScreenDisplay.hide()

	# Connect all button signals
	$TimerButton.pressed.connect(_on_timer_button_pressed)
	$MainScreenDisplay/OpenButton.pressed.connect(_on_main_display_pressed)
	$MainScreenDisplay/CancelButton.pressed.connect(_on_cancel_pressed)
	$TimerOverlay/CloseButton.pressed.connect(_on_close_overlay_pressed)

	# Connect preset buttons
	$TimerOverlay/PresetContainer/Preset1m.pressed.connect(func(): set_preset(1))
	$TimerOverlay/PresetContainer/Preset5m.pressed.connect(func(): set_preset(5))
	$TimerOverlay/PresetContainer/Preset10m.pressed.connect(func(): set_preset(10))
	$TimerOverlay/PresetContainer/Preset20m.pressed.connect(func(): set_preset(20))
	$TimerOverlay/PresetContainer/Preset25m.pressed.connect(func(): set_preset(25))
	$TimerOverlay/PresetContainer/Preset30m.pressed.connect(func(): set_preset(30))

	# Connect time picker buttons (button_down and button_up for hold detection)
	var hours_up = $TimerOverlay/TimePickerContainer/HoursGroup/HoursUpButton
	hours_up.button_down.connect(func():
		increment_hours()
		_start_button_hold("hours_up")
	)
	hours_up.button_up.connect(_stop_button_hold)

	var hours_down = $TimerOverlay/TimePickerContainer/HoursGroup/HoursDownButton
	hours_down.button_down.connect(func():
		decrement_hours()
		_start_button_hold("hours_down")
	)
	hours_down.button_up.connect(_stop_button_hold)

	var minutes_up = $TimerOverlay/TimePickerContainer/MinutesGroup/MinutesUpButton
	minutes_up.button_down.connect(func():
		increment_minutes()
		_start_button_hold("minutes_up")
	)
	minutes_up.button_up.connect(_stop_button_hold)

	var minutes_down = $TimerOverlay/TimePickerContainer/MinutesGroup/MinutesDownButton
	minutes_down.button_down.connect(func():
		decrement_minutes()
		_start_button_hold("minutes_down")
	)
	minutes_down.button_up.connect(_stop_button_hold)

	var seconds_up = $TimerOverlay/TimePickerContainer/SecondsGroup/SecondsUpButton
	seconds_up.button_down.connect(func():
		increment_seconds()
		_start_button_hold("seconds_up")
	)
	seconds_up.button_up.connect(_stop_button_hold)

	var seconds_down = $TimerOverlay/TimePickerContainer/SecondsGroup/SecondsDownButton
	seconds_down.button_down.connect(func():
		decrement_seconds()
		_start_button_hold("seconds_down")
	)
	seconds_down.button_up.connect(_stop_button_hold)

	# Connect control buttons
	$TimerOverlay/ControlContainer/StartButton.pressed.connect(toggle_timer)
	$TimerOverlay/ControlContainer/ResetButton.pressed.connect(reset_timer)

	# Connect countdown timer
	$TimerOverlay/CountdownTimer.timeout.connect(_on_countdown_tick)

	_update_picker_display()
	_update_display()

func _process(delta):
	# Handle alert flashing and sound (repeat 10 times)
	if alert_playing:
		alert_beep_timer -= delta
		if alert_beep_timer <= 0 and alert_beeps_remaining > 0:
			$TimerOverlay/AlertSound.play()
			alert_beeps_remaining -= 1
			alert_beep_timer = 5.0  # 5 seconds between beeps

		# Stop alert when all beeps are done
		if alert_beeps_remaining <= 0 and not $TimerOverlay/AlertSound.playing:
			_stop_alert()

	# Hold-to-increment handling
	if button_hold_state.active:
		_process_button_hold(delta)

func _process_button_hold(delta):
	button_hold_state.hold_time += delta

	# Wait for initial delay before starting auto-repeat
	if button_hold_state.hold_time < HOLD_INITIAL_DELAY:
		return

	# Calculate repeat interval based on hold duration (acceleration)
	var repeat_interval = HOLD_REPEAT_SLOW
	if button_hold_state.hold_time > HOLD_ACCEL_THRESHOLD:
		repeat_interval = HOLD_REPEAT_FAST
	else:
		# Linear interpolation between slow and fast
		var accel_progress = (button_hold_state.hold_time - HOLD_INITIAL_DELAY) / (HOLD_ACCEL_THRESHOLD - HOLD_INITIAL_DELAY)
		repeat_interval = lerp(HOLD_REPEAT_SLOW, HOLD_REPEAT_FAST, accel_progress)

	# Check if enough time has passed for next increment
	if button_hold_state.hold_time - button_hold_state.last_increment >= repeat_interval:
		button_hold_state.last_increment = button_hold_state.hold_time
		_execute_button_action(button_hold_state.button_type)

func _execute_button_action(button_type: String):
	match button_type:
		"hours_up": increment_hours()
		"hours_down": decrement_hours()
		"minutes_up": increment_minutes()
		"minutes_down": decrement_minutes()
		"seconds_up": increment_seconds()
		"seconds_down": decrement_seconds()

func _start_button_hold(button_type: String):
	button_hold_state.active = true
	button_hold_state.button_type = button_type
	button_hold_state.hold_time = 0.0
	button_hold_state.last_increment = 0.0

func _stop_button_hold():
	button_hold_state.active = false
	button_hold_state.button_type = ""
	button_hold_state.hold_time = 0.0
	button_hold_state.last_increment = 0.0

func _stop_alert():
	alert_playing = false
	alert_beeps_remaining = 0
	$TimerOverlay/AlertSound.stop()
	# Kill the tweens if they're still running
	if alert_tween != null and alert_tween.is_valid():
		alert_tween.kill()
	if alert_tween_main != null and alert_tween_main.is_valid():
		alert_tween_main.kill()
	$TimerOverlay/AlertFlash.modulate.a = 0
	$MainScreenDisplay/AlertFlash.modulate.a = 0

func _on_timer_button_pressed():
	$TimerOverlay.show()

func _on_main_display_pressed():
	# If alert is playing or timer is in overtime, reset everything
	if alert_playing or current_state == TimerState.OVERTIME:
		reset_timer()
	else:
		$TimerOverlay.show()

func _on_close_overlay_pressed():
	$TimerOverlay.hide()

func _on_cancel_pressed():
	# If alert is playing, just stop it
	if alert_playing:
		_stop_alert()
	else:
		reset_timer()

func set_preset(preset_minutes):
	time_remaining = preset_minutes * 60
	original_time = time_remaining
	current_state = TimerState.IDLE
	_sync_picker_from_time()
	_update_display()

# Time picker increment/decrement functions
func increment_hours():
	hours = min(hours + 1, 99)
	_update_time_from_picker()

func decrement_hours():
	hours = max(hours - 1, 0)
	_update_time_from_picker()

func increment_minutes():
	minutes += 1
	if minutes > 59:
		minutes = 0
		increment_hours()
	else:
		_update_time_from_picker()

func decrement_minutes():
	minutes -= 1
	if minutes < 0:
		if hours > 0:
			minutes = 59
			decrement_hours()
		else:
			minutes = 0
			_update_time_from_picker()
	else:
		_update_time_from_picker()

func increment_seconds():
	seconds += 1
	if seconds > 59:
		seconds = 0
		increment_minutes()
	else:
		_update_time_from_picker()

func decrement_seconds():
	seconds -= 1
	if seconds < 0:
		if minutes > 0 or hours > 0:
			seconds = 59
			decrement_minutes()
		else:
			seconds = 0
			_update_time_from_picker()
	else:
		_update_time_from_picker()

func _update_time_from_picker():
	time_remaining = hours * 3600 + minutes * 60 + seconds
	original_time = time_remaining
	_update_picker_display()
	_update_display()

func _update_picker_display():
	$TimerOverlay/TimePickerContainer/HoursGroup/HoursLabel.text = "%02d" % hours
	$TimerOverlay/TimePickerContainer/MinutesGroup/MinutesLabel.text = "%02d" % minutes
	$TimerOverlay/TimePickerContainer/SecondsGroup/SecondsLabel.text = "%02d" % seconds

func _sync_picker_from_time():
	hours = time_remaining / 3600
	minutes = (time_remaining % 3600) / 60
	seconds = time_remaining % 60
	_update_picker_display()

func toggle_timer():
	if current_state == TimerState.IDLE:
		if time_remaining > 0:
			start_timer()
			$TimerOverlay/ControlContainer/StartButton.text = "PAUSE"
	elif current_state == TimerState.RUNNING:
		pause_timer()
		$TimerOverlay/ControlContainer/StartButton.text = "RESUME"
	elif current_state == TimerState.PAUSED:
		current_state = TimerState.RUNNING
		$TimerOverlay/CountdownTimer.start()
		$TimerOverlay/ControlContainer/StartButton.text = "PAUSE"
		_update_display()

func start_timer():
	if time_remaining > 0:
		current_state = TimerState.RUNNING
		$TimerOverlay/CountdownTimer.start()
		$MainScreenDisplay.show()
		$TimerOverlay.hide()  # Close overlay and return to main screen
		_set_picker_buttons_enabled(false)
		_update_display()

func pause_timer():
	if current_state == TimerState.RUNNING:
		current_state = TimerState.PAUSED
		$TimerOverlay/CountdownTimer.stop()
		_update_display()

func _set_picker_buttons_enabled(enabled: bool):
	$TimerOverlay/TimePickerContainer/HoursGroup/HoursUpButton.disabled = !enabled
	$TimerOverlay/TimePickerContainer/HoursGroup/HoursDownButton.disabled = !enabled
	$TimerOverlay/TimePickerContainer/MinutesGroup/MinutesUpButton.disabled = !enabled
	$TimerOverlay/TimePickerContainer/MinutesGroup/MinutesDownButton.disabled = !enabled
	$TimerOverlay/TimePickerContainer/SecondsGroup/SecondsUpButton.disabled = !enabled
	$TimerOverlay/TimePickerContainer/SecondsGroup/SecondsDownButton.disabled = !enabled

func reset_timer():
	current_state = TimerState.IDLE
	time_remaining = 0
	original_time = 0
	overtime_elapsed = 0
	hours = 0
	minutes = 0
	seconds = 0
	$TimerOverlay/CountdownTimer.stop()
	$MainScreenDisplay.hide()
	_stop_alert()
	$TimerOverlay/ControlContainer/StartButton.text = "START"
	_set_picker_buttons_enabled(true)
	_update_picker_display()
	_update_display()

func _on_countdown_tick():
	if current_state == TimerState.RUNNING:
		time_remaining -= 1
		if time_remaining <= 0:
			time_remaining = 0
			_on_timer_complete()
		_update_display()
	elif current_state == TimerState.OVERTIME:
		overtime_elapsed += 1
		_update_display()

func _on_timer_complete():
	current_state = TimerState.COMPLETE
	_flash_alert()
	_play_sound()
	# Switch to overtime mode
	current_state = TimerState.OVERTIME
	overtime_elapsed = 0
	_update_display()

func _flash_alert():
	alert_playing = true
	alert_beeps_remaining = 10  # Play 10 beeps
	alert_beep_timer = 0.0  # Start immediately
	# Kill any existing tweens first
	if alert_tween != null and alert_tween.is_valid():
		alert_tween.kill()
	if alert_tween_main != null and alert_tween_main.is_valid():
		alert_tween_main.kill()
	# Create new tween for overlay and store reference
	alert_tween = create_tween()
	alert_tween.tween_property($TimerOverlay/AlertFlash, "modulate:a", 0.5, 0.3)
	alert_tween.tween_property($TimerOverlay/AlertFlash, "modulate:a", 0.0, 0.3)
	alert_tween.set_loops(80)  # Flash for ~50 seconds (matches 10 beeps @ 5 sec each)
	# Create new tween for main screen display
	alert_tween_main = create_tween()
	alert_tween_main.tween_property($MainScreenDisplay/AlertFlash, "modulate:a", 0.5, 0.3)
	alert_tween_main.tween_property($MainScreenDisplay/AlertFlash, "modulate:a", 0.0, 0.3)
	alert_tween_main.set_loops(80)

func _play_sound():
	# Deprecated - sound now plays via _process loop
	pass

func _update_display():
	var display_text = ""
	var text_color = Color(1, 1, 1)  # White

	if current_state == TimerState.IDLE:
		var h = time_remaining / 3600
		var m = (time_remaining % 3600) / 60
		var s = time_remaining % 60
		display_text = "%02d:%02d:%02d" % [h, m, s]
	elif current_state == TimerState.RUNNING or current_state == TimerState.PAUSED:
		var h = time_remaining / 3600
		var m = (time_remaining % 3600) / 60
		var s = time_remaining % 60
		display_text = "%02d:%02d:%02d" % [h, m, s]
		$MainScreenDisplay.show()
	elif current_state == TimerState.OVERTIME:
		var h = overtime_elapsed / 3600
		var m = (overtime_elapsed % 3600) / 60
		var s = overtime_elapsed % 60
		display_text = "-%02d:%02d:%02d" % [h, m, s]
		text_color = Color(0.9, 0.1, 0.1)  # Red
		$MainScreenDisplay.show()

	# Update overlay display
	$TimerOverlay/TimeDisplay.text = display_text
	$TimerOverlay/TimeDisplay.add_theme_color_override("font_color", text_color)

	# Update main screen display
	$MainScreenDisplay/TimerLabel.text = display_text
	$MainScreenDisplay/TimerLabel.add_theme_color_override("font_color", text_color)

	# Show/hide main display based on state
	if current_state == TimerState.IDLE and time_remaining == 0:
		$MainScreenDisplay.hide()
