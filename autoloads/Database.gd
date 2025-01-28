extends Node
class_name RositaDB

const DEFAULT_DB_PATH = "user://database"
const GLYPH_DB_FILENAME = "glyph_db.json"
const SOURCE_DB_FOLDER = "sources"

#[ PUBLIC API ]#

#==[ Signals ]#

@warning_ignore("unused_signal")
signal glyph_added( glyph_id: int )

@warning_ignore("unused_signal")
signal glyph_removed( glyph_id: int, glyph : Glyph)

@warning_ignore("unused_signal")
signal glyph_modified( glyph_id: int)

@warning_ignore("unused_signal")
signal location_added( glyph_id : int, location : Location)

@warning_ignore("unused_signal")
signal location_removed( glyph_id : int, location : Location)

@warning_ignore("unused_signal")
signal definition_added( glyph_id: int, definition : String)

@warning_ignore("unused_signal")
signal definition_removed( glyph_id: int, definition : String)

@warning_ignore("unused_signal")
signal save_started()
@warning_ignore("unused_signal")
signal save_complete()


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
	var destroyed := false
	var orphan : bool:
		set(v):
			push_error("Read-only")
		get():
			return locations.is_empty()
	var id : int = 0 # TODO: Implement NullGlyph extends Glyph with id 0
	var locations : Array[Location]= []
	var definitions : Array[String]= []

	func _init(p_id : int) -> void:
		id = p_id
	
	func destroy() -> void:
		destroyed = true
		_emit_changed()
		for i in locations.size():
			locations_remove(i)
		for i in definitions.size():
			definition_remove(i)

	func locations_add ( path : String, rect : Rect2 ):
		var location := Location.new(path, rect)
		locations.append(location)
		Database.location_added.emit(id, location)
		_emit_changed()

	func locations_remove ( index : int ):
		var location : Location = locations.pop_at( index )
		Database.location_removed.emit(id, location)
		if orphan and definitions.is_empty():
			destroy()
	
	func locations_remove_rect ( rect : Rect2i ):
		for i in locations.size():
			if locations[i].rect == rect:
				locations_remove(i)
				break

	func definition_add( def: String ) -> int:
		definitions.append(def)
		Database.definition_added.emit(id, def)
		_emit_changed()
		return definitions.size() - 1

	func definition_remove( index : int ) -> bool:
		var success := false
		if index >= 0 and index < definitions.size():
			success = true
			var def = definitions.pop_at(index)
			Database.definition_removed.emit(id, def)
			_emit_changed()
		if orphan and definitions.is_empty():
			destroy()
		return success

	func definition_edit( index : int, def: String ) -> bool:
		var success := false
		if index >= 0 and index < definitions.size():
			var removed_def = definitions[index]
			definitions[index] = def
			Database.definition_removed.emit(id, removed_def)
			Database.definition_added.emit(id, def)
			_emit_changed()
		return success
	
	func to_dictionary() -> Dictionary:
		var ret := Dictionary()
		var serialized_locations : Array[Dictionary] = []
		for l:Location in locations:
			serialized_locations.append(l.to_dictionary())
		
		ret["id"] = id
		ret["locations"] = serialized_locations
		ret["definitions"] = definitions
		return ret
	
	static func from_dictionary(dict : Dictionary) -> Glyph:
		var ret := Glyph.new(0)
		assert(dict.has("id"))
		assert(dict.has("locations"))
		assert(dict.has("definitions"))
		
		var serialized_locations = dict["locations"]
		var deserialized_locations : Array[Location] = []
		for l in serialized_locations:
			deserialized_locations.append(Location.from_dictionary(l))

		ret.id = dict["id"]
		ret.locations = deserialized_locations
		ret.definitions.assign( dict["definitions"] )
		return ret
	
	func _emit_changed():
		changed.emit()
		Database.glyph_modified.emit(id)

## Defines a location.
## [br]
## A "location" is a rectangular section of an image containing a glyph
class Location extends RefCounted:
	var path : String
	var rect : Rect2i
	func _init(p_path : String, p_rect : Rect2i) -> void:
		assert(p_rect.size != Vector2i.ZERO)
		path = p_path
		rect = p_rect
	
	func to_dictionary() -> Dictionary:
		return {
			"path" : path, "rect": {
				"x": rect.position.x,
				"y": rect.position.y,
				"w": rect.size.x,
				"h": rect.size.y, } }
	
	static func from_dictionary(dict: Dictionary) -> Location:
		assert(dict.has("path"))
		assert(dict.has("rect"))
		var dict_rect = dict["rect"]
		var _rect := Rect2i(dict_rect.x, dict_rect.y, dict_rect.w, dict_rect.h)
		return Location.new( dict["path"], _rect )



#==[ Public Methods ]#

#====[ I/O ]#

## Initializes the database
func db_create() -> Error:
	var db_path : String = DEFAULT_DB_PATH.path_join(GLYPH_DB_FILENAME)
	var sources_path : String = DEFAULT_DB_PATH.path_join(SOURCE_DB_FOLDER)
	var err := ERR_BUG
	
	if not DirAccess.dir_exists_absolute(DEFAULT_DB_PATH):
		DirAccess.make_dir_recursive_absolute(DEFAULT_DB_PATH)
	
	if not DirAccess.dir_exists_absolute(sources_path):
		DirAccess.make_dir_recursive_absolute(sources_path)
	
	if FileAccess.file_exists(db_path):
		return ERR_ALREADY_EXISTS
	
	var db_file = FileAccess.open(db_path,FileAccess.WRITE)
	err = FileAccess.get_open_error()
	if err != OK:
		return err

	glyph_db = GlyphDB.new()
	definition_db = DefinitionDB.new(glyph_db)
	word_db = WordDB.new(glyph_db)
	sources_db = SourcesDB.new(glyph_db)
	sources_db.add_sources_from_paths(DirAccess.get_files_at(sources_path))

	db_file.store_string(glyph_db.serialize())
	err = OK
	return err

## Loads the database
func db_load() -> Error:
	var start_time := Time.get_ticks_msec()
	var db_path : String = DEFAULT_DB_PATH.path_join(GLYPH_DB_FILENAME)
	var sources_path : String = DEFAULT_DB_PATH.path_join(SOURCE_DB_FOLDER)
	var err := ERR_BUG
	if not FileAccess.file_exists(db_path):
		return db_create()
	
	if not DirAccess.dir_exists_absolute(sources_path):
		DirAccess.make_dir_recursive_absolute(sources_path)
	
	var file = FileAccess.open(db_path, FileAccess.READ)
	err = FileAccess.get_open_error()
	if not err == OK:
		return err
	
	glyph_db = GlyphDB.deserialize( file.get_as_text() )
	definition_db = DefinitionDB.new(glyph_db)
	word_db = WordDB.new(glyph_db)
	sources_db = SourcesDB.new(glyph_db)
	sources_db.add_sources_from_paths(DirAccess.get_files_at(sources_path))
	err = OK
	print("Loaded in %ss" % (0.001 * (Time.get_ticks_msec()-start_time )))
	return err

## Saves the database
func db_save() -> Error:
	var err := ERR_BUG
	## Check for existing lock
	var lockfile : FileAccess
	var lockfile_path = DEFAULT_DB_PATH.path_join("db.lock")
	if FileAccess.file_exists(lockfile_path):
		return ERR_FILE_ALREADY_IN_USE
	else:
		lockfile = FileAccess.open(lockfile_path, FileAccess.WRITE)
		err = FileAccess.get_open_error()
		if err != OK:
			return err
		lockfile.flush()
		lockfile.close()
		
	save_started.emit()
	await get_tree().process_frame
	
	var start_time := Time.get_ticks_msec()
	var db_path : String = DEFAULT_DB_PATH.path_join(GLYPH_DB_FILENAME)
	if FileAccess.file_exists(db_path):
		var ext = db_path.get_extension()
		var basename = db_path.get_basename()
		DirAccess.copy_absolute(db_path, basename + "[backup]." + ext)
	var file = FileAccess.open(db_path, FileAccess.WRITE)
	err = FileAccess.get_open_error()
	if err == OK:
		file.store_string(glyph_db.serialize())
	
	err = DirAccess.remove_absolute(lockfile_path)
	print("Saved in %ss" % (0.001 * (Time.get_ticks_msec() - start_time) ))
	save_complete.emit()
	return err

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
		removed_glyph.destroy()
	return success

## Takes an int id and returns a Glyph
func glyph_get(id: int) -> Glyph:
	return glyph_db.get_at(id)

## Returns amount of glyphs in the db
func glyph_count() -> int:
	return glyph_db.size()

#====[ source and glyph display ]#
func get_texture(path : String) -> Texture2D:
	return texture_cache.get_texture(path)

func get_thumbnail(path : String) -> Texture2D:
	return texture_cache.get_thumbnail(path)

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
	
	func size():
		return glyphs.size()
	
	func create() -> Glyph:
		var id : int = _get_free_id()
		var glyph = Glyph.new(id)
		glyphs[id] = glyph
		return glyph
	func remove(id : int) -> bool:
		if not(id > 0 and id < glyphs.size()):
			return false
		if glyphs[id] == null:
			return false
		glyphs[id] = null
		free_ids[id] = true
		return true

	func get_at(id : int) -> Glyph:
		if not(id > 0 and id < glyphs.size()):
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
	
	func to_dictionary() -> Dictionary:
		var ret := Dictionary()
		var serialized_glyphs : Array = []
		for g : Glyph in glyphs:
			if g == null:
				serialized_glyphs.append(null)
			else:
				serialized_glyphs.append(g.to_dictionary())
		ret["glyphs"] = serialized_glyphs
		return ret
	
	static func from_dictionary(dict : Dictionary) -> GlyphDB:
		var ret = GlyphDB.new()
		assert(dict.has("glyphs"))
		var deserialized_glyphs : Array[Glyph] = []
		var serialized_glyphs : Array = dict["glyphs"]
		var _free_ids : Dictionary[int, bool] = {}
		for i : int  in serialized_glyphs.size():
			var g = serialized_glyphs[i]
			assert(g == null or g is Dictionary)
			if g == null:
				deserialized_glyphs.append(null)
				_free_ids[i] = true
			else:
				var glyph : Glyph = Glyph.from_dictionary(g)
				assert(glyph.id == deserialized_glyphs.size())
				deserialized_glyphs.append(glyph)
		
		ret.glyphs = deserialized_glyphs
		ret.free_ids = _free_ids
		return ret
	
	func serialize() -> String:
		return JSON.stringify(to_dictionary(), "\t")
	
	static func deserialize(json_string : String) -> GlyphDB:
		return GlyphDB.from_dictionary(JSON.parse_string(json_string))
	
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


class Source extends RefCounted:
	var path : String = ""
	var rects : Dictionary[Rect2i, int] = {}
	var size : bool:
		set(v):
			push_error("Read only")
		get():
			return rects.size()
	var empty : bool:
		set(v):
			push_error("Read only")
		get():
			return rects.is_empty()

	func _init(p_path : String) -> void:
		assert(p_path.is_relative_path())
		path = p_path
	
	func set_rect( rect : Rect2i, glyph_id: int):
		rects[rect] = glyph_id
	
	func remove_rect( rect : Rect2i):
		rects.erase(rect)


class SourcesDB extends RefCounted:
	var sources : Dictionary[String,Source] = {}
	func _init(glyph_db : GlyphDB) -> void:
		Database.location_added.connect(_on_location_added)
		Database.location_removed.connect(_on_location_removed)
		for glyph in glyph_db.get_all():
			for l in glyph.locations:
				_on_location_added(glyph.id, l)
	
	func _on_location_added(glyph_id : int, location : Location):
		add_source(location.path)
		var source : Source = sources[location.path]
		source.set_rect(location.rect, glyph_id)
	
	func _on_location_removed(_glyph_id : int, location : Location):
		assert(sources.has(location.path))
		var source : Source = sources[location.path]
		source.remove_rect(location.rect)
		if source.empty:
			remove_source(location.path)
	
	func add_source(path: String) -> Error:
		assert(path.is_relative_path())
		if sources.has(path):
			return ERR_ALREADY_EXISTS
		if path.get_extension() != "jpg":
			return ERR_INVALID_DATA
		sources[path] = Source.new(path)
		return OK
	
	func remove_source(path: String):
		sources.erase(path)

	func add_sources_from_paths( paths: PackedStringArray):
		for path in paths:
			add_source(path)
	
	func list() -> Array[Source]:
		return sources.values()
	
	func list_sorted() -> Array[Source]:
		var ret := sources.values()
		ret.sort_custom(func(a : Source, b: Source): return a.size < b.size )
		return ret
	
	func list_empty() -> Array[Source]:
		return sources.values().filter(func(s : Source): return s.empty )
	
	func list_non_empty() -> Array[Source]:
		return sources.values().filter(func(s : Source): return not s.empty)

class TextureCache extends RefCounted:
	const MAX_TEXTURES := 20
	const MAX_THUMBNAIS := 100
	var base_path : String = ""
	var textures : Dictionary[String,Texture2D] = {}
	var thumbnails : Dictionary[String, Texture2D] = {}
	
	func _init(p_base_path : String) -> void:
		assert(p_base_path.is_absolute_path())
		base_path = p_base_path
		textures[base_path] = Texture2D.new()
	
	func get_texture( path: String ) -> Texture2D:
		_load_texture_if_needed(path)
		return textures[path]
	
	func get_thumbnail( path: String ) -> Texture2D:
		_load_thumb_if_needed(path)
		return thumbnails[path]
	
	func _load_texture_if_needed( path : String):
		if textures.has(path):
			return
		var full_path : String = base_path.path_join(path)
		var image : Image = Image.load_from_file(full_path) if FileAccess.file_exists(full_path) else null
		var texture : Texture2D = ImageTexture.create_from_image(image) if image else (preload("uid://cc27nwruufj0o") as Texture2D)
		if textures.size() >= MAX_TEXTURES:
			textures.erase(textures.keys().front())
		textures[path] = texture
	
	func _load_thumb_if_needed( path : String ):
		if thumbnails.has(path):
			return
		var thumbs_dir := base_path.path_join("thumbnails")
		# Create thumbnails dir if needed
		if not DirAccess.dir_exists_absolute(thumbs_dir):
			DirAccess.make_dir_recursive_absolute(thumbs_dir)
		var full_path_thumb := thumbs_dir.path_join(path)
		var image : Image
		# Try loading the thumb from disk, otherwise generate it and save it
		if FileAccess.file_exists(full_path_thumb):
			image = Image.load_from_file(full_path_thumb)
		else:
			var texture_full_path = base_path.path_join(path)
			image = Image.load_from_file(texture_full_path) if FileAccess.file_exists(texture_full_path) else null
			if image:
				image.resize(200,113,Image.INTERPOLATE_LANCZOS)
				image.save_jpg(full_path_thumb, 0.85)
		var texture : Texture2D = ImageTexture.create_from_image(image) if image else (preload("uid://cc27nwruufj0o") as Texture2D)
		if thumbnails.size() >= MAX_THUMBNAIS:
			thumbnails.erase(thumbnails.keys().front())
		thumbnails[path] = texture


## Active instance of GlyphDB
var glyph_db: GlyphDB

## Active instance of SourcesDB
var sources_db: SourcesDB

## Active instance of DefinitionDB
var definition_db: DefinitionDB

## Active instance of WordDB
var word_db : WordDB

var texture_cache : TextureCache = TextureCache.new(DEFAULT_DB_PATH.path_join(SOURCE_DB_FOLDER))

func _ready() -> void:
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	var err = db_load()
	assert(err == OK)
	
	var timer := Timer.new()
	timer.wait_time = 60
	timer.autostart = true
	timer.one_shot = false
	timer.timeout.connect(func(): print(await db_save()))
	add_child(timer)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		await db_save()
		get_tree().quit()

func _add_random_glyph():
	var lorem_packed := "Lorem ipsum odor amet, consectetuer adipiscing elit. Penatibus etiam lacinia placerat quisque nullam pretium. Tristique bibendum potenti fringilla placerat fusce faucibus vitae nostra nisl. Elementum nascetur aliquam facilisi molestie quisque. Interdum felis eros rhoncus gravida inceptos dis! Eleifend nulla lectus justo duis orci ex; eget turpis a. Pretium augue tristique parturient per fames ad euismod semper. Ex justo fames eleifend rhoncus orci feugiat. Ipsum ultricies orci aenean integer ad purus. Erat habitasse curae egestas orci duis eleifend eleifend. Nostra aptent ad dapibus nunc orci imperdiet condimentum aliquam morbi. Nunc facilisis odio mi, aptent tristique sem sodales. Euismod facilisis suspendisse sit dui curabitur fusce non taciti. Per curae ultricies primis erat egestas sit duis! Conubia litora torquent maximus faucibus class lacinia.".split(" ")
	var lorem : Array = lorem_packed
	var glyph := glyph_add()
	for i in randi_range(1,5):
		var sentence = ""
		for j in randi_range(1, 6):
			sentence += lorem.pick_random() + " "
		glyph.definition_add(sentence)
