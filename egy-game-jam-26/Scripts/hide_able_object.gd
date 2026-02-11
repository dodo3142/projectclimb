extends StaticBody2D

enum Personality {SAD, ANGRY, HAPPY, LOVE, RANDOM}
@export var ShowPersonality := Personality.SAD

@export_group("References")
@export var collision : CollisionShape2D
@export var sprite : Sprite2D

@export_group("Personality Colors")
@export var color_sad : Color = Color(0.0, 0.0, 1.0)   # Blue
@export var color_angry : Color = Color(1.0, 0.0, 0.0) # Red
@export var color_happy : Color = Color(0.963, 0.859, 0.0, 1.0) # Green
@export var color_love : Color = Color(1.0, 0.4, 0.7)  # Pink

# Preloaded Shader Files (.gdshader)
const ANGRY_OUT_LINE = preload("uid://cbeukll1ny1dr")
const HAPPY_OUT_LINE = preload("uid://littsc76xsrx")
const LOVE_OUT_LINE = preload("uid://c68trupi0dda8")
const SAD_OUT_LINE = preload("uid://bay8a8dtroe88")

func _ready() -> void:
	# 1. HANDLE RANDOMNESS
	if ShowPersonality == Personality.RANDOM:
		# Create a list of the 4 valid types
		var valid_options = [Personality.SAD, Personality.ANGRY, Personality.HAPPY, Personality.LOVE]
		# Pick one and overwrite the variable so the rest of the script treats it as that type
		ShowPersonality = valid_options.pick_random()

	# 2. SETUP MATERIAL
	if sprite.material:
		sprite.material = sprite.material.duplicate()
	
	# 3. APPLY SHADER AND COLOR BASED ON THE (POSSIBLY RANDOMIZED) SELECTION
	match ShowPersonality:
		Personality.SAD:
			sprite.modulate = color_sad
			sprite.material.shader = SAD_OUT_LINE
			sprite.material.set_shader_parameter("color", color_sad)
			
		Personality.ANGRY:
			sprite.modulate = color_angry
			sprite.material.shader = ANGRY_OUT_LINE
			sprite.material.set_shader_parameter("color", color_angry)
			
		Personality.HAPPY:
			sprite.modulate = color_happy
			sprite.material.shader = HAPPY_OUT_LINE
			sprite.material.set_shader_parameter("color", color_happy)
			
		Personality.LOVE:
			sprite.modulate = color_love
			sprite.material.shader = LOVE_OUT_LINE
			sprite.material.set_shader_parameter("color", color_love)

func _process(delta: float) -> void:
	# Because we overwrote ShowPersonality in _ready, this logic works automatically!
	if ShowPersonality == GameManger.current_personality:
		collision.disabled = true
	else:
		collision.disabled = false
	
