extends Area3D

signal PlayerEntered

@export var JumpForce: float = 30


func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("Player"):
		PlayerEntered.emit()
		area.get_parent().ask_to_jump(JumpForce)
