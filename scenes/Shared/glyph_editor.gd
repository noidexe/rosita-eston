extends VBoxContainer
class_name GlyphEditor

var glyph : Database.Glyph:
	set(v):
		glyph = v
		if glyph != null:
			glyph.changed.connect(_update_display)
		_update_display()

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
		child.queue_free()
	if glyph == null:
		%Id.text = str(0)
		%Glyph.texture = null
		return 
	if glyph.is_destroyed:
		queue_free()
		return

	%Id.text = str(glyph.id)
	for i : int in glyph.definitions.size():
		_add_definition(i, glyph.definitions[i])
	if glyph.orphan:
		%Glyph.texture = null
	else:
		var first_location = glyph.locations.front()
		var atlas_tex = AtlasTexture.new()
		atlas_tex.atlas = Database.get_texture(first_location.path)
		atlas_tex.region = first_location.rect
		%Glyph.texture = atlas_tex


func _on_add_definition_pressed() -> void:
	if glyph == null:
		return
	glyph.definition_add("")

func _on_definition_changed(new_def, index):
	if glyph == null:
		return
	glyph.definition_edit(index, new_def)

func _remove_definition(index):
	if glyph == null:
		return
	glyph.definition_remove(index)
