extends Label


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var time = Time.get_time_dict_from_system()
	var ampm = "AM"
	var hour = time.hour
	if hour >= 12:
		ampm = "PM"
	if hour > 12:
		hour = hour - 12
	self.text = "%d:%02d %s" % [hour, time.minute, ampm]
	
