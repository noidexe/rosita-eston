extends PanelContainer
class_name GlyphEntry

signal selected()

var glyph : Database.Glyph:
	set(v):
		glyph = v
		glyph.changed.connect(_update_display)
		_update_display()

func _ready() -> void:
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed() and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		selected.emit()

func _update_display():
	if is_queued_for_deletion():
		return
	if not is_inside_tree():
		await ready
	if glyph == null:
		return
	if glyph.is_destroyed:
		queue_free()
		return
	%Id.text = str(glyph.id).pad_zeros(5)
	var defs_text = "[ORPHAN!]" if glyph.orphan else ""
	for def in glyph.definitions:
		defs_text += def
		defs_text += ", "
	defs_text = defs_text.trim_suffix(", ")
	%Definitions.text = defs_text
	if glyph.orphan:
		%Glyph.texture = null
	else:
		var first_location = glyph.locations.front()
		var atlas_tex = AtlasTexture.new()
		atlas_tex.atlas = Database.get_texture(first_location.path)
		atlas_tex.region = first_location.rect
		%Glyph.texture = atlas_tex
