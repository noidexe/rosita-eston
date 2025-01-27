extends VBoxContainer
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
	if event is InputEventMouseButton and event.is_pressed():
		selected.emit()

func _update_display():
	if glyph == null:
		return
	if not is_inside_tree():
		await ready
	%Id.text = str(glyph.id).pad_zeros(5)
	%Definitions.text = str(glyph.definitions)
	var first_location = glyph.locations.front()
	if first_location == null:
		%Glyph.texture = null
	var atlas_tex = AtlasTexture.new()
	atlas_tex.atlas = Database.texture_cache.get_texture(first_location.path)
	atlas_tex.region = first_location.rect
	%Glyph.texture = atlas_tex
