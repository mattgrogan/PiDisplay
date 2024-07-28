extends Label



# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):

	var date = Time.get_date_dict_from_system()
	
	var day_of_week = ""
	match date.weekday:
		Time.Weekday.WEEKDAY_SUNDAY:
			day_of_week = "Sunday"
		Time.Weekday.WEEKDAY_MONDAY:
			day_of_week = "Monday"
		Time.Weekday.WEEKDAY_TUESDAY:
			day_of_week = "Tuesday"
		Time.Weekday.WEEKDAY_WEDNESDAY:
			day_of_week = "Wednesday"
		Time.Weekday.WEEKDAY_THURSDAY:
			day_of_week = "Thursday"
		Time.Weekday.WEEKDAY_FRIDAY:
			day_of_week = "Friday"
		Time.Weekday.WEEKDAY_SATURDAY:
			day_of_week = "Saturday"
			
	var month = ""
	match date.month:
		Time.Month.MONTH_JANUARY:
			month = "January"
		Time.Month.MONTH_FEBRUARY:
			month = "February"
		Time.Month.MONTH_MARCH:
			month = "March"
		Time.Month.MONTH_APRIL:
			month = "April"
		Time.Month.MONTH_MAY:
			month = "May"
		Time.Month.MONTH_JUNE:
			month = "June"
		Time.Month.MONTH_JULY:
			month = "July"
		Time.Month.MONTH_AUGUST:
			month = "August"
		Time.Month.MONTH_SEPTEMBER:
			month = "September"
		Time.Month.MONTH_OCTOBER:
			month = "October"
		Time.Month.MONTH_NOVEMBER:
			month = "November"
		Time.Month.MONTH_DECEMBER:
			month = "December"
						
	self.text = "%s, %s %d" % [day_of_week, month, date.day]
