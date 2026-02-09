extends Area2D

@export var area_pcam: PhantomCamera2D

func _ready() -> void:
	connect("area_entered", _entered_area)
	connect("area_exited", _exited_area)

func _entered_area(area_2d: Area2D) -> void:
	if area_2d.is_in_group("Player"):
		area_pcam.set_priority(20)

func _exited_area(area_2d: Area2D) -> void:
	if area_2d.is_in_group("Player"):
		area_pcam.set_priority(0)
