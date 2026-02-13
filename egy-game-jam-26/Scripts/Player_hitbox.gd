extends Area2D


@onready var player: CharacterBody2D = $".."
const DEATH_SPLASH = preload("uid://bgq81csn13n7")
const DEATH_SPLASH_2 = preload("uid://cqdq4q314ddgx")

var respawn_pos : Vector2

func _ready() -> void:
	respawn_pos = player.global_position

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("Kill"):
		die()
	if area.is_in_group("Respawn"):
		respawn_pos = area.global_position

func _on_area_exited(area: Area2D) -> void:
	pass # Replace with function body.


func die():
	$"../Audios/Die".play()
	var death_splash = DEATH_SPLASH.instantiate()
	add_child(death_splash)
	var death_splash2 = DEATH_SPLASH_2.instantiate()
	add_child(death_splash2)
	var tween = get_tree().create_tween().set_trans(Tween.TRANS_CUBIC)
	$"../PlayerVisual".visible = false
	self.set_deferred("monitoring",false)
	tween.tween_property(player,"global_position",respawn_pos,1)
	tween.tween_callback(death_splash2.queue_free)
	tween.tween_callback($"../PlayerVisual".show)
	tween.tween_callback(func():
		self.monitoring = true 
		)
