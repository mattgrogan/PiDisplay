extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func update(period, temp, temp_label, forecast, detail):
	get_node("Period").text = period.to_upper()
	get_node("Temp").text = temp
	get_node("TempLabel").text = temp_label
	get_node("Forecast").text = forecast
	get_node("ForecastDetailWindow/ScrollContainer/ForecastDetail").text = detail
	#$Detail/DetailedForecast.text = forecast


func _on_close_button_pressed():
	get_node("ForecastDetailWindow").hide()



func _on_open_detail_pressed():
	get_node("ForecastDetailWindow").show()
