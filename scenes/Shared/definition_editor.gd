extends HBoxContainer
class_name DefinitionEditor

var dirty := true
signal changed(new_text : String)
signal remove_requested()

func set_text(text : String):
	$Text.text = text

func focus():
	$Text.grab_focus()

func _on_remove_pressed() -> void:
	remove_requested.emit()

func _on_text_text_submitted(new_text: String) -> void:
	dirty = false
	_validate_definition()

func _on_text_text_changed(_new_text: String) -> void:
	dirty = true

func _on_text_focus_exited() -> void:
	if dirty:
		_on_text_text_submitted($Text.text)

func _validate_definition():
	if ($Text.text as String).is_empty():
		remove_requested.emit()
	else:
		changed.emit($Text.text)
