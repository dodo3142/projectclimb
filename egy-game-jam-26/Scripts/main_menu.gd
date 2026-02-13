extends Node2D

@onready var settings: MarginContainer = $CanvasLayer/Settings



func _on_quit_pressed() -> void:
	GameManger.Start()
	await get_tree().create_timer(0.4).timeout
	get_tree().quit()


func _on_close_pressed() -> void:
	settings.visible = false


func _on_settings_pressed() -> void:
	settings.visible = true


func _on_play_pressed() -> void:
	GameManger.Start()
