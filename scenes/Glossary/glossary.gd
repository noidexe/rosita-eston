extends VBoxContainer

signal glyph_selected(glyph: Database.Glyph)

func _on_query_text_submitted(new_text: String) -> void:
	var query := Database.GlossarySearchQuery.new()
	query.string = new_text
	query.perfect_match = %Perfect.button_pressed
	query.match_all_words = %AllWords.button_pressed
	query.match_any_words = %AnyWords.button_pressed
	var result := Database.glossary_search(query)
	clear()
	for glyph in result:
		add_entry(glyph)

func clear():
	for child in %SearchResults.get_children():
		child.queue_free()
	for child in %Details.get_children():
		child.queue_free()

func add_entry(glyph : Database.Glyph):
	var glyph_entry : GlyphEntry = preload("uid://cwp60k603jkko").instantiate()
	%SearchResults.add_child(glyph_entry)
	glyph_entry.glyph = glyph
	glyph_entry.selected.connect(edit_entry.bind(glyph))

func edit_entry(glyph : Database.Glyph):
	for child in %Details.get_children():
		child.queue_free()
	var glyph_editor : GlyphEditor = preload("uid://bw5ts2cyuaquo").instantiate()
	%Details.add_child(glyph_editor)
	glyph_editor.glyph = glyph
	glyph_selected.emit(glyph)
	for child in %Sources.get_children():
		child.queue_free()
	var used_paths := []
	for location in glyph.locations:
		if location.path in used_paths:
			continue
		used_paths.append(location.path)
		var texture = TextureRect.new()
		texture.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture.size_flags_horizontal = Control.SIZE_FILL
		texture.size_flags_horizontal = Control.SIZE_FILL
		texture.texture = Database.texture_cache.get_thumbnail(location.path)
		%Sources.add_child(texture)

func _on_perfect_toggled(_toggled_on: bool) -> void:
	_on_query_text_submitted(%Query.text)


func _on_all_words_toggled(_toggled_on: bool) -> void:
	_on_query_text_submitted(%Query.text)


func _on_any_words_toggled(_toggled_on: bool) -> void:
	_on_query_text_submitted(%Query.text)
