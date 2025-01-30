extends VBoxContainer
class_name SourceExplorer

var current_path := ""
var current_glyph_editor : GlyphEditor = null


@export var viewer : SourceViewer



func _ready() -> void:
	match viewer.mode:
		SourceViewer.Mode.SELECT:
			%Select.set_pressed_no_signal(true)
		SourceViewer.Mode.CREATE:
			%Create.set_pressed_no_signal(true)
		SourceViewer.Mode.REMOVE:
			%Create.set_pressed_no_signal(true)
	_reload_sources()

func _reload_sources():
	for child in %Thumbnails.get_children():
		%Thumbnails.remove_child(child)
		child.queue_free()
	var sources := Database.sources_db.list_sorted()
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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("lookup_tool"):
		%Selected.grab_focus()
		%Selected.text = ""

func _on_thumb_selected( path: String ):
	viewer.set_source(Database.sources_db.sources.get(path))
	%AspectRatioContainer.ratio = viewer.get_aspect_ratio()
	current_path = path
	%SourceName.text = current_path.get_basename()


func _on_create_pressed() -> void:
	%Create.button_pressed = true
	viewer.mode = SourceViewer.Mode.CREATE

func _on_select_pressed() -> void:
	%Select.button_pressed = true
	viewer.mode = SourceViewer.Mode.SELECT

func _on_erase_pressed() -> void:
	%Erase.button_pressed = true
	viewer.mode = SourceViewer.Mode.REMOVE


func _on_source_viewer_rect_selected(rect: Rect2, id : int) -> void:
	var glyph : Database.Glyph = Database.glyph_get(id)
	var should_create = glyph == null or id == 0
	if should_create:
		glyph = Database.glyph_add()
	glyph.locations_add(current_path, rect)
	viewer.select(glyph.id)
	if should_create:
		(%GlyphEditorContainer.get_child(0) as GlyphEditor)._on_add_definition_pressed()


func _on_source_viewer_glyph_selected(id: int) -> void:
	for child in %GlyphEditorContainer.get_children():
		current_glyph_editor = null
		%GlyphEditorContainer.remove_child(child)
		child.queue_free()
	var glyph = Database.glyph_get(id)
	var glyph_editor : GlyphEditor = preload("uid://bw5ts2cyuaquo").instantiate()
	%GlyphEditorContainer.add_child(glyph_editor)
	current_glyph_editor = glyph_editor
	glyph_editor.glyph = glyph


func _on_source_viewer_glyph_location_removed(id: int, rect: Rect2) -> void:
	var glyph = Database.glyph_get(id)
	glyph.locations_remove_rect(current_path, rect)


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
	%Selected.release_focus()

func _on_glyph_selected( glyph : Database.Glyph):
	if glyph == null:
		return
	viewer.select(glyph.id)

func _on_source_name_text_submitted(new_text: String) -> void:
	_on_rename_pressed()

func _on_rename_pressed() -> void:
	var new_path : String = %SourceName.text + "." + current_path.get_extension()
	if not new_path.is_valid_filename():
		%SourceName.text = current_path.get_basename()
		return
	var err = Database.rename_source(current_path, %SourceName.text + "." + current_path.get_extension() )
	if err != OK:
		%SourceName.text = current_path.get_basename()
		return
	_reload_sources()
	_on_thumb_selected(new_path)


func _on_source_name_text_changed(new_text: String) -> void:
	get_viewport().set_input_as_handled()
func _on_selected_text_changed(new_text: String) -> void:
	get_viewport().set_input_as_handled()
