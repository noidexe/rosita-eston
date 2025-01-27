extends VBoxContainer

signal glyph_selected(glyph: Database.Glyph)

func _on_query_text_submitted(new_text: String) -> void:
	var query = Database.GlossarySearchQuery.new()
	query.string = new_text
	query.match_meanings = %Meanings.button_pressed
	query.match_all_words = %AllWords.button_pressed
	query.match_any_words = %AnyWords.button_pressed
	var result = Database.glossary_search(query)
	clear()
	for glyph in result:
		add_entry(glyph)

func clear():
	for child in %SearchResults.get_children():
		child.queue_free()
	for child in %Details.get_children():
		child.queue_free()

func add_entry(glyph : Database.Glyph):
	var glyph_entry = preload("uid://cwp60k603jkko").instantiate()
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


func _on_meanings_toggled(_toggled_on: bool) -> void:
	_on_query_text_submitted(%Query.text)


func _on_all_words_toggled(_toggled_on: bool) -> void:
	_on_query_text_submitted(%Query.text)


func _on_any_words_toggled(_toggled_on: bool) -> void:
	_on_query_text_submitted(%Query.text)
