extends Node3D

@onready var mesh: MeshInstance3D = $MeshInstance3D

func _on_jump_area_player_entered() -> void:
	mesh.scale = mesh.scale * Vector3(1.5,0.5,1.5)

func _process(delta: float) -> void:
	mesh.scale = mesh.scale.lerp(Vector3(4,0.2,4),delta * 10)
