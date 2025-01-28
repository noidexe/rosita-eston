extends TextureRect

signal selected()

func _on_gui_input(event: InputEvent) -> void:
	if event.is_pressed() and event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		selected.emit()
	pass # Replace with function body.
