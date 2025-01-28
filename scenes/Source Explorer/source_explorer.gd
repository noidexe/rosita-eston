extends VBoxContainer

var current_path := ""

func _ready() -> void:
	var sources := Database.sources_db.list()
	for source in sources:
		var texture = Database.texture_cache.get_thumbnail(source.path)
		var button := TextureButton.new()
		button.texture_normal = texture
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.ignore_texture_size = true
		button.size_flags_vertical = Control.SIZE_FILL
		button.size_flags_horizontal = Control.SIZE_FILL
		button.custom_minimum_size.x = 200
		%Thumbnails.add_child(button)
		button.pressed.connect(_on_thumb_selected.bind(source.path))


func _on_thumb_selected( path: String ):
	(%Viewport/SubViewport.get_child(0) as SourceViewer).set_source(Database.sources_db.sources.get(path))
	current_path = path


func _on_source_viewer_rect_selected(rect: Rect2) -> void:
	var glyph : Database.Glyph = Database.glyph_add()
	glyph.locations_add(current_path, rect)
