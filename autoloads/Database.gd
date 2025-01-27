extends Node
class_name RositaDB

const DEFAULT_DB_PATH = "user://database"



### PUBLIC API
@warning_ignore("unused_signal")
signal glyph_added( glyph_id: int )
@warning_ignore("unused_signal")
signal glyph_removed( glyph_id: int, glyph : Glyph)
@warning_ignore("unused_signal")
signal location_added( glyph_id : int, location : Location)
@warning_ignore("unused_signal")
signal location_removed( glyph_id : int, location : Location)
@warning_ignore("unused_signal")
signal meaning_added( glyph_id: int, meaning : String)
@warning_ignore("unused_signal")
signal meaning_removed( glyph_id: int, meaning : String)

## Defines a search query in the glossary
class GlossarySearchQuery extends RefCounted:
	var string : String
	var match_meanings : bool
	var match_all_words : bool
	var match_any_words : bool

class Glyph extends RefCounted:
	signal changed
	var id : int = 0
	var locations : Array[Location]= []
	var meanings : Array[String]= []
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
	func meaning_add( meaning: String ) -> int:
		meanings.append(meaning)
		Database.meaning_added.emit(id, meaning)
		changed.emit()
		return meanings.size() - 1
	func meaning_remove( index : int ) -> bool:
		var success := false
		if index >= 0 and index < meanings.size():
			success = true
			var meaning = meanings.pop_at(index)
			Database.meaning_removed.emit(id, meaning)
			changed.emit()
		return success
	func meaning_edit( index : int, meaning: String ) -> bool:
		var success := false
		if index >= 0 and index < meanings.size():
			var old_meaning = meanings[index]
			meanings[index] = meaning
			Database.meaning_removed.emit(id, old_meaning)
			Database.meaning_added.emit(id, meaning)
			changed.emit()
		return success

class Location extends RefCounted:
	var image_uid : String
	var rect : Rect2i
	func _init(p_image_uid : String, p_rect : Rect2i) -> void:
		assert(p_image_uid.is_absolute_path())
		assert(p_rect.size != Vector2i.ZERO)
		image_uid = p_image_uid
		rect = p_rect

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

## Returns an array of glyph_ids
func glossary_search(query : GlossarySearchQuery) -> Array[Glyph]:
	# TODO
	# if match meanings, match all words, match any words, etc...
	var result : Array[Glyph] = []
	var ids : Array[int] = []
	if query.string.is_empty():
		return glyph_db.get_all()
	query.string = query.string.to_lower()
	if query.match_meanings:
		ids += meaning_db.get_glyph_ids(query.string)
	if query.match_all_words:
		ids += meaning_db.get_glyph_ids_all_words(query.string)
	if query.match_any_words:
		ids += word_db.get_glyph_ids_from_sentece(query.string)
	result = glyph_db.get_from_ids(ids)
	return result

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

func glyph_get(id: int) -> Glyph:
	return glyph_db.get_at(id)

## Implementation
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

class MeaningDB extends RefCounted:
	var meanings : Dictionary[String, Array] = {}
	func _init( glyph_db : GlyphDB):
		Database.meaning_added.connect(_on_meaning_added)
		Database.meaning_removed.connect(_on_meaning_removed)
		for glyph: Glyph in glyph_db.get_all():
			for m in glyph.meanings:
				add_glyph_id(m, glyph.id)
	
	func _on_meaning_added( glyph_id: int, meaning : String):
		add_glyph_id(meaning, glyph_id)
	
	func _on_meaning_removed( glyph_id: int, meaning : String):
		remove_glyph_id(meaning, glyph_id)
	
	func add_glyph_id(key : String, id: int):
		key = key.to_lower()
		if not meanings.has(key):
			var arr : Array[int] = []
			meanings[key] = arr
		if not id in meanings[key]:
			meanings[key].append(id)
	
	func remove_glyph_id(key: String, id: int):
		key = key.to_lower()
		if meanings.has(key):
			var arr : Array[int] = meanings[key]
			arr.erase(id)
			if arr.is_empty():
				meanings.erase(key)
	
	func get_glyph_ids(key: String):
		key = key.to_lower()
		var ret : Array[int] = []
		return meanings.get(key, ret)
	
	func get_glyph_ids_all_words(sentence: String) -> Array[int]:
		var ret : Array[int] = []
		var words : = RositaDB.split_sentence(sentence)

		for m : String in meanings.keys():
			var include := true
			for w in words:
				if not m.containsn(w):
					include = false
					break
			if include:
				ret += get_glyph_ids(m)
		return ret

class WordDB extends RefCounted:
	var words : Dictionary[String, Array] = {}
	func _init( glyph_db : GlyphDB):
		Database.meaning_added.connect(_on_meaning_added)
		Database.meaning_removed.connect(_on_meaning_removed)
		for glyph in glyph_db.get_all():
			for m in glyph.meanings:
				add_sentence(m, glyph.id)

	func _on_meaning_added( glyph_id: int, meaning : String):
		add_sentence(meaning, glyph_id)
	
	func _on_meaning_removed( glyph_id: int, meaning : String):
		remove_sentence(meaning, glyph_id)

	func add_sentence(sentence: String, id: int) -> void:
		var _words : = RositaDB.split_sentence(sentence)
		for word in _words:
			add_glyph_id(word, id)
	
	func remove_sentence(sentence: String, id: int) -> void:
		var _words : = RositaDB.split_sentence(sentence)
		for word in _words:
			remove_glyph_id(word, id)
	
	func get_glyph_ids_from_sentece(sentence: String):
		var ret : Array[int] = []
		var _words : = RositaDB.split_sentence(sentence)
		for word in _words:
			ret += get_glyph_ids(word)
		return ret

	func add_glyph_id(key: String, id: int):
		key = key.to_lower()
		if not words.has(key):
			var arr : Array[int] = []
			words[key] = arr
		if not id in words[key]:
			words[key].append(id)
	
	func remove_glyph_id(key: String, id: int):
		key = key.to_lower()
		if words.has(key):
			var arr : Array[int] = words[key]
			arr.erase(id)
			if arr.is_empty():
				words.erase(key)
	
	func get_glyph_ids(key: String):
		key = key.to_lower()
		return words.get(key, [])


var glyph_db: GlyphDB
var sources_db = {}
var meaning_db: MeaningDB
var word_db : WordDB

func _ready() -> void:
	
	
	glyph_db = GlyphDB.new()
	for i in 20:
		_add_random_glyph()
	meaning_db = MeaningDB.new(glyph_db)
	word_db = WordDB.new(glyph_db)
	for i in 20:
		_add_random_glyph()

static func split_sentence( sentence : String) -> PackedStringArray:
	var regex := RegEx.create_from_string(r"(\b[^\s]+\b)")
	var matches : = regex.search_all(sentence)
	var words : = PackedStringArray()
	if not matches:
		return words
	for m : RegExMatch in matches:
		words.append(m.get_string())
	return words

func _add_random_glyph():
	var lorem_packed := "Lorem ipsum odor amet, consectetuer adipiscing elit. Penatibus etiam lacinia placerat quisque nullam pretium. Tristique bibendum potenti fringilla placerat fusce faucibus vitae nostra nisl. Elementum nascetur aliquam facilisi molestie quisque. Interdum felis eros rhoncus gravida inceptos dis! Eleifend nulla lectus justo duis orci ex; eget turpis a. Pretium augue tristique parturient per fames ad euismod semper. Ex justo fames eleifend rhoncus orci feugiat. Ipsum ultricies orci aenean integer ad purus. Erat habitasse curae egestas orci duis eleifend eleifend. Nostra aptent ad dapibus nunc orci imperdiet condimentum aliquam morbi. Nunc facilisis odio mi, aptent tristique sem sodales. Euismod facilisis suspendisse sit dui curabitur fusce non taciti. Per curae ultricies primis erat egestas sit duis! Conubia litora torquent maximus faucibus class lacinia.".split(" ")
	var lorem : Array = lorem_packed
	var glyph := glyph_add()
	for i in randi_range(1,5):
		var sentence = ""
		for j in randi_range(1, 6):
			sentence += lorem.pick_random() + " "
		glyph.meaning_add(sentence)
