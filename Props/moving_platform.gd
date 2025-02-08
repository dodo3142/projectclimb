extends Path3D

@export var Loop: bool = true
@export var Speed: float = 2
@export var SpeedScale: float = 1

@onready var PathPos: PathFollow3D = $PathFollow3D
@onready var AnimPlayer: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	if not Loop:
		AnimPlayer.play("Moving")
		AnimPlayer.speed_scale = SpeedScale
		set_process(false)

func _process(delta: float) -> void:
	PathPos.progress += Speed
