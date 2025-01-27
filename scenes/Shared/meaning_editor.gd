extends HBoxContainer
class_name MeaningEditor

var dirty := false
signal changed(new_text : String)
signal remove_requested()

func set_text(text : String):
	$Text.text = text

func _on_remove_pressed() -> void:
	remove_requested.emit()

func _on_text_text_submitted(new_text: String) -> void:
	dirty = false
	changed.emit(new_text)

func _on_text_text_changed(new_text: String) -> void:
	dirty = true

func _on_text_focus_exited() -> void:
	if dirty:
		changed.emit($Text.text)
