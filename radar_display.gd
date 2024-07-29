extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	print_debug($VideoStreamPlayer.stream)
	print_debug($VideoStreamPlayer)
	update_radar()

func _on_button_pressed():
	$CanvasLayer.hide()


func _on_open_button_pressed():
	$CanvasLayer.show()

func update_radar():
	# Download the latest radar image
	print_debug("Running curl")
	var url = "https://radar.weather.gov/ridge/standard/KOKX_loop.gif"
	var output = []
	var err = OS.execute("curl", ["-O", url], output, true)
	print_debug(err)
	print_debug(output)
	
	# Unload the current video
	#$VideoStreamPlayer.stream = null
	#$CanvasLayer/VideoStreamPlayer2.stream = null
	
	# Run ffmpeg to convert animated gif to ogv
	print_debug("Running ffmpeg...")
	var output2 = []
	var output_filename = "tmp_KOKX_loop_" + Time.get_datetime_string_from_system(true) + ".ogv"
	output_filename = output_filename.replace(":", "")
	output_filename = output_filename.replace("-", "")
	print_debug(output_filename)
	var err2 = OS.execute("ffmpeg", ["-i", "KOKX_loop.gif", "-q:v", "10", "-codec:v", "libtheora", "-y", output_filename], output, true)
	print_debug(err2)
	print_debug(output2)
	

	var stream = VideoStreamTheora.new()
	stream.file = "res://" + output_filename

	$VideoStreamPlayer.stream = stream
	$VideoStreamPlayer.play()
	$CanvasLayer/VideoStreamPlayer2.stream = stream
	$CanvasLayer/VideoStreamPlayer2.play()
	
	#print_debug($VideoStreamPlayer.stream.get_stream())
