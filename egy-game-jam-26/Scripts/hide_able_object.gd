extends StaticBody2D

enum Personality {SAD,ANGRY,HAPPY,LOVE}
@export var ShowPersonality := Personality.SAD

@export var collision : CollisionShape2D

func _process(delta: float) -> void:
	if ShowPersonality == GameManger.current_personality:
		collision.disabled = false
	else:
		collision.disabled = true
