extends Node

func _ready():
	# Set the window to fullscreen mode
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

# Handle input for closing the application and toggling fullscreen
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			print_debug("ESC pressed - closing application")
			get_tree().quit()
		elif event.keycode == KEY_F11:
			toggle_fullscreen()

func toggle_fullscreen():
	var current_mode = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		print_debug("F11 pressed - switching to windowed mode")
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		print_debug("F11 pressed - switching to fullscreen mode")
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
