extends Node2D

signal menu_button_pressed


func _on_button_pressed() -> void:
	emit_signal("menu_button_pressed")
