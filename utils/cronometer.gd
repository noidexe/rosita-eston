extends RefCounted
class_name Cronometer

var start_time : int
var lap_time : int

# Optionally print a message like "Starting..","Loading", etc.
func _init( message : String = "") -> void:
	start_time = Time.get_ticks_usec()
	lap_time = start_time
	if message:
		print(message)

# Mark a lap and optionally print a message with the lap time
func lap( message : String = ""):
	var new_lap = Time.get_ticks_usec()
	if message:
		_print(new_lap - lap_time, message)
	lap_time = new_lap

# Print a message with the total time since the Cronometer was created
func total( message : String = "Total time: "):
	_print(Time.get_ticks_usec() - start_time, message)
func _print(elapsed: float, message : String):
	var unit : String
	if elapsed < 1000:
		unit = "µs"
	elif elapsed < 1000000:
		elapsed /= 1000
		unit = "ms"
	else:
		elapsed /= 1000000
		unit = "s"
	print(message + " [ %s%s ]" % [elapsed, unit])
