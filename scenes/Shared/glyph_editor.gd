extends VBoxContainer
class_name GlyphEditor

var glyph : Database.Glyph:
	set(v):
		glyph = v
		if glyph != null:
			glyph.changed.connect(_update_display)
		_update_display()

func is_editing_definition() -> bool:
	return %Definitions.get_children().any(func(child : DefinitionEditor): return child.get_node("%Text").has_focus() )

func _add_definition(index: int, text : String):
	var definition_editor : DefinitionEditor = preload("uid://du8pnwobbthhw").instantiate()
	definition_editor.set_text(text)
	definition_editor.remove_requested.connect(_remove_definition.bind(index))
	definition_editor.changed.connect(_on_definition_changed.bind(index))
	%Definitions.add_child(definition_editor)

func _update_display():
	if is_queued_for_deletion():
		return
	if not is_inside_tree():
		await ready
	
	for child : Node in %Definitions.get_children():
		%Definitions.remove_child(child)
		child.queue_free()
	if glyph == null:
		%Id.text = str(0)
		%Glyph.texture = null
		return 
	if glyph.is_destroyed:
		queue_free()
		return

	%Id.text = "Id: %s, Locs: %s" % [glyph.id, glyph.locations.size()]
	for i : int in glyph.definitions.size():
		_add_definition(i, glyph.definitions[i])
	if glyph.orphan:
		%Glyph.texture = null
	else:
		%Glyph.texture = Database.glyph_get_texture(glyph)


func _on_add_definition_pressed() -> void:
	if glyph == null:
		return
	glyph.definition_add("")
	%Definitions.get_children().back().focus()

func _on_definition_changed(new_def, index):
	if glyph == null:
		return
	glyph.definition_edit(index, new_def)

func _remove_definition(index):
	if glyph == null:
		return
	glyph.definition_remove(index)
