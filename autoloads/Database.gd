extends Node
class_name RositaDB

const DEFAULT_DB_PATH = "user://database"

#[ PUBLIC API ]#

#==[ Signals ]#

@warning_ignore("unused_signal")
signal glyph_added( glyph_id: int )

@warning_ignore("unused_signal")
signal glyph_removed( glyph_id: int, glyph : Glyph)

@warning_ignore("unused_signal")
signal location_added( glyph_id : int, location : Location)

@warning_ignore("unused_signal")
signal location_removed( glyph_id : int, location : Location)

@warning_ignore("unused_signal")
signal definition_added( glyph_id: int, definition : String)

@warning_ignore("unused_signal")
signal definition_removed( glyph_id: int, definition : String)

#==[ Inner Classes ]#

## Defines a search query in the glossary
class GlossarySearchQuery extends RefCounted:
	var string : String
	var perfect_match : bool
	var match_all_words : bool
	var match_any_words : bool


## Data Structure to handle Glyphs
## [br]
## A Glyph is a character or sequence of characters treated as a unit
class Glyph extends RefCounted:
	signal changed
	var id : int = 0 # TODO: Implement NullGlyph extends Glyph with id 0
	var locations : Array[Location]= []
	var definitions : Array[String]= []
	var preview : Texture:
		set(v):
			preview = v
			changed.emit()

	func _init(p_id : int) -> void:
		id = p_id

	func locations_add ( image_uid : String, rect : Rect2 ):
		var location := Location.new(image_uid, rect)
		locations.append(location)
		Database.location_added.emit(id, location)
		changed.emit()

	func locations_remove ( index : int ):
		var location : Location = locations.pop_at( index )
		Database.location_removed.emit(id, location)

	func definition_add( def: String ) -> int:
		definitions.append(def)
		Database.definition_added.emit(id, def)
		changed.emit()
		return definitions.size() - 1

	func definition_remove( index : int ) -> bool:
		var success := false
		if index >= 0 and index < definitions.size():
			success = true
			var def = definitions.pop_at(index)
			Database.definition_removed.emit(id, def)
			changed.emit()
		return success

	func definition_edit( index : int, def: String ) -> bool:
		var success := false
		if index >= 0 and index < definitions.size():
			var removed_def = definitions[index]
			definitions[index] = def
			Database.definition_removed.emit(id, removed_def)
			Database.definition_added.emit(id, def)
			changed.emit()
		return success

## Defines a location.
## [br]
## A "location" is a rectangular section of an image containing a glyph
class Location extends RefCounted:
	var image_uid : String
	var rect : Rect2i
	func _init(p_image_uid : String, p_rect : Rect2i) -> void:
		assert(p_image_uid.is_absolute_path())
		assert(p_rect.size != Vector2i.ZERO)
		image_uid = p_image_uid
		rect = p_rect


#==[ Public Methods ]#

#====[ I/O ]#

## Initializes the database
func db_create() -> Error:
	return ERR_BUG

## Loads the database
func db_load() -> bool:
	var db_path : String = DEFAULT_DB_PATH
	var err : int = ERR_BUG
	if not DirAccess.dir_exists_absolute(db_path):
		err = db_create()
	
	if not err == OK:
		return err
	
	DirAccess.open(db_path)
	err = DirAccess.get_open_error()
	if not err == OK:
		return err
	
	
	return err

## Saves the database
func db_save() -> bool:
	return ERR_BUG

#====[ Search ]#

## Returns an array of glyphs
func glossary_search(query : GlossarySearchQuery) -> Array[Glyph]:
	var result : Array[Glyph] = []
	var ids : Array[int] = []
	if query.string.is_empty():
		return glyph_db.get_all()
	query.string = query.string.to_lower()
	if query.perfect_match:
		ids += definition_db.get_glyph_ids(query.string)
	if query.match_all_words:
		ids += definition_db.get_glyph_ids_wordset(RositaDB.extract_words(query.string))
	if query.match_any_words:
		ids += word_db.get_glyph_ids_from_sentece(query.string)
	result = glyph_db.get_from_ids(ids)
	return result

#====[ Glyph handling ]#

## Adds a glyph to the GlyphDB
func glyph_add() -> Glyph:
	var glyph := glyph_db.create()
	Database.glyph_added.emit(glyph.id)
	return glyph

## Removes a glyph from the GlyphDB
func glyph_remove(id : int) -> bool:
	var removed_glyph : Glyph = glyph_db.get_at(id)
	var success : bool = glyph_db.remove(id)
	if success:
		Database.glyph_removed.emit(id, removed_glyph)
	return success

## Takes an int id and returns a Glyph
func glyph_get(id: int) -> Glyph:
	return glyph_db.get_at(id)

##[ Helper Funcs ]##

static func extract_words( sentence : String) -> PackedStringArray:
	var regex := RegEx.create_from_string(r"(\b[^\s]+\b)")
	var matches : = regex.search_all(sentence)
	var words : = PackedStringArray()
	if not matches:
		return words
	for m : RegExMatch in matches:
		words.append(m.get_string())
	return words


#[ IMPLEMENTATION ]#

## A Database of Glyphs
## [br]
## Main source of truth
class GlyphDB extends RefCounted:
	var glyphs : Array[Glyph] = [Glyph.new(0)]
	var free_ids : Dictionary[int, bool] = {}
	func create() -> Glyph:
		var id : int = _get_free_id()
		var glyph = Glyph.new(id)
		glyphs[id] = glyph
		return glyph
	func remove(id : int) -> bool:
		if not id > 0 and id < glyphs.size():
			return false
		if glyphs[id] == null:
			return false
		glyphs[id] = null
		free_ids[id] = true
		return true
	func get_at(id : int) -> Glyph:
		if not id > 0 and id < glyphs.size():
			return null
		return glyphs[id]
	
	func get_all() -> Array[Glyph]:
		var ret : Array[Glyph] = []
		for glyph in glyphs:
			if glyph == null or glyph.id == 0:
				continue
			ret.append(glyph)
		return ret
	
	func get_from_ids( ids: Array[int]):
		var glyph_set : Dictionary[Glyph, bool] = {}
		var ret : Array[Glyph] = []
		for id in ids:
			var glyph = get_at(id)
			if glyph:
				glyph_set[glyph] = true
		ret = glyph_set.keys()
		return ret
	
	func _get_free_id() -> int:
		var id = -1
		if not free_ids.is_empty():
			id = free_ids.keys().front()
			free_ids.erase(id)
		else:
			id = glyphs.size()
			glyphs.append(null)
		return id


## A database of definitons
## [br]
## Built from GlyphDB. Allows for fast definition->glyphs reverse lookups
class DefinitionDB extends RefCounted:
	var definitions : Dictionary[String, Array] = {}
	func _init( glyph_db : GlyphDB):
		Database.definition_added.connect(_on_definition_added)
		Database.definition_removed.connect(_on_definition_removed)
		for glyph: Glyph in glyph_db.get_all():
			for m in glyph.definitions:
				add_glyph_id(m, glyph.id)
	
	func _on_definition_added( glyph_id: int, def : String):
		add_glyph_id(def, glyph_id)
	
	func _on_definition_removed( glyph_id: int, def : String):
		remove_glyph_id(def, glyph_id)
	
	func add_glyph_id(definition : String, id: int):
		definition = definition.to_lower()
		if not definitions.has(definition):
			var arr : Array[int] = []
			definitions[definition] = arr
		if not id in definitions[definition]:
			definitions[definition].append(id)
	
	func remove_glyph_id(definition: String, id: int):
		definition = definition.to_lower()
		if definitions.has(definition):
			var arr : Array[int] = definitions[definition]
			arr.erase(id)
			if arr.is_empty():
				definitions.erase(definition)
	
	func get_glyph_ids(definition: String):
		definition = definition.to_lower()
		var ret : Array[int] = []
		return definitions.get(definition, ret)
	
	func get_glyph_ids_wordset(words: PackedStringArray) -> Array[int]:
		var ret : Array[int] = []

		for def : String in definitions.keys():
			var include := true
			for word in words:
				if not def.containsn(word):
					include = false
					break
			if include:
				ret += get_glyph_ids(def)
		return ret


## A database of words
## [br]
## Built from GlyphDB. Allows for fast word->glyphs reverse lookups
class WordDB extends RefCounted:
	var words : Dictionary[String, Array] = {}
	func _init( glyph_db : GlyphDB):
		Database.definition_added.connect(_on_definition_added)
		Database.definition_removed.connect(_on_definition_removed)
		for glyph in glyph_db.get_all():
			for def in glyph.definitions:
				add_from_sentence(def, glyph.id)

	func _on_definition_added( glyph_id: int, definition : String):
		add_from_sentence(definition, glyph_id)
	
	func _on_definition_removed( glyph_id: int, definition : String):
		remove_from_sentence(definition, glyph_id)

	func add_from_sentence(sentence: String, id: int) -> void:
		var _words : = RositaDB.extract_words(sentence)
		for word in _words:
			add_glyph_id(word, id)
	
	func remove_from_sentence(sentence: String, id: int) -> void:
		var _words : = RositaDB.extract_words(sentence)
		for word in _words:
			remove_glyph_id(word, id)
	
	func get_glyph_ids_from_sentece(sentence: String):
		var ret : Array[int] = []
		var _words : = RositaDB.extract_words(sentence)
		for word in _words:
			ret += get_glyph_ids(word)
		return ret

	func add_glyph_id(word: String, id: int):
		word = word.to_lower()
		if not words.has(word):
			var arr : Array[int] = []
			words[word] = arr
		if not id in words[word]:
			words[word].append(id)
	
	func remove_glyph_id(word: String, id: int):
		word = word.to_lower()
		if words.has(word):
			var arr : Array[int] = words[word]
			arr.erase(id)
			if arr.is_empty():
				words.erase(word)
	
	func get_glyph_ids(word: String):
		word = word.to_lower()
		return words.get(word, [])


## Active instance of GlyphDB
var glyph_db: GlyphDB

## Active instance of SourcesDB
var sources_db = {}

## Active instance of DefinitionDB
var definition_db: DefinitionDB

## Active instance of WordDB
var word_db : WordDB

func _ready() -> void:
	glyph_db = GlyphDB.new()
	# For testing
	for i in 20:
		_add_random_glyph()
	definition_db = DefinitionDB.new(glyph_db)
	word_db = WordDB.new(glyph_db)
	for i in 20:
		_add_random_glyph()

func _add_random_glyph():
	var lorem_packed := "Lorem ipsum odor amet, consectetuer adipiscing elit. Penatibus etiam lacinia placerat quisque nullam pretium. Tristique bibendum potenti fringilla placerat fusce faucibus vitae nostra nisl. Elementum nascetur aliquam facilisi molestie quisque. Interdum felis eros rhoncus gravida inceptos dis! Eleifend nulla lectus justo duis orci ex; eget turpis a. Pretium augue tristique parturient per fames ad euismod semper. Ex justo fames eleifend rhoncus orci feugiat. Ipsum ultricies orci aenean integer ad purus. Erat habitasse curae egestas orci duis eleifend eleifend. Nostra aptent ad dapibus nunc orci imperdiet condimentum aliquam morbi. Nunc facilisis odio mi, aptent tristique sem sodales. Euismod facilisis suspendisse sit dui curabitur fusce non taciti. Per curae ultricies primis erat egestas sit duis! Conubia litora torquent maximus faucibus class lacinia.".split(" ")
	var lorem : Array = lorem_packed
	var glyph := glyph_add()
	for i in randi_range(1,5):
		var sentence = ""
		for j in randi_range(1, 6):
			sentence += lorem.pick_random() + " "
		glyph.definition_add(sentence)
