extends HSlider

@export var bus_name: String = "Master"

var _bus_index: int

func _ready() -> void:
	_bus_index = AudioServer.get_bus_index(bus_name)
	if _bus_index == -1:
		return
	
	# CHANGED: Instead of reading the volume, we APPLY the slider's
	# current value to the audio bus immediately.
	_on_value_changed(value)
	
	# Connect the signal so it keeps updating when you drag it
	value_changed.connect(_on_value_changed)

func _on_value_changed(new_value: float) -> void:
	AudioServer.set_bus_volume_db(_bus_index, linear_to_db(new_value))
