extends VBoxContainer
class_name GlyphEditor

var glyph : Database.Glyph:
	set(v):
		glyph = v
		glyph.changed.connect(_update_display)
		_update_display()

func _add_definition(index: int, text : String):
	var definition_editor : DefinitionEditor = preload("uid://du8pnwobbthhw").instantiate()
	definition_editor.set_text(text)
	definition_editor.remove_requested.connect(_remove_definition.bind(index))
	definition_editor.changed.connect(_on_definition_changed.bind(index))
	%Definitions.add_child(definition_editor)

func _update_display():
	if glyph == null:
		return 
	if glyph.destroyed:
		queue_free()
		return
	if not is_inside_tree():
		await ready
	if is_queued_for_deletion():
		return
	%Id.text = str(glyph.id)
	for child : Node in %Definitions.get_children():
		child.queue_free()
	for i : int in glyph.definitions.size():
		_add_definition(i, glyph.definitions[i])
	var first_location = glyph.locations.front()
	if first_location == null:
		%Glyph.texture = null
	var atlas_tex = AtlasTexture.new()
	atlas_tex.atlas = Database.texture_cache.get_texture(first_location.path)
	atlas_tex.region = first_location.rect
	%Glyph.texture = atlas_tex


func _on_add_definition_pressed() -> void:
	glyph.definition_add("")

func _on_definition_changed(new_def, index):
	glyph.definition_edit(index, new_def)

func _remove_definition(index):
	glyph.definition_remove(index)
