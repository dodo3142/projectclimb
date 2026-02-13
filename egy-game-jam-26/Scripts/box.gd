extends CharacterBody2D

@export var speed : float = 500
@export var gravity : float = 500
var push_dir : Vector2

func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.is_in_group("Push"):
		$Hit.play()
		push_dir = area.global_position.direction_to(global_position)
		velocity.x = push_dir.x * speed

func _physics_process(delta: float) -> void:
	velocity.y += gravity * delta
	if is_equal_approx(velocity.x,0):
		push_dir.x = 0
	move_and_slide()
