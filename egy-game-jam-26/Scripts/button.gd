extends Sprite2D

@export var door : Node2D

func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.is_in_group("Box"):
		if door:
			door.queue_free()
			$Click.play()
