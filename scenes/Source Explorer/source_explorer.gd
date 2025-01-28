extends VBoxContainer
class_name SourceExplorer

var current_path := ""

@export var viewer : SourceViewer

func _ready() -> void:
	match viewer.mode:
		SourceViewer.Mode.SELECT:
			%Select.set_pressed_no_signal(true)
		SourceViewer.Mode.CREATE:
			%Create.set_pressed_no_signal(true)
		SourceViewer.Mode.REMOVE:
			%Create.set_pressed_no_signal(true)
	var sources := Database.sources_db.list()
	for source in sources:
		var texture = Database.get_thumbnail(source)
		var button := TextureButton.new()
		button.texture_normal = texture
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.ignore_texture_size = true
		button.size_flags_vertical = Control.SIZE_FILL
		button.size_flags_horizontal = Control.SIZE_FILL
		button.custom_minimum_size.x = 200
		%Thumbnails.add_child(button)
		button.pressed.connect(_on_thumb_selected.bind(source.path))
	if not sources.is_empty():
		_on_thumb_selected(sources.front().path)


func _on_thumb_selected( path: String ):
	viewer.set_source(Database.sources_db.sources.get(path))
	%AspectRatioContainer.ratio = viewer.get_aspect_ratio()
	current_path = path


func _on_create_pressed() -> void:
	viewer.mode = SourceViewer.Mode.CREATE

func _on_select_pressed() -> void:
	viewer.mode = SourceViewer.Mode.SELECT

func _on_erase_pressed() -> void:
	viewer.mode = SourceViewer.Mode.REMOVE


func _on_source_viewer_rect_selected(rect: Rect2, id : int) -> void:
	var glyph : Database.Glyph = Database.glyph_get(id) if id != 0 else Database.glyph_add()
	glyph.locations_add(current_path, rect)
	viewer.select(glyph.id)


func _on_source_viewer_glyph_selected(id: int) -> void:
	for child in %GlyphEditorContainer.get_children():
		child.queue_free()
	var glyph = Database.glyph_get(id)
	var glyph_editor : GlyphEditor = preload("uid://bw5ts2cyuaquo").instantiate()
	%GlyphEditorContainer.add_child(glyph_editor)
	glyph_editor.glyph = glyph


func _on_source_viewer_glyph_location_removed(id: int, rect: Rect2) -> void:
	var glyph = Database.glyph_get(id)
	glyph.locations_remove_rect(rect)


func _on_next_pressed() -> void:
	var next = wrapi(viewer.selected+1, 0, Database.glyph_count())
	viewer.select(next)
	%Selected.text = str(next)


func _on_prev_pressed() -> void:
	var prev = wrapi(viewer.selected-1, 0, Database.glyph_count())
	viewer.select(prev)
	%Selected.text = str(prev)


func _on_selected_text_submitted(new_text: String) -> void:
	var id = 0
	if new_text.is_valid_int():
		id = wrapi(int(new_text), 0, Database.glyph_count())
	else:
		var query := Database.GlossarySearchQuery.new()
		query.string = new_text
		query.perfect_match = true
		var result = Database.glossary_search(query)
		if not result.is_empty():
			id = result.front().id
	viewer.select(id)
	%Selected.text = str(id)

func _on_glyph_selected( glyph : Database.Glyph):
	if glyph == null:
		return
	viewer.select(glyph.id)
