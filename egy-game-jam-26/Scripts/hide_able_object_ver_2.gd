extends StaticBody2D

enum Personality {SAD, ANGRY, HAPPY, LOVE, RANDOM}
@export var ShowPersonality := Personality.SAD

@export_group("References")
@export var collision : CollisionShape2D
@export var sprite : Sprite2D
@export var spikes : Node2D
@export var spikes_collision : CollisionShape2D

@export_group("Personality Colors")
@export var color_sad : Color = Color(0.0, 0.0, 1.0)   # Blue
@export var color_angry : Color = Color(1.0, 0.0, 0.0) # Red
@export var color_happy : Color = Color(0.963, 0.859, 0.0, 1.0) # Green
@export var color_love : Color = Color(1.0, 0.4, 0.7)  # Pink


func _ready() -> void:
	# 1. HANDLE RANDOMNESS
	if ShowPersonality == Personality.RANDOM:
		# Create a list of the 4 valid types
		var valid_options = [Personality.SAD, Personality.ANGRY, Personality.HAPPY, Personality.LOVE]
		# Pick one and overwrite the variable so the rest of the script treats it as that type
		ShowPersonality = valid_options.pick_random()
	
	match ShowPersonality:
		Personality.SAD:
			sprite.modulate = color_sad
			if spikes:
				spikes.modulate = color_sad
		Personality.ANGRY:
			sprite.modulate = color_angry
			if spikes:
				spikes.modulate = color_angry
		Personality.HAPPY:
			sprite.modulate = color_happy
			if spikes:
				spikes.modulate = color_happy
		Personality.LOVE:
			sprite.modulate = color_love
			if spikes:
				spikes.modulate = color_love


func _process(delta: float) -> void:
	# Because we overwrote ShowPersonality in _ready, this logic works automatically!
	if ShowPersonality == GameManger.current_personality:
		collision.disabled = true
		if spikes:
			spikes_collision.disabled = true
	else:
		collision.disabled = false
		if spikes:
			spikes_collision.disabled = false
	
