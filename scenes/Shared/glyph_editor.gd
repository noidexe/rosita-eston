extends VBoxContainer
class_name GlyphEditor

var glyph : Database.Glyph:
	set(v):
		glyph = v
		glyph.changed.connect(_update_display)
		_update_display()

func _add_meaning(index: int, text : String):
	var meaning_editor : MeaningEditor = preload("uid://du8pnwobbthhw").instantiate()
	meaning_editor.set_text(text)
	meaning_editor.remove_requested.connect(_remove_meaning.bind(index))
	meaning_editor.changed.connect(_on_meaning_changed.bind(index))
	%Meanings.add_child(meaning_editor)

func _update_display():
	if glyph == null:
		return 
	if not is_inside_tree():
		await ready
	%Preview.texture = glyph.preview
	%Id.text = str(glyph.id)
	for child : Node in %Meanings.get_children():
		child.queue_free()
	for i : int in glyph.meanings.size():
		_add_meaning(i, glyph.meanings[i])


func _on_add_meaning_pressed() -> void:
	glyph.meaning_add("")

func _on_meaning_changed(new_meaning, index):
	glyph.meaning_edit(index, new_meaning)

func _remove_meaning(index):
	glyph.meaning_remove(index)
