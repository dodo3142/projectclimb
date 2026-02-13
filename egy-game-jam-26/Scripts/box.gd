extends CharacterBody2D

@export var speed : float = 500

var push_dir : Vector2

func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.is_in_group("Push"):
		push_dir = area.global_position.direction_to(global_position)
		velocity.x = push_dir.x * speed

func _physics_process(delta: float) -> void:
	move_and_slide()
