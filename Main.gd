extends Node

# Handle input for closing the application
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			print_debug("ESC pressed - closing application")
			get_tree().quit()
